"""Regression tests: no live database, emails, model training or paid API calls."""
import unittest
from collections import Counter
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app import auth_utils
from app.database import get_db
from app.main import app
from app.routers.daily_tracker import sync_tracker_glucose
from app.routers.weekly_report import _calculate_report_data
from app.services.openai_service import openai_service


def record(day, morning=None, evening=None, **kwargs):
    data = dict(tracker_date=date(2026, 11, day), morning_glucose=morning,
                evening_glucose=evening, exercise=None, sleep_hours=None,
                water_intake=None, stress_level=None, weight=None)
    data.update(kwargs)
    return SimpleNamespace(**data)


class ReportTests(unittest.TestCase):
    def test_partial_glucose_is_not_halved_or_averaged_as_zero(self):
        report = _calculate_report_data([record(1, 120), record(2, None, 180)],
                                        1, date(2026, 11, 1), date(2026, 11, 3))
        self.assertEqual(report['clinical_metrics'][0]['average_value'], '120.0 mg/dL')
        self.assertEqual(report['clinical_metrics'][1]['average_value'], '180.0 mg/dL')
        self.assertEqual(report['best_day']['avg_glucose'], 120)
        self.assertEqual(report['summary']['compliance'], 66.67)
        self.assertIsNone(report['daily_logs'][0]['evening_glucose'])
        self.assertEqual(report['summary']['trend'], 'INSUFFICIENT_DATA')

    def test_missing_measurement_has_no_assessment(self):
        report = _calculate_report_data([record(1, 120)], 1,
                                        date(2026, 11, 1), date(2026, 11, 1))
        self.assertEqual(report['clinical_metrics'][1]['status'], 'No data')
        self.assertEqual(report['lifestyle_metrics'][0]['assessment'], 'No data')
        self.assertEqual(report['summary']['compliance'], 100)

    def test_real_zero_exercise_is_included(self):
        report = _calculate_report_data([record(1, 120, exercise=0),
                                        record(2, 140, exercise=40)], 1,
                                        date(2026, 11, 1), date(2026, 11, 2))
        self.assertEqual(report['lifestyle_metrics'][0]['weekly_average'], '20.0 min/day')
        self.assertEqual(report['summary']['trend'], 'RISING')

    def test_no_duplicate_routes(self):
        routes = Counter((r.path, tuple(sorted(r.methods))) for r in app.routes
                         if hasattr(r, 'methods'))
        self.assertFalse([key for key, count in routes.items() if count > 1])

    def test_api_docs_only_require_auth_on_protected_endpoints(self):
        schema = app.openapi()
        self.assertNotIn('security', schema['paths']['/auth/login']['post'])
        self.assertTrue(schema['paths']['/profile/get']['get']['security'])

    def test_ai_fallback_does_not_invent_health_scores(self):
        result = openai_service._get_fallback_analysis({'daily_logs': []})
        self.assertEqual(result['ai_analysis']['health_score'], {})
        self.assertEqual(result['ai_analysis']['risk_level'], 'not_assessed')


class AccessTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        async def no_database():
            yield SimpleNamespace(execute=AsyncMock(side_effect=AssertionError('Unexpected DB access')))
        app.dependency_overrides[get_db] = no_database
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                       base_url='http://test')

    async def asyncTearDown(self):
        await self.client.aclose()
        app.dependency_overrides.clear()

    async def test_profile_and_statistics_require_login(self):
        for path in ['/profile/get?user_id=7', '/profile/me',
                     '/daily-tracker/weekly-stats?user_id=7&start_date=2026-11-01&end_date=2026-11-03']:
            response = await self.client.get(path)
            self.assertEqual(response.status_code, 401, path)

    async def test_cross_account_requests_are_rejected_before_database_access(self):
        async def signed_in_user():
            return SimpleNamespace(user_id=1)
        app.dependency_overrides[auth_utils.get_current_user] = signed_in_user
        response = await self.client.get('/profile/get?user_id=2')
        self.assertEqual(response.status_code, 403)
        response = await self.client.put('/profile/edit', data={'user_id': '2'})
        self.assertEqual(response.status_code, 403)
        response = await self.client.post('/profile/create', json={
            'user_id': 2, 'age': 30, 'gender': 'male', 'weight_kg': 70,
            'height_cm': 170, 'diabetes_status': 'type2', 'insulin_usage': False,
            'activity_level': 'sedentary', 'blood_sugar': None})
        self.assertEqual(response.status_code, 403)
        response = await self.client.get('/daily-tracker/weekly-stats?user_id=2&start_date=2026-11-01&end_date=2026-11-03')
        self.assertEqual(response.status_code, 403)

    async def test_malformed_or_expired_token_returns_401(self):
        for token in ['invalid', auth_utils.create_access_token('not-an-integer'),
                      auth_utils.create_access_token(1, expires_minutes=-1)]:
            response = await self.client.get('/auth/users/me', headers={'Authorization': f'Bearer {token}'})
            self.assertEqual(response.status_code, 401)

    async def test_owner_can_fetch_profile(self):
        async def signed_in_user():
            return SimpleNamespace(user_id=1)
        app.dependency_overrides[auth_utils.get_current_user] = signed_in_user
        with patch('app.routers.profile.get_user_profile', new=AsyncMock(return_value={'user_id': 1})):
            response = await self.client.get('/profile/get?user_id=1')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['user_id'], 1)

    async def test_invalid_profile_edit_is_validation_error_not_server_error(self):
        async def signed_in_user():
            return SimpleNamespace(user_id=1)
        app.dependency_overrides[auth_utils.get_current_user] = signed_in_user
        response = await self.client.put('/profile/edit', data={'user_id': '1', 'age': '999'})
        self.assertEqual(response.status_code, 422)

    async def test_inactive_account_is_rejected(self):
        credentials = HTTPAuthorizationCredentials(scheme='Bearer',
                                                    credentials=auth_utils.create_access_token(1))
        with patch('app.crud_auth.get_user_by_id', new=AsyncMock(return_value=SimpleNamespace(is_active=False))):
            with self.assertRaises(HTTPException) as caught:
                await auth_utils.get_current_user(credentials, None)
            self.assertEqual(caught.exception.status_code, 401)


class GlucoseSyncTests(unittest.IsolatedAsyncioTestCase):
    async def test_logging_requires_completed_profile(self):
        db = SimpleNamespace(get=AsyncMock(return_value=None))
        with self.assertRaises(HTTPException) as caught:
            await sync_tracker_glucose(db, SimpleNamespace(user_id=1))
        self.assertEqual(caught.exception.status_code, 409)

    async def test_quick_log_creates_only_the_available_reading(self):
        empty = SimpleNamespace(scalars=lambda: SimpleNamespace(first=lambda: None))
        db = SimpleNamespace(execute=AsyncMock(return_value=empty), get=AsyncMock(return_value=object()),
                             add=lambda value: added.append(value))
        added = []
        tracker = SimpleNamespace(user_id=1, tracker_date=date(2026, 11, 1),
                                  morning_glucose=Decimal('123'), evening_glucose=None)
        await sync_tracker_glucose(db, tracker)
        self.assertEqual(len(added), 1)
        self.assertEqual(added[0].reading_value, 123)
        self.assertEqual(added[0].notes, 'tracker:2026-11-01:morning')
        self.assertIsNotNone(added[0].reading_time.tzinfo)

    async def test_edit_updates_existing_reading_instead_of_adding_duplicate(self):
        existing = SimpleNamespace(reading_value=100)
        first = SimpleNamespace(scalars=lambda: SimpleNamespace(first=lambda: existing))
        empty = SimpleNamespace(scalars=lambda: SimpleNamespace(first=lambda: None))
        db = SimpleNamespace(execute=AsyncMock(side_effect=[first, empty]), get=AsyncMock(return_value=object()),
                             add=lambda value: self.fail('Unexpected duplicate reading'))
        tracker = SimpleNamespace(user_id=1, tracker_date=date(2026, 11, 1),
                                  morning_glucose=Decimal('140'), evening_glucose=None)
        await sync_tracker_glucose(db, tracker)
        self.assertEqual(existing.reading_value, 140)


if __name__ == '__main__':
    unittest.main()
