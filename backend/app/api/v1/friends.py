from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.friendship import FriendRequestIn, UserCard
from app.services import friends as friends_service

router = APIRouter()


@router.get("/users/search", response_model=list[UserCard])
async def search_users(
    q: str = Query(min_length=1, max_length=100),
    limit: int = Query(default=10, gt=0, le=50),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[UserCard]:
    return await friends_service.search_users(
        session, query=q, current_user_id=current_user.id, limit=limit
    )


@router.get("/me/friends", response_model=list[UserCard])
async def list_my_friends(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[UserCard]:
    return await friends_service.list_friends(session, user_id=current_user.id)


@router.get("/me/friend-requests")
async def list_my_requests(
    direction: str = Query(default="incoming", pattern="^(incoming|outgoing)$"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    rows = await friends_service.list_pending_requests(
        session, user_id=current_user.id, direction=direction
    )
    return [
        {
            "id": str(fr.id),
            "user": {
                "id": str(u.id),
                "email": u.email,
                "full_name": u.full_name,
            },
            "requested_at": fr.created_at.isoformat(),
        }
        for fr, u in rows
    ]


@router.post("/me/friends/requests", status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    payload: FriendRequestIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    try:
        fr = await friends_service.send_request(
            session, requester_id=current_user.id, target_email=payload.email
        )
    except friends_service.UserNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except friends_service.SelfFriendError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except friends_service.AlreadyFriendsError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return {"id": str(fr.id), "status": fr.status}


@router.post("/me/friends/requests/{friendship_id}/accept")
async def accept_request(
    friendship_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await _respond(session, friendship_id, current_user.id, accept=True)


@router.post("/me/friends/requests/{friendship_id}/reject")
async def reject_request(
    friendship_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await _respond(session, friendship_id, current_user.id, accept=False)


async def _respond(
    session: AsyncSession, friendship_id: UUID, user_id: UUID, *, accept: bool
) -> dict:
    try:
        fr = await friends_service.respond_to_request(
            session, friendship_id=friendship_id, current_user_id=user_id, accept=accept
        )
    except NoResultFound as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except friends_service.NotAuthorizedError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    return {"id": str(fr.id), "status": fr.status}


@router.delete("/me/friends/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_friend(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    try:
        await friends_service.remove_friend(
            session, current_user_id=current_user.id, other_user_id=user_id
        )
    except NoResultFound as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
