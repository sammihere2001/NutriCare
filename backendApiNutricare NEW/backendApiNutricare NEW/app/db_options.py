"""Normalize provider PostgreSQL URLs without logging credentials."""
import ssl
from sqlalchemy.engine import make_url


def database_options(value):
    url = make_url(value)
    if url.drivername in {'postgres', 'postgresql'}:
        url = url.set(drivername='postgresql+asyncpg')
    if url.drivername != 'postgresql+asyncpg':
        raise ValueError('NutriCare requires PostgreSQL with asyncpg')
    query = dict(url.query)
    mode = query.pop('sslmode', None)
    query.pop('channel_binding', None)  # libpq-only option; TLS still verifies hostname.
    options = {}
    if mode in {'require', 'verify-ca', 'verify-full'}:
        options['ssl'] = ssl.create_default_context()
    elif mode not in {None, 'disable'}:
        raise ValueError('Use sslmode=require or verify-full for hosted PostgreSQL')
    return url.set(query=query), options
