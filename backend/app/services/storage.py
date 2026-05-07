"""S3-compatible object storage wrapper (MinIO in dev, Hetzner in prod)."""
import asyncio
import mimetypes
import uuid
from pathlib import PurePosixPath

import boto3
from botocore.client import Config

from app.core.config import settings


def _client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key_id,
        aws_secret_access_key=settings.s3_secret_access_key,
        config=Config(signature_version="s3v4"),
    )


def _public_url(key: str) -> str:
    """Return the publicly accessible URL for the given key.

    In dev this points at MinIO on localhost:9000. The bucket is configured
    with anonymous download in `infra/docker-compose.yml`.
    """
    base = (settings.s3_endpoint_url or "").rstrip("/")
    return f"{base}/{settings.s3_bucket}/{key}"


async def upload_bytes(
    *,
    data: bytes,
    filename: str,
    prefix: str = "media",
) -> str:
    """Upload `data` to S3 and return the public URL.

    The key is `<prefix>/<uuid>.<ext>` to avoid collisions and prevent
    user-supplied filenames from leaking into URLs.
    """
    ext = PurePosixPath(filename).suffix.lower() or ".bin"
    key = f"{prefix}/{uuid.uuid4().hex}{ext}"
    content_type, _ = mimetypes.guess_type(filename)
    content_type = content_type or "application/octet-stream"

    def _put() -> None:
        _client().put_object(
            Bucket=settings.s3_bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
        )

    await asyncio.to_thread(_put)
    return _public_url(key)
