import asyncio
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import aiosqlite
from app.config import settings
from app.db import init_db
from app.glm import glm_client
from app.routers import auth, chat, explore, media

STATIC_DIR = Path(__file__).resolve().parent / "data" / "static"

async def _cleanup_expired_media():
    while True:
        try:
            await asyncio.sleep(3600)
            now = datetime.utcnow().isoformat()
            async with aiosqlite.connect(settings.db_path) as db:
                rows = await db.execute(
                    "SELECT id, url FROM media WHERE expires_at<?", (now,)
                )
                expired = await rows.fetchall()
                for row in expired:
                    url = row["url"]
                    if url and url.startswith("/static/"):
                        rel = url.lstrip("/")
                        file_path = STATIC_DIR.parent / rel
                        try:
                            file_path.unlink(missing_ok=True)
                        except Exception:
                            pass
                await db.execute("DELETE FROM media WHERE expires_at<?", (now,))
                await db.commit()
        except asyncio.CancelledError:
            break
        except Exception:
            pass

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    cleanup_task = asyncio.create_task(_cleanup_expired_media())
    yield
    cleanup_task.cancel()
    try:
        await cleanup_task
    except asyncio.CancelledError:
        pass
    await glm_client.close()

app = FastAPI(title="初眠AI 服务端", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

static_dir = Path(__file__).resolve().parent / "data" / "static"
static_dir.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=static_dir), name="static")

app.include_router(auth.router)
app.include_router(chat.router)
app.include_router(explore.router)
app.include_router(media.router)

@app.get("/health")
async def health():
    return {"status": "ok"}
