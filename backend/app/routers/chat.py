import json
import re
from datetime import datetime, timedelta
from typing import AsyncGenerator
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
import aiosqlite
from app.config import settings
from app.db import get_db
from app.deps import get_current_user, user_out
from app.models import ConversationCreate, MessageCreate, ModelInfo
from app.glm import glm_client, VISION_MODELS
from app.moderation import moderate_chat
from app.security import start_chat, end_chat, can_start_chat

router = APIRouter(prefix="/api/chat", tags=["chat"])

MODELS = [
    ModelInfo(id="GLM-4-Flash", name="GLM-4-Flash", type="chat", description="文本对话"),
    ModelInfo(id="GLM-4-Flash-250414", name="GLM-4-Flash-250414", type="chat", description="文本对话"),
    ModelInfo(id="GLM-4.7-Flash", name="GLM-4.7-Flash", type="chat", description="文本对话"),
    ModelInfo(id="GLM-Z1-Flash", name="GLM-Z1-Flash", type="chat", description="思考模式"),
    ModelInfo(id="GLM-4V-Flash", name="GLM-4V-Flash", type="vision", description="看图对话"),
    ModelInfo(id="GLM-4.6V-Flash", name="GLM-4.6V-Flash", type="vision", description="看图对话"),
    ModelInfo(id="GLM-4.1V-Thinking-Flash", name="GLM-4.1V-Thinking-Flash", type="vision", description="看图思考"),
    ModelInfo(id="CogView-3-Flash", name="CogView-3-Flash", type="image", description="文生图"),
    ModelInfo(id="CogVideoX-Flash", name="CogVideoX-Flash", type="video", description="文生视频"),
]

def _now():
    return datetime.utcnow()

def _today_str():
    return _now().date().isoformat()

async def ensure_daily_reset(db, user):
    if user.get("quota_date") != _today_str():
        await db.execute(
            "UPDATE users SET quota_date=?, points_balance=? WHERE id=?",
            (_today_str(), settings.daily_points, user["id"]),
        )
        await db.commit()
        user["quota_date"] = _today_str()
        user["points_balance"] = settings.daily_points

@router.get("/models", response_model=list[ModelInfo])
async def list_models():
    return MODELS

