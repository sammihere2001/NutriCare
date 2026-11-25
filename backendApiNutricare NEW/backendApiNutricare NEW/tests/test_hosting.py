import ssl
import unittest
import json
import httpx
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from sqlalchemy.engine import make_url
from app.db_options import database_options
from test_narration import service, report


class DatabaseUrlTests(unittest.TestCase):
    def test_hosted_libpq_url_uses_verified_tls_with_asyncpg(self):
        url, args = database_options('postgresql://fixture:password@db.invalid/db?sslmode=require&channel_binding=require')
        self.assertEqual(url.drivername, 'postgresql+asyncpg')
        self.assertNotIn('sslmode', url.query)
        self.assertNotIn('channel_binding', url.query)
        self.assertEqual(args['ssl'].verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(args['ssl'].check_hostname)

    def test_existing_local_asyncpg_url_is_preserved(self):
        value = 'postgresql+asyncpg://fixture:password@localhost/db'
        url, args = database_options(value)
        self.assertEqual(url, make_url(value))
        self.assertEqual(args, {})

    def test_other_drivers_and_ambiguous_ssl_modes_are_rejected(self):
        for value in ('sqlite:///db', 'postgresql://localhost/db?sslmode=prefer'):
            with self.assertRaises(ValueError):
                database_options(value)


class GroqTests(unittest.IsolatedAsyncioTestCase):
    async def test_groq_contract_uses_its_endpoint_and_no_deepseek_options(self):
        def request(req):
            self.assertEqual(str(req.url), 'https://api.groq.com/openai/v1/chat/completions')
            payload = json.loads(req.content)
            self.assertNotIn('thinking', payload)
            self.assertNotIn('max_tokens', payload)
            self.assertEqual(payload['max_completion_tokens'], 1600)
            self.assertEqual(payload['reasoning_effort'], 'low')
            return httpx.Response(200, json={'choices': [{'finish_reason': 'stop', 'message': {
                'content': json.dumps({'health_summary': 'Recorded data draft.'})}}]})
        client = service('groq', httpx.MockTransport(request), LLM_MODEL='openai/gpt-oss-20b')
        result = await client.generate_health_insights(report())
        self.assertEqual(result['ai_analysis']['generated_by'], 'groq / openai/gpt-oss-20b')

    async def test_free_tier_rate_limit_keeps_measured_report(self):
        transport = httpx.MockTransport(lambda _: httpx.Response(429, json={'error': 'quota'}))
        data = report()
        result = await service('groq', transport).generate_health_insights(data)
        self.assertEqual(result['daily_logs'], data['daily_logs'])
        self.assertEqual(result['ai_analysis']['review_status'], 'recorded_data_only')


class ReferenceSetupTests(unittest.IsolatedAsyncioTestCase):
    async def test_reference_setup_does_not_invent_missing_nutrition_or_import_users(self):
        from app.scripts import seed_demo
        from app.models import Meal, HealthGoal, DietPreference
        from app.routers.meal_database import get_meals
        path = Path(__file__).resolve().parents[3] / 'Diet_Plan_AI_Complete_v3/final_pakistani_diabetic_meal_plans.csv'
        session = AsyncMock()
        session.__aenter__.return_value = session
        session.get.return_value = None
        session.scalars.return_value = SimpleNamespace(all=lambda: [])
        session.add = Mock()
        fake_engine = Mock()
        connection = AsyncMock()
        context = AsyncMock()
        context.__aenter__.return_value = connection
        fake_engine.begin.return_value = context
        fake_engine.dispose = AsyncMock()
        with patch.object(seed_demo, 'engine', fake_engine), \
             patch.object(seed_demo, 'AsyncSessionLocal', return_value=session), \
             patch.dict('os.environ', {'MEAL_DATASET_PATH': str(path)}):
            await seed_demo.seed()
        added = [call.args[0] for call in session.add.call_args_list]
        self.assertTrue(all(isinstance(row, (Meal, HealthGoal, DietPreference)) for row in added))
        meals = [row for row in added if isinstance(row, Meal)]
        self.assertGreater(len(meals), 0)
        self.assertEqual(len(meals), len({row.name for row in meals}))
        self.assertTrue(all(row.glycemic_index is None and row.fiber_g is None for row in meals))
        session.commit.assert_awaited_once()
        # Exercise the browser contract on a newly seeded reference meal.
        meal = meals[0]
        meal.meal_id = 1
        db = AsyncMock()
        result = Mock()
        result.scalar.return_value = 1
        result.scalars.return_value.all.return_value = [meal]
        result.fetchall.return_value = []
        db.execute.return_value = result
        response = await get_meals(meal_type=None, glycemic_index=None, search=None,
                                   page=1, page_size=20, db=db)
        self.assertEqual(response['meals'][0]['giLevel'], 'GI unknown')
        self.assertEqual(response['meals'][0]['fiber'], 'Not recorded')
