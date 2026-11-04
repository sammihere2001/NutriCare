"""Explicit live-provider check using fictional measurements only."""
import asyncio
from app.services.openai_service import openai_service


async def main():
    if not openai_service._configured():
        raise SystemExit('Provider is disabled or incomplete; configure backend LLM_* settings first.')
    report = {'daily_logs': [
        {'date': f'2026-01-0{day}', 'morning_glucose': value,
         'evening_glucose': None, 'exercise_minutes': 20, 'sleep_hours': 7}
        for day, value in enumerate((125, 132, 128), 1)]}
    result = await openai_service.generate_health_insights(report)
    analysis = result['ai_analysis']
    if analysis.get('review_status') != 'unverified_ai_draft':
        raise SystemExit('Provider check returned the recorded-data fallback. Check model access/quota/configuration.')
    print('LIVE_NARRATION_CONTRACT_OK: fictional input, valid draft response; clinical quality not assessed.')


if __name__ == '__main__':
    asyncio.run(main())
