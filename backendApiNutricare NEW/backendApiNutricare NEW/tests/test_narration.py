import json
import unittest
from types import SimpleNamespace
import httpx
from app.services.openai_service import OpenAIService


def service(provider='deepseek', transport=None, **overrides):
    config = dict(LLM_PROVIDER=provider, LLM_BASE_URL='', LLM_MODEL='test-model',
                  LLM_API_KEY='fixture-key', LLM_TIMEOUT=1)
    config.update(overrides)
    return OpenAIService(SimpleNamespace(**config), transport)


def report():
    return {'email': 'private@example.invalid', 'daily_logs': [
        {'date': f'2026-11-0{i}', 'morning_glucose': 120 + i,
         'evening_glucose': None, 'notes': 'private prescription text'} for i in range(1, 4)]}


class NarrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_disabled_never_sends_a_request(self):
        def request(_):
            self.fail('Disabled provider made a request')
        result = await service('disabled', httpx.MockTransport(request)).generate_health_insights(report())
        self.assertEqual(result['ai_analysis']['risk_level'], 'not_assessed')

    async def test_insufficient_unique_dates_never_calls_provider(self):
        data = report()
        data['daily_logs'] = [data['daily_logs'][0]] * 3
        self.assertFalse(service().has_sufficient_data(data)[0])
        result = await service().generate_health_insights(data)
        self.assertEqual(result['ai_analysis']['days_analyzed'], 1)

    async def test_deepseek_request_is_minimized_and_risk_scores_are_discarded(self):
        def request(req):
            self.assertEqual(str(req.url), 'https://api.deepseek.com/v1/chat/completions')
            payload = json.loads(req.content)
            self.assertNotIn('private', json.dumps(payload))
            self.assertIn('null', payload['messages'][1]['content'])
            self.assertEqual(payload['thinking'], {'type': 'disabled'})
            return httpx.Response(200, json={'choices': [{'finish_reason': 'stop', 'message': {
                'content': json.dumps({'health_summary': 'Three recorded days.',
                                       'health_score': {'total': 99}, 'risk_level': 'low'})}}]})
        result = await service(transport=httpx.MockTransport(request)).generate_health_insights(report())
        analysis = result['ai_analysis']
        self.assertEqual(analysis['health_summary'], 'Three recorded days.')
        self.assertEqual(analysis['health_score'], {})
        self.assertEqual(analysis['risk_level'], 'not_assessed')
        self.assertEqual(analysis['review_status'], 'unverified_ai_draft')

    async def test_invalid_truncated_and_failed_outputs_fall_back(self):
        for status, choice in [(429, {}), (200, {'finish_reason': 'length', 'message': {'content': '{}'}}),
                               (200, {'finish_reason': 'stop', 'message': {'content': '[]'}}),
                               (200, {'finish_reason': 'stop', 'message': {'content': '{invalid'}})]:
            transport = httpx.MockTransport(lambda _: httpx.Response(status, json={'choices': [choice]}))
            result = await service(transport=transport).generate_health_insights(report())
            self.assertEqual(result['ai_analysis']['review_status'], 'recorded_data_only')

    async def test_local_ollama_needs_no_key(self):
        client = service('ollama', LLM_API_KEY='')
        self.assertTrue(client._configured())
        self.assertEqual(client.base_url, 'http://127.0.0.1:11434/v1')

    async def test_invalid_or_unencrypted_remote_configuration_is_disabled(self):
        for url in ('http://remote.invalid/v1', 'https://user:secret@remote.invalid/v1', 'https://remote.invalid/v1?key=secret'):
            self.assertFalse(service(LLM_BASE_URL=url)._configured())


if __name__ == '__main__':
    unittest.main()
