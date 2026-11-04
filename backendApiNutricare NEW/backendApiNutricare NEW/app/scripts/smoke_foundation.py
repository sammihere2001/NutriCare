"""Exercise real PostgreSQL + ASGI endpoints using one rolled-back fixture.

No SMTP, Cloudinary or language-model requests are made.
An optional --ml-url exercises a local development ML service.
"""
import asyncio
from datetime import date
import uuid
import json
import argparse

import httpx
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth_utils import get_current_user
from app.database import engine, get_db
from app.main import app
from app.models import User, UserProfile, DailyTracker
from app.schemas import ActivityLevelEnum, DiabetesStatusEnum


async def smoke(ml_url=None):
    from app.services.ai_service import ai_service
    original_ml_url = ai_service.ai_api_url
    if ml_url:
        ai_service.ai_api_url = ml_url.rstrip('/')
    email = f"nutricare-smoke-{uuid.uuid4().hex}@example.invalid"
    try:
        async with engine.connect() as connection:
            transaction = await connection.begin()
            session = AsyncSession(bind=connection, expire_on_commit=False,
                                   join_transaction_mode="create_savepoint")
            try:
                user = User(email=email, password_hash="not-a-login-credential",
                            first_name="Integration", last_name="Fixture", is_active=True)
                session.add(user)
                await session.flush()
                await session.commit()

                async def fixture_db():
                    yield session

                async def fixture_user():
                    return user

                app.dependency_overrides[get_db] = fixture_db
                app.dependency_overrides[get_current_user] = fixture_user
                async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                             base_url='http://test') as client:
                    payload = {'medications_confirmed': True, 'appetite': 'reduced',
                               'symptoms': ['early_fullness'], 'medications': [
                                   {'medication_class': 'insulin'},
                                   {'medication_class': 'glp1', 'name': 'Fixture medication'},
                                   {'medication_class': 'metformin'}]}
                    result = await client.post('/profile/create', json={
                        'user_id': user.user_id, 'age': 30, 'gender': 'male',
                        'weight_kg': 70, 'height_cm': 175, 'diabetes_status': 'type2',
                        'insulin_usage': True, 'activity_level': 'sedentary',
                        'blood_sugar': None, 'treatment': payload})
                    assert result.status_code == 200, result.text
                    result = await client.put('/profile/edit', data={
                        'user_id': str(user.user_id), 'first_name': 'Updated fixture',
                        'treatment': json.dumps(payload)})
                    assert result.status_code == 200, result.text
                    result = await client.put('/treatment/me', json=payload)
                    assert result.status_code == 200, result.text
                    result = await client.get('/treatment/me')
                    assert result.status_code == 200 and len(result.json()['medications']) == 3
                    result = await client.get('/profile/me')
                    assert result.status_code == 200, result.text
                    assert result.json()['insulin_usage'] is True
                    assert result.json()['treatment']['appetite'] == 'reduced'
                    day = date.today().isoformat()
                    for glucose in (123, 135):
                        result = await client.post('/daily-tracker/quick-log-glucose', params={
                            'tracker_date': day, 'glucose_type': 'morning', 'glucose_value': glucose})
                        assert result.status_code == 200, result.text
                    count = await session.scalar(select(func.count()).select_from(DailyTracker)
                                                 .where(DailyTracker.user_id == user.user_id))
                    assert count == 1
                    result = await client.get('/profile/me')
                    assert result.json()['latest_blood_sugar'] == 135
                    if ml_url:
                        health = await client.get('/health/ready')
                        assert health.status_code == 200, health.text
                        result = await client.post('/diet-plan/generate', params={'days': 3})
                        assert result.status_code == 200, result.text
                        plan = result.json()['data']
                        assert len(plan['weekly_plan']) == 3
                        context = plan['planning_context']
                        assert context['engine_version'] == 'medication_hybrid_v1'
                        assert set(context['medication_context']['medication_classes']) == {'insulin', 'glp1', 'metformin'}
                        print('POSTGRESQL_BACKEND_ML_OK: three days and combination context preserved')
                    result = await client.post('/weekly-reports/generate',
                                               params={'start_date': day, 'end_date': day})
                    assert result.status_code == 200, result.text
                    assert result.json()['clinical_metrics'][1]['status'] == 'No data'
                    payload['medications'] = [{'medication_class': 'metformin'}]
                    result = await client.put('/treatment/me', json=payload)
                    assert result.status_code == 200, result.text
                    result = await client.get('/profile/me')
                    assert result.json()['insulin_usage'] is False
                print('POSTGRESQL_ASGI_SMOKE_OK: treatment combinations, legacy insulin, tracker sync and reports')
            finally:
                app.dependency_overrides.clear()
                await session.close()
                await transaction.rollback()
            remaining = await connection.scalar(select(func.count()).select_from(User).where(User.email == email))
            assert remaining == 0
            print('ROLLBACK_VERIFIED: no fixture account or health records retained')
    finally:
        ai_service.ai_api_url = original_ml_url
        await engine.dispose()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ml-url', help='Optional local development ML service URL')
    asyncio.run(smoke(parser.parse_args().ml_url))
