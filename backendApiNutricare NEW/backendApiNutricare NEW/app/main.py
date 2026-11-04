from fastapi import FastAPI
from fastapi.security import HTTPBearer

from contextlib import asynccontextmanager
from app.database import engine
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, pass_reset, profile, daily_tracker, weekly_report, notifications , diet_plan
from app.routers import user_settings
from app.models import Base
# Add this import at the top with other router imports
from app.routers import meal_database
from app.routers import treatment
from app.routers import health

# Add this line with other app.include_router() calls

# Create security scheme for Swagger
security = HTTPBearer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    try:
        yield
    finally:
        await engine.dispose()

app = FastAPI(
    title="NutriCare API",
    lifespan=lifespan,
    swagger_ui_parameters={
        "persistAuthorization": True,  # Keep authorization across page reloads
    }
)
@app.get("/")
async def root():
    return {"message": "Welcome to NutriCare API"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(pass_reset.router)
app.include_router(daily_tracker.router)
app.include_router(weekly_report.router)
app.include_router(notifications.router)
app.include_router(user_settings.router)
app.include_router(diet_plan.router)
app.include_router(meal_database.router)
app.include_router(treatment.router)
app.include_router(health.router)