@router.get("/conversations")
async def conversations(user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    await ensure_daily_reset(db, user)
    rows = await db.execute(
        "SELECT id, title, model, created_at, updated_at FROM conversations WHERE user_id=? ORDER BY updated_at DESC",
        (user["id"],),
    )
    return [dict(r) for r in await rows.fetchall()]

@router.post("/conversations")
async def create_conversation(
    payload: ConversationCreate,
    user: dict = Depends(get_current_user),
    db: aiosqlite.Connection = Depends(get_db),
):
    cur = await db.execute(
        "INSERT INTO conversations (user_id, title, model) VALUES (?, ?, ?)",
        (user["id"], payload.title or "新对话", payload.model or "GLM-4-Flash"),
    )
    await db.commit()
    row = await db.execute("SELECT * FROM conversations WHERE id=?", (cur.lastrowid,))
    return dict(await row.fetchone())

@router.get("/conversations/{cid}")
async def get_conversation(cid: int, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    row = await db.execute("SELECT * FROM conversations WHERE id=? AND user_id=?", (cid, user["id"]))
    conv = await row.fetchone()
    if not conv:
        raise HTTPException(status_code=404, detail="会话不存在")
    return dict(conv)

@router.delete("/conversations/{cid}")
async def delete_conversation(cid: int, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    conv = await db.execute("SELECT id FROM conversations WHERE id=? AND user_id=?", (cid, user["id"]))
    if not await conv.fetchone():
        raise HTTPException(status_code=404, detail="会话不存在")
    await db.execute("DELETE FROM messages WHERE conversation_id=?", (cid,))
    await db.execute("DELETE FROM conversations WHERE id=?", (cid,))
    await db.commit()
    return {"ok": True}

@router.get("/conversations/{cid}/messages")
async def get_messages(cid: int, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    conv = await db.execute("SELECT id FROM conversations WHERE id=? AND user_id=?", (cid, user["id"]))
    if not await conv.fetchone():
        raise HTTPException(status_code=404, detail="会话不存在")
    rows = await db.execute(
        "SELECT id, role, content, thinking, media_url, media_type, created_at FROM messages WHERE conversation_id=? ORDER BY id",
        (cid,),
    )
    return [dict(r) for r in await rows.fetchall()]

@router.post("/conversations/{cid}/messages")
async def create_message(
    cid: int,
    payload: MessageCreate,
    user: dict = Depends(get_current_user),
    db: aiosqlite.Connection = Depends(get_db),
):
    await ensure_daily_reset(db, user)
    if user["points_balance"] <= 0:
        raise HTTPException(status_code=403, detail="今日积分已用完")
    ok, reason = await moderate_chat(payload.content)
    if not ok:
        days = 7
        banned = (_now() + timedelta(days=days)).isoformat()
        await db.execute(
            "UPDATE users SET is_banned=1, banned_until=? WHERE id=?",
            (banned, user["id"]),
        )
        await db.commit()
        raise HTTPException(status_code=403, detail=f"内容违规，账号被封禁 {days} 天：{reason}")
    conv = await db.execute("SELECT * FROM conversations WHERE id=? AND user_id=?", (cid, user["id"]))
    conv = await conv.fetchone()
    if not conv:
        raise HTTPException(status_code=404, detail="会话不存在")
    if not can_start_chat(user["id"]):
        raise HTTPException(status_code=429, detail="最多同时进行 5 个对话")
    start_chat(user["id"])
    media_url = ""
    media_type = ""
    if payload.attachments:
        media_url = payload.attachments[0].get("url", "")
        media_type = payload.attachments[0].get("type", "")
    await db.execute(
        "INSERT INTO messages (conversation_id, role, content, media_url, media_type) VALUES (?, ?, ?, ?, ?)",
        (cid, "user", payload.content, media_url, media_type),
    )
    await db.commit()
    await db.execute("UPDATE conversations SET updated_at=CURRENT_TIMESTAMP WHERE id=?", (cid,))
    await db.commit()

    model = conv["model"]
    rows = await db.execute(
        "SELECT role, content, thinking, media_url, media_type FROM messages WHERE conversation_id=? ORDER BY id",
        (cid,),
    )
    history = []
    for r in await rows.fetchall():
        if r["role"] == "user":
            content = r["content"]
            if model in VISION_MODELS and r["media_url"]:
                content = [{"type": "text", "text": content}]
                content.append({"type": "image_url", "image_url": {"url": r["media_url"]}})
            history.append({"role": "user", "content": content})
        else:
            history.append({"role": "assistant", "content": r["content"] or ""})

    async def event_stream() -> AsyncGenerator[str, None]:
        full_content = ""
        full_reasoning = ""
        try:
            async for chunk in glm_client.chat_stream(history, model):
                c = chunk.get("content", "")
                r = chunk.get("reasoning", "")
                full_content += c
                full_reasoning += r
                if c or r:
                    yield f"data: {json.dumps({'content': c, 'reasoning': r, 'done': False}, ensure_ascii=False)}\n\n"
            # parse <think> tags
            thinking_text = full_reasoning
            content_text = full_content
            m = re.search(r"<think>(.*?)</think>", full_content, re.S)
            if m:
                thinking_text = thinking_text + m.group(1)
                content_text = re.sub(r"<think>.*?</think>", "", full_content, flags=re.S).strip()
            cost = len(payload.content) + len(content_text)
            new_balance = max(user["points_balance"] - cost, 0)
            await db.execute(
                "INSERT INTO messages (conversation_id, role, content, thinking) VALUES (?, ?, ?, ?)",
                (cid, "assistant", content_text, thinking_text or None),
            )
            await db.commit()
            await db.execute("UPDATE users SET points_balance=? WHERE id=?", (new_balance, user["id"]))
            await db.commit()
            msg_id_cur = await db.execute("SELECT last_insert_rowid()")
            msg_id = (await msg_id_cur.fetchone())[0]
            yield f"data: {json.dumps({'done': True, 'message_id': msg_id, 'cost': cost, 'balance': new_balance}, ensure_ascii=False)}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)}, ensure_ascii=False)}\n\n"
        finally:
            end_chat(user["id"])

    return StreamingResponse(event_stream(), media_type="text/event-stream")
