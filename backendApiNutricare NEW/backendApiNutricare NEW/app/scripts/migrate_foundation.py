"""Add treatment tables and tracker uniqueness without deleting existing data.

Check: python -m app.scripts.migrate_foundation
Apply: python -m app.scripts.migrate_foundation --apply
"""
import argparse
import asyncio

from sqlalchemy import inspect, text
from app.database import engine
from app.models import UserMedication, UserTreatmentContext


async def migrate(apply=False):
    try:
        async with engine.begin() as connection:
            await connection.execute(text("SET LOCAL lock_timeout = '5s'"))
            existing = await connection.run_sync(lambda c: set(inspect(c).get_table_names()))
            for table in (UserMedication.__table__, UserTreatmentContext.__table__):
                print(f"{table.name}: {'exists' if table.name in existing else 'missing'}")
                if apply:
                    await connection.run_sync(lambda c, t=table: t.create(c, checkfirst=True))
            duplicate_groups = await connection.scalar(text("""
                SELECT count(*) FROM (
                    SELECT user_id, tracker_date FROM daily_tracker
                    GROUP BY user_id, tracker_date HAVING count(*) > 1
                ) duplicates
            """))
            print(f"Duplicate tracker date groups: {duplicate_groups}")
            constraints = await connection.run_sync(
                lambda c: inspect(c).get_unique_constraints('daily_tracker'))
            indexes = await connection.run_sync(
                lambda c: inspect(c).get_indexes('daily_tracker'))
            unique = any(set(item.get('column_names') or []) == {'user_id', 'tracker_date'}
                         for item in constraints + [i for i in indexes if i.get('unique')])
            print(f"Tracker date uniqueness: {'present' if unique else 'missing'}")
            if apply and not unique:
                if duplicate_groups:
                    print("Skipped uniqueness: existing duplicate records need review; no rows were removed.")
                else:
                    await connection.execute(text("""
                        ALTER TABLE daily_tracker ADD CONSTRAINT uq_daily_tracker_user_date
                        UNIQUE (user_id, tracker_date)
                    """))
                    print("Added tracker date uniqueness.")
            print("Migration applied." if apply else "Read-only check completed; use --apply to migrate.")
    finally:
        await engine.dispose()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    asyncio.run(migrate(arguments.apply))
