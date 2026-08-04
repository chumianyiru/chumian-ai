import bcrypt
import uuid
import secrets
from datetime import datetime, timedelta
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from app.config import settings

serializer = URLSafeTimedSerializer(settings.secret_key, salt="chumian_session")

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=10)).decode("utf-8")

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))

def create_session_id() -> str:
    return secrets.token_urlsafe(32)

def sign_session(session_id: str) -> str:
    return serializer.dumps(session_id)

def unsign_session(value: str) -> str | None:
    try:
        return serializer.loads(value, max_age=settings.session_max_age)
    except (BadSignature, SignatureExpired):
        return None

active_chats: dict[int, int] = {}

def can_start_chat(user_id: int) -> bool:
    return active_chats.get(user_id, 0) < settings.max_concurrent_chats

def start_chat(user_id: int):
    active_chats[user_id] = active_chats.get(user_id, 0) + 1

def end_chat(user_id: int):
    active_chats[user_id] = max(active_chats.get(user_id, 1) - 1, 0)
