from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
import aiosqlite
from app.config import settings
from app.db import get_db
from app.deps import get_current_user
from app.models import AgentCreate, AgentOut, PostCreate, CommentCreate, TemplateOut
from app.moderation import moderate_post

router = APIRouter(prefix="/api/explore", tags=["explore"])

TEMPLATES = [
    {"category": "creative", "title": "小红书文案", "prompt": "帮我写一篇小红书风格的种草文案，主题是：", "icon": "📝"},
    {"category": "creative", "title": "短视频脚本", "prompt": "写一个30秒短视频脚本，主题是：", "icon": "🎬"},
    {"category": "creative", "title": "诗歌创作", "prompt": "写一首现代诗，主题是：", "icon": "✍️"},
    {"category": "play", "title": "角色扮演", "prompt": "我们来玩角色扮演，你扮演一位古代侠客，我说：", "icon": "🎭"},
    {"category": "play", "title": "解谜游戏", "prompt": "给我出一个逻辑推理谜题，主题是：", "icon": "🧩"},
    {"category": "play", "title": "模拟面试", "prompt": "你来当面试官，面试岗位是：", "icon": "💼"},
]

@router.get("/templates")
async def templates(category: str | None = None):
    data = [t for t in TEMPLATES if not category or t["category"] == category]
    return [{"id": i+1, **t} for i, t in enumerate(data)]

@router.get("/agents", response_model=list[AgentOut])
async def list_agents(published: bool = True, db: aiosqlite.Connection = Depends(get_db)):
    if published:
        rows = await db.execute("SELECT * FROM agents WHERE published=1 ORDER BY id DESC")
    else:
        rows = await db.execute("SELECT * FROM agents ORDER BY id DESC")
    return [dict(r) for r in await rows.fetchall()]

@router.post("/agents", response_model=AgentOut)
async def create_agent(payload: AgentCreate, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    cur = await db.execute(
        "INSERT INTO agents (user_id, name, description, system_prompt, icon, published) VALUES (?, ?, ?, ?, ?, ?)",
        (user["id"], payload.name, payload.description, payload.system_prompt, payload.icon, int(payload.published)),
    )
    await db.commit()
    row = await db.execute("SELECT * FROM agents WHERE id=?", (cur.lastrowid,))
    return dict(await row.fetchone())

@router.get("/posts")
async def list_posts(user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    rows = await db.execute(
        """
        SELECT p.*, u.nickname as author_nickname,
               (SELECT COUNT(*) FROM post_likes WHERE post_id=p.id) as likes,
               (SELECT COUNT(*) FROM comments WHERE post_id=p.id) as comments,
               (SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=?) as liked
        FROM posts p JOIN users u ON p.user_id=u.id
        WHERE p.status='approved' ORDER BY p.id DESC LIMIT 200
        """,
        (user["id"],),
    )
    return [dict(r) for r in await rows.fetchall()]

@router.post("/posts")
async def create_post(payload: PostCreate, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    text = f"{payload.title} {payload.content}".strip()
    safe, reason = await moderate_post(text)
    if not safe:
        days = 7
        banned = (datetime.utcnow() + timedelta(days=days)).isoformat()
        await db.execute("UPDATE users SET is_banned=1, banned_until=? WHERE id=?", (banned, user["id"]))
        await db.commit()
        raise HTTPException(status_code=403, detail=f"内容违规，账号被封禁 {days} 天：{reason}")
    status = "approved"  # AI moderation passed
    cur = await db.execute(
        "INSERT INTO posts (user_id, title, content, media_url, status) VALUES (?, ?, ?, ?, ?)",
        (user["id"], payload.title or "", payload.content, payload.media_url or "", status),
    )
    await db.commit()
    row = await db.execute("SELECT * FROM posts WHERE id=?", (cur.lastrowid,))
    return dict(await row.fetchone())

@router.post("/posts/{pid}/like")
async def like_post(pid: int, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    try:
        await db.execute("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)", (pid, user["id"]))
        await db.commit()
    except Exception:
        pass
    count = await db.execute("SELECT COUNT(*) FROM post_likes WHERE post_id=?", (pid,))
    return {"likes": (await count.fetchone())[0]}

@router.get("/posts/{pid}/comments")
async def get_comments(pid: int, db: aiosqlite.Connection = Depends(get_db)):
    rows = await db.execute(
        "SELECT c.*, u.nickname FROM comments c JOIN users u ON c.user_id=u.id WHERE post_id=? ORDER BY c.id",
        (pid,),
    )
    return [dict(r) for r in await rows.fetchall()]

@router.post("/posts/{pid}/comments")
async def create_comment(pid: int, payload: CommentCreate, user: dict = Depends(get_current_user), db: aiosqlite.Connection = Depends(get_db)):
    safe, reason = await moderate_post(payload.content)
    if not safe:
        raise HTTPException(status_code=403, detail=f"评论审核未通过：{reason}")
    cur = await db.execute(
        "INSERT INTO comments (post_id, user_id, content) VALUES (?, ?, ?)",
        (pid, user["id"], payload.content),
    )
    await db.commit()
    row = await db.execute("SELECT * FROM comments WHERE id=?", (cur.lastrowid,))
    return dict(await row.fetchone())
