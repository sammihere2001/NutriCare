import unittest
from unittest.mock import patch

import httpx
from fastapi import HTTPException

from app.services.ai_service import AIService


def saved_profile():
    return {'age': 45, 'gender': 'male', 'weight_kg': 85, 'height_cm': 175,
            'activity_level': 'moderately_active', 'health_goals': [4],
            'dietary_preferences': [9], 'diabetes_status': 'type2', 'insulin_usage': True,
            'blood_sugar_level': 140, 'email': 'not-for-ml@example.invalid',
            'treatment': {'medications_confirmed': True, 'appetite': 'reduced',
                'symptoms': ['early_fullness'], 'medications': [
                    {'medication_class': 'insulin', 'name': 'Private name', 'prescribed_dose': 'Private prescription'},
                    {'medication_class': 'glp1', 'name': 'Private GLP name'}]}}


class PayloadTests(unittest.TestCase):
    def test_only_medication_classes_and_context_are_forwarded(self):
        payload = AIService()._prepare_ai_payload(saved_profile())
        self.assertEqual(payload['goals'], ['maintain_weight'])
        self.assertEqual(payload['dietary_preferences'], ['balanced'])
        self.assertEqual(payload['treatment']['medications'], [
            {'medication_class': 'insulin'}, {'medication_class': 'glp1'}])
        self.assertNotIn('email', payload)
        self.assertNotIn('Private', str(payload))

    def test_custom_canonical_inputs_are_supported(self):
        data = saved_profile()
        data.pop('health_goals')
        data['goals'] = ['blood_sugar_control']
        data['dietary_preferences'] = ['vegetarian']
        self.assertEqual(AIService()._prepare_ai_payload(data)['dietary_preferences'], ['vegetarian'])

    def test_unknown_preferences_are_not_silently_replaced(self):
        data = saved_profile()
        data['dietary_preferences'] = [9999]
        with self.assertRaises(HTTPException) as caught:
            AIService()._prepare_ai_payload(data)
        self.assertEqual(caught.exception.status_code, 422)


class MlHttpBridgeTests(unittest.IsolatedAsyncioTestCase):
    async def test_success_keeps_planning_metadata_and_forwards_days(self):
        client_type = httpx.AsyncClient

        def respond(request):
            self.assertEqual(request.url.params['days'], '3')
            return httpx.Response(200, json={'status': 'success',
                'planning_context': {'engine_version': 'medication_hybrid_v1'}, 'weekly_plan': []})

        with patch('app.services.ai_service.httpx.AsyncClient',
                   side_effect=lambda **kwargs: client_type(transport=httpx.MockTransport(respond), **kwargs)):
            result = await AIService().generate_diet_plan(saved_profile(), days=3)
        self.assertEqual(result['planning_context']['engine_version'], 'medication_hybrid_v1')

    async def test_upstream_planning_restriction_is_not_reported_as_server_failure(self):
        client_type = httpx.AsyncClient
        transport = httpx.MockTransport(lambda request: httpx.Response(422, json={'detail': {
            'code': 'diet_medication_review_required', 'message': 'Clinical review is needed'}}))
        with patch('app.services.ai_service.httpx.AsyncClient',
                   side_effect=lambda **kwargs: client_type(transport=transport, **kwargs)):
            with self.assertRaises(HTTPException) as caught:
                await AIService().generate_diet_plan(saved_profile())
        self.assertEqual(caught.exception.status_code, 422)
        self.assertEqual(caught.exception.detail['code'], 'diet_medication_review_required')
