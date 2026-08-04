from datetime import datetime, timedelta
from fastapi import Request, HTTPException, Depends
from fastapi.security import APIKeyHeader
import aiosqlite
from app.config import settings
from app.db import get_db
from app.security import unsign_session
from app.models import UserOut

header_scheme = APIKeyHeader(name="X-Session-Token", auto_error=False)

def _parse_dt(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return None

async def get_current_user(
    request: Request,
    token_header: str | None = Depends(header_scheme),
    db: aiosqlite.Connection = Depends(get_db),
) -> dict:
    token = token_header or request.cookies.get(settings.session_cookie_name)
    if not token:
        raise HTTPException(status_code=401, detail="未登录")
    session_id = unsign_session(token)
    if not session_id:
        raise HTTPException(status_code=401, detail="会话无效")
    row = await db.execute(
        "SELECT * FROM sessions WHERE id=? AND expires_at>?",
        (session_id, datetime.utcnow().isoformat()),
    )
    session = await row.fetchone()
    if not session:
        raise HTTPException(status_code=401, detail="会话已过期")
    user_row = await db.execute("SELECT * FROM users WHERE id=?", (session["user_id"],))
    user = await user_row.fetchone()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")
    if user["is_banned"]:
        until = _parse_dt(user["banned_until"])
        if until and until > datetime.utcnow():
            raise HTTPException(status_code=403, detail=f"账号已被封禁至 {user['banned_until']}")
        else:
            await db.execute("UPDATE users SET is_banned=0, banned_until=NULL WHERE id=?", (user["id"],))
            await db.commit()
    return dict(user)

def user_out(user: dict) -> UserOut:
    return UserOut(
        id=user["id"],
        email=user["email"],
        nickname=user["nickname"],
        points_balance=user["points_balance"],
        daily_points=user["daily_points"],
        is_banned=bool(user["is_banned"]),
        banned_until=user.get("banned_until"),
        oobe_completed=bool(user["oobe_completed"]),
    )
