from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.categorizer import embed_locale
from app.api.deps import get_current_admin
from app.db.session import get_session
from app.models.user import User
from app.schemas.locale import LocaleDetail, LocaleWrite
from app.services import locales as locales_service
from app.services.storage import upload_bytes

_MAX_UPLOAD_BYTES = 8 * 1024 * 1024  # 8 MB
_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}

router = APIRouter()


@router.post("/uploads", status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile = File(...),
    _admin: User = Depends(get_current_admin),
) -> dict[str, str]:
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"unsupported type {file.content_type}; allowed: {sorted(_ALLOWED_CONTENT_TYPES)}",
        )
    data = await file.read()
    if len(data) > _MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"file too large; max {_MAX_UPLOAD_BYTES // (1024 * 1024)} MB",
        )
    url = await upload_bytes(data=data, filename=file.filename or "upload.bin")
    return {"url": url}


@router.post(
    "/locales",
    response_model=LocaleDetail,
    status_code=status.HTTP_201_CREATED,
)
async def admin_create_locale(
    payload: LocaleWrite,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(get_current_admin),
) -> LocaleDetail:
    try:
        locale = await locales_service.create_locale(session, payload=payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    await embed_locale(session, locale)
    return await locales_service.get_locale(
        session, locale_id=locale.id, lat=None, lng=None
    )


@router.put("/locales/{locale_id}", response_model=LocaleDetail)
async def admin_update_locale(
    locale_id: UUID,
    payload: LocaleWrite,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(get_current_admin),
) -> LocaleDetail:
    try:
        locale = await locales_service.update_locale(
            session, locale_id=locale_id, payload=payload
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="locale not found"
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    await embed_locale(session, locale)
    return await locales_service.get_locale(
        session, locale_id=locale.id, lat=None, lng=None
    )


@router.delete("/locales/{locale_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_locale(
    locale_id: UUID,
    session: AsyncSession = Depends(get_session),
    _admin: User = Depends(get_current_admin),
) -> Response:
    try:
        await locales_service.delete_locale(session, locale_id=locale_id)
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="locale not found"
        ) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
