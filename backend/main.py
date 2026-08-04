from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from app.db import init_db
from app.glm import glm_client
from app.routers import auth, chat, explore, media

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
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
