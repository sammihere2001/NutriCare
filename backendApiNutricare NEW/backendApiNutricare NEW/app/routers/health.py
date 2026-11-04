import httpx
from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text
from app.database import engine
from app.services.ai_service import ai_service

router = APIRouter()


@router.get('/health/ready', include_in_schema=False)
async def ready():
    try:
        async with engine.connect() as connection:
            await connection.execute(text('SELECT 1'))
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(ai_service.ai_api_url + '/model-status')
            response.raise_for_status()
            if response.json().get('status') != 'loaded':
                raise ValueError('Model unavailable')
        return {'status': 'ready'}
    except Exception:
        return JSONResponse(status_code=503, content={'status': 'not_ready'})
