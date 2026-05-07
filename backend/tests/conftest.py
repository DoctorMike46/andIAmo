import os

os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("APP_SECRET_KEY", "test-secret-test-secret-test-secret")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-test-jwt-secret")
os.environ.setdefault(
    "DATABASE_URL", "postgresql+asyncpg://andiamo:andiamo@localhost:5432/andiamo_test"
)
os.environ.setdefault(
    "DATABASE_URL_SYNC", "postgresql+psycopg://andiamo:andiamo@localhost:5432/andiamo_test"
)
