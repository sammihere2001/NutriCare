"""Provider-independent educational narration; legacy import retained."""
import json
import logging
from urllib.parse import urlparse
import httpx
from app.config import settings

logger = logging.getLogger(__name__)

class OpenAIService:
    def __init__(self, config=None, transport=None):
        c = config or settings
        self.provider = c.LLM_PROVIDER.strip().lower()
        self.model = c.LLM_MODEL.strip()
        self.api_key = c.LLM_API_KEY
        self.timeout = c.LLM_TIMEOUT
        self.transport = transport
        defaults = {'deepseek': 'https://api.deepseek.com/v1', 'ollama': 'http://127.0.0.1:11434/v1',
                    'groq': 'https://api.groq.com/openai/v1'}
        self.base_url = (c.LLM_BASE_URL or defaults.get(self.provider, '')).rstrip('/')
        self.min_days_required = 3

    def has_sufficient_data(self, report):
        dates = {log.get('date') for log in report.get('daily_logs', []) if log.get('date') and any(
            type(log.get(k)) in (int, float) and log[k] > 0 for k in ('morning_glucose', 'evening_glucose'))}
        return len(dates) >= 3, len(dates)

    def _configured(self):
        if self.provider not in {'deepseek', 'ollama', 'groq', 'compatible'} or not self.model:
            return False
        u = urlparse(self.base_url)
        if u.username or u.password or u.query or u.fragment:
            return False
        local = u.hostname in {'localhost', '127.0.0.1', '::1'}
        return bool(u.hostname) and (u.scheme == 'https' or (u.scheme == 'http' and local)) and (self.provider == 'ollama' or bool(self.api_key))

    @staticmethod
    def _selected_data(report):
        keys = ('morning_glucose', 'evening_glucose', 'exercise_minutes', 'sleep_hours')
        return [{'day': i, **{k: log.get(k) for k in keys if log.get(k) is None or type(log.get(k)) in (int, float)}}
                for i, log in enumerate(report.get('daily_logs', [])[:31], 1)]

    def _build_optimized_prompt(self, report, previous=None):
        data = {'current_period': self._selected_data(report)}
        if previous:
            data['previous_period'] = self._selected_data(previous)
        return ('Summarize recorded measurements as an educational draft for clinician review. '
                'Glucose units are mg/dL; exercise is minutes; sleep is hours. Null means missing, never zero. '
                'Do not diagnose, assign risk or health scores, infer causation or correlations, prescribe '
                'medication, recommend doses, or infer meal suitability. A short history cannot establish '
                'why readings changed. Mention uncertainty and missing data. Return JSON with only '
                'health_summary (string), glucose_pattern_analysis (object of descriptive strings), '
                'week_comparison (object of strings; unavailable without prior data), educational_insights '
                '(object of strings), recommendations (array of strings about tracking and clinician discussion). '
                'Measurements: ' + json.dumps(data, allow_nan=False))

    async def generate_health_insights(self, report_data, previous_week_data=None):
        enough, days = self.has_sufficient_data(report_data)
        if not enough or not self._configured():
            return self._get_fallback_analysis(report_data)
        try:
            headers = {'Content-Type': 'application/json'}
            if self.api_key:
                headers['Authorization'] = f'Bearer {self.api_key}'
            payload = {'model': self.model, 'messages': [
                {'role': 'system', 'content': 'Return JSON only. Describe recorded data within the requested limits.'},
                {'role': 'user', 'content': self._build_optimized_prompt(report_data, previous_week_data)}],
                'temperature': 0.2, 'max_tokens': 1600, 'response_format': {'type': 'json_object'}}
            if self.provider == 'deepseek':
                payload['thinking'] = {'type': 'disabled'}
            if self.provider == 'groq':
                payload['max_completion_tokens'] = payload.pop('max_tokens')
                if self.model.startswith('openai/gpt-oss-'):
                    payload['reasoning_effort'] = 'low'
            async with httpx.AsyncClient(timeout=self.timeout, transport=self.transport, follow_redirects=False) as client:
                response = await client.post(self.base_url + '/chat/completions', headers=headers, json=payload)
                response.raise_for_status()
                choice = response.json()['choices'][0]
                if choice.get('finish_reason') != 'stop':
                    return self._get_fallback_analysis(report_data)
                return self._parse_ai_response(choice['message']['content'], report_data, days)
        except Exception:
            logger.warning('Report narration unavailable; returning recorded-data summary')
            return self._get_fallback_analysis(report_data)

    def _parse_ai_response(self, text, original_data, days_count=0):
        try:
            if not isinstance(text, str) or len(text) > 30000:
                raise ValueError('Invalid output')
            parsed = json.loads(text)
            if not isinstance(parsed, dict) or not isinstance(parsed.get('health_summary'), str):
                raise ValueError('Invalid summary')
            analysis = self._get_fallback_analysis(original_data)['ai_analysis']
            for key in ('glucose_pattern_analysis', 'week_comparison', 'educational_insights'):
                value = parsed.get(key, {})
                if not isinstance(value, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in value.items()):
                    raise ValueError('Invalid section')
                analysis[key] = value
            recs = parsed.get('recommendations', [])
            if not isinstance(recs, list) or not all(isinstance(v, str) for v in recs):
                raise ValueError('Invalid recommendations')
            analysis.update(generated_by=f'{self.provider} / {self.model}', days_analyzed=days_count,
                            health_summary=parsed['health_summary'], recommendations=recs,
                            review_status='unverified_ai_draft')
            return {**original_data, 'ai_analysis': analysis}
        except (ValueError, TypeError):
            return self._get_fallback_analysis(original_data)

    def _get_fallback_analysis(self, report_data):
        _, days = self.has_sufficient_data(report_data)
        return {**report_data, 'ai_analysis': {
            'generated_by': 'Recorded Data Summary (AI unavailable)', 'days_analyzed': days,
            'health_score': {}, 'risk_level': 'not_assessed',
            'risk_explanation': 'No validated risk assessment was generated.',
            'health_summary': 'Your measured statistics are available below. AI interpretation could not be generated.',
            'glucose_pattern_analysis': {}, 'exercise_glucose_relationship': {}, 'sleep_stress_impact': {},
            'hydration_lifestyle': {}, 'correlation_insights': {}, 'action_matrix': {},
            'week_comparison': {}, 'educational_insights': {}, 'review_status': 'recorded_data_only',
            'recommendations': ['Review the recorded readings and their dates with your healthcare professional.']}}

openai_service = OpenAIService()
