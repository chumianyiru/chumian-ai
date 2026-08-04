import os
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
import aiosqlite
from app.config import settings, ROOT
from app.db import get_db
from app.deps import get_current_user
from app.glm import glm_client

router = APIRouter(prefix="/api/media", tags=["media"])

STATIC_DIR = ROOT / "data" / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)

def _rel_path(user_id: int, filename: str) -> str:
    return f"static/{user_id}/{filename}"

def _abs_path(rel: str) -> Path:
    return ROOT / "data" / rel

@router.post("/images")
async def generate_image(
    payload: dict,
    user: dict = Depends(get_current_user),
    db: aiosqlite.Connection = Depends(get_db),
):
    prompt = payload.get("prompt", "").strip()
    size = payload.get("size", "1024x1024")
    if not prompt:
        raise HTTPException(status_code=400, detail="提示词为空")
    if user["points_balance"] < 1000:
        raise HTTPException(status_code=403, detail="积分不足")
    url = await glm_client.generate_image(prompt, size)
    expires = (datetime.utcnow() + timedelta(days=1)).isoformat()
    await db.execute(
        "INSERT INTO media (user_id, url, media_type, expires_at) VALUES (?, ?, ?, ?)",
        (user["id"], url, "image", expires),
    )
    await db.execute("UPDATE users SET points_balance=points_balance-1000 WHERE id=?", (user["id"],))
    await db.commit()
    return {"url": url, "type": "image"}

@router.post("/videos")
async def generate_video(
    payload: dict,
    user: dict = Depends(get_current_user),
    db: aiosqlite.Connection = Depends(get_db),
):
    prompt = payload.get("prompt", "").strip()
    image_url = payload.get("image_url", "")
    size = payload.get("size", "1280x720")
    if not prompt:
        raise HTTPException(status_code=400, detail="提示词为空")
    if user["points_balance"] < 5000:
        raise HTTPException(status_code=403, detail="积分不足")
    data = await glm_client.generate_video(prompt, image_url, size)
    await db.execute("UPDATE users SET points_balance=points_balance-5000 WHERE id=?", (user["id"],))
    await db.commit()
    return {"task_id": data["id"], "status": data.get("task_status", "PROCESSING")}

@router.get("/videos/{task_id}")
async def video_result(
    task_id: str,
    user: dict = Depends(get_current_user),
    db: aiosqlite.Connection = Depends(get_db),
):
    data = await glm_client.video_result(task_id)
    status = data.get("task_status")
    url = ""
    if status == "SUCCESS":
        video_result = data.get("video_result") or data.get("data") or []
        if isinstance(video_result, list) and video_result:
            url = video_result[0].get("url") or video_result[0].get("video_url", "")
        elif isinstance(video_result, dict):
            url = video_result.get("url") or video_result.get("video_url", "")
        if url:
            expires = (datetime.utcnow() + timedelta(days=1)).isoformat()
            await db.execute(
                "INSERT INTO media (user_id, url, media_type, expires_at) VALUES (?, ?, ?, ?)",
                (user["id"], url, "video", expires),
            )
            await db.commit()
    return {"status": status, "url": url, "raw": data}

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
    db: aiosqlite.Connection = Depends(get_db),
):
    ext = Path(file.filename or "bin").suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mov"}:
        raise HTTPException(status_code=400, detail="不支持的文件格式")
    media_type = "video" if ext in {".mp4", ".mov"} else "image"
    user_dir = STATIC_DIR / str(user["id"])
    user_dir.mkdir(exist_ok=True)
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = user_dir / filename
    content = await file.read()
    if len(content) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="文件超过20MB")
    with open(dest, "wb") as f:
        f.write(content)
    rel = _rel_path(user["id"], filename)
    expires = (datetime.utcnow() + timedelta(days=1)).isoformat()
    await db.execute(
        "INSERT INTO media (user_id, url, media_type, expires_at) VALUES (?, ?, ?, ?)",
        (user["id"], f"/{rel}", media_type, expires),
    )
    await db.commit()
    return {"url": f"/{rel}", "type": media_type}
