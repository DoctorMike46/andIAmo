from functools import cached_property
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_env: Literal["development", "staging", "production"] = "development"
    app_debug: bool = False
    app_secret_key: str = Field(min_length=16)
    app_base_url: str = "http://localhost:8000"

    database_url: str
    database_url_sync: str

    jwt_secret: str = Field(min_length=16)
    jwt_access_ttl_seconds: int = 900
    jwt_refresh_ttl_seconds: int = 2_592_000

    redis_url: str = "redis://localhost:6379/0"

    s3_endpoint_url: str | None = None
    s3_region: str = "eu-central-1"
    s3_access_key_id: str = ""
    s3_secret_access_key: str = ""
    s3_bucket: str = "andiamo-media"

    anthropic_api_key: str = ""
    voyage_api_key: str = ""

    smtp_host: str = "localhost"
    smtp_port: int = 1025
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "no-reply@andiamo.local"

    cors_allow_origins: str = ""

    @cached_property
    def cors_allow_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allow_origins.split(",") if origin.strip()]

    @cached_property
    def is_production(self) -> bool:
        return self.app_env == "production"


settings = Settings()  # type: ignore[call-arg]
