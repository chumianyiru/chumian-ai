import random
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Response, Request
from fastapi.responses import JSONResponse
import aiosqlite
from app.config import settings
from app.db import get_db
from app.email import generate_code, send_verification_email
from app.security import hash_password, verify_password, create_session_id, sign_session
from app.models import ClientVerify, SendCode, Register, Login, UserOut
from app.deps import get_current_user, user_out

router = APIRouter(prefix="/api/auth", tags=["auth"])

def _now() -> datetime:
    return datetime.utcnow()

def _today_str() -> str:
    return _now().date().isoformat()

async def ensure_daily_reset(db: aiosqlite.Connection, user: dict):
    if user.get("quota_date") != _today_str():
        await db.execute(
            "UPDATE users SET quota_date=?, points_balance=? WHERE id=?",
            (_today_str(), settings.daily_points, user["id"]),
        )
        await db.commit()
        user["quota_date"] = _today_str()
        user["points_balance"] = settings.daily_points

@router.post("/client/verify")
async def client_verify(payload: ClientVerify):
    md5 = payload.signature_md5.upper().replace(":", "")
    ok = (
        payload.package_name == settings.expected_package
        and md5 in settings.expected_md5_set
    )
    if not ok:
        raise HTTPException(status_code=403, detail="你使用的不是官方版")
    return {"ok": True}

@router.post("/send-code")
async def send_code(payload: SendCode, db: aiosqlite.Connection = Depends(get_db)):
    email = payload.email.lower()
    if not email.endswith("@qq.com"):
        raise HTTPException(status_code=400, detail="目前仅支持QQ邮箱")
    row = await db.execute("SELECT * FROM users WHERE email=?", (email,))
    user = await row.fetchone()
    if user and user["email_verified"]:
        raise HTTPException(status_code=400, detail="该邮箱已注册")
    code = generate_code(6)
    expires = (_now() + timedelta(minutes=10)).isoformat()
    if user:
        await db.execute(
            "UPDATE users SET verification_code=?, code_expires_at=? WHERE id=?",
            (code, expires, user["id"]),
        )
    else:
        await db.execute(
            "INSERT INTO users (email, nickname, password_hash, verification_code, code_expires_at) VALUES (?, ?, ?, ?, ?)",
            (email, "", "", code, expires),
        )
    await db.commit()
    try:
        await send_verification_email(email, code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"邮件发送失败：{e}")
    return {"ok": True}

@router.post("/register")
async def register(payload: Register, db: aiosqlite.Connection = Depends(get_db)):
    if payload.invite_code != settings.invite_code:
        raise HTTPException(status_code=400, detail="邀请码错误")
    email = payload.email.lower()
    if not email.endswith("@qq.com"):
        raise HTTPException(status_code=400, detail="目前仅支持QQ邮箱")
    row = await db.execute("SELECT * FROM users WHERE email=?", (email,))
    user = await row.fetchone()
    if not user or user["email_verified"]:
        raise HTTPException(status_code=400, detail="请先获取验证码")
    if user["verification_code"] != payload.code:
        raise HTTPException(status_code=400, detail="验证码错误")
    if _parse_dt(user["code_expires_at"]) < _now():
        raise HTTPException(status_code=400, detail="验证码已过期")
    pwd_hash = hash_password(payload.password)
    await db.execute(
        "UPDATE users SET nickname=?, password_hash=?, email_verified=1, verification_code=NULL, code_expires_at=NULL, points_balance=?, daily_points=?, quota_date=? WHERE id=?",
        (payload.nickname, pwd_hash, settings.daily_points, settings.daily_points, _today_str(), user["id"]),
    )
    await db.commit()
    row = await db.execute("SELECT * FROM users WHERE id=?", (user["id"],))
    new_user = dict(await row.fetchone())
    token, expires = await _create_session(db, new_user["id"])
    resp = JSONResponse({"user": user_out(new_user), "token": token})
    _set_cookie(resp, token, expires)
    return resp

@router.post("/login")
async def login(payload: Login, response: Response, db: aiosqlite.Connection = Depends(get_db)):
    md5 = payload.signature_md5.upper().replace(":", "")
    if payload.package_name != settings.expected_package:
        raise HTTPException(status_code=403, detail="你使用的不是官方版")
    if md5 not in settings.expected_md5_set:
        raise HTTPException(status_code=403, detail="你使用的不是官方版")
    email = payload.email.lower()
    row = await db.execute("SELECT * FROM users WHERE email=? AND email_verified=1", (email,))
    user = await row.fetchone()
    if not user or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="邮箱或密码错误")
    if user["is_banned"]:
        until = _parse_dt(user["banned_until"])
        if until and until > _now():
            raise HTTPException(status_code=403, detail=f"账号已被封禁至 {user['banned_until']}")
    await ensure_daily_reset(db, dict(user))
    token, expires = await _create_session(db, user["id"], payload.package_name, payload.signature_md5)
    resp = JSONResponse({"user": user_out(dict(user)), "token": token})
    _set_cookie(resp, token, expires)
    return resp

@router.post("/logout")
async def logout(request: Request, db: aiosqlite.Connection = Depends(get_db)):
    token = request.headers.get("X-Session-Token") or request.cookies.get(settings.session_cookie_name)
    from app.security import unsign_session
    if token:
        sid = unsign_session(token)
        if sid:
            await db.execute("DELETE FROM sessions WHERE id=?", (sid,))
            await db.commit()
    resp = JSONResponse({"ok": True})
    resp.delete_cookie(settings.session_cookie_name)
    return resp

@router.get("/me", response_model=UserOut)
async def me(user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    await ensure_daily_reset(db, user)
    return user_out(user)

@router.post("/oobe-complete")
async def oobe_complete(user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    await db.execute("UPDATE users SET oobe_completed=1 WHERE id=?", (user["id"],))
    await db.commit()
    user["oobe_completed"] = 1
    return user_out(user)

async def _create_session(db, user_id, pkg="", md5=""):
    sid = create_session_id()
    expires = _now() + timedelta(seconds=settings.session_max_age)
    await db.execute(
        "INSERT INTO sessions (id, user_id, client_pkg, client_md5, expires_at) VALUES (?, ?, ?, ?, ?)",
        (sid, user_id, pkg, md5, expires.isoformat()),
    )
    await db.commit()
    return sign_session(sid), expires

def _set_cookie(response: Response, token: str, expires: datetime):
    response.set_cookie(
        key=settings.session_cookie_name,
        value=token,
        expires=int(expires.timestamp()),
        httponly=False,
        samesite="lax",
    )

def _parse_dt(s):
    if not s:
        return datetime.min
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return datetime.min
