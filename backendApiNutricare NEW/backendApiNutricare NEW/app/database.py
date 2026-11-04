from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import settings
from app.db_options import database_options

database_url, connect_args = database_options(settings.DATABASE_URL)
engine = create_async_engine(database_url, connect_args=connect_args,
                             echo=settings.SQL_ECHO, future=True, pool_pre_ping=True,
                             pool_size=3, max_overflow=2)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
