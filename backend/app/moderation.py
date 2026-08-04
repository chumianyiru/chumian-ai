import json
from app.glm import glm_client

BANNED_KEYWORDS = [
    "色情", "淫秽", "赌博", "毒品", "爆炸物", "恐怖袭击", "自杀", "自残",
    "杀人", "诈骗", "传销", "洗钱", "枪支", "假币", "强奸", "猥亵", "嫖娼",
]

def keyword_check(text: str) -> tuple[bool, str]:
    t = text.lower()
    for kw in BANNED_KEYWORDS:
        if kw in t:
            return False, f"包含敏感词：{kw}"
    return True, ""

async def ai_moderate(text: str) -> tuple[bool, str]:
    prompt = f"""请判断以下用户内容是否违规。仅回答 JSON：{{"safe": true/false, "reason": "原因"}}。
违规包括：色情、暴力、恐怖主义、毒品、诈骗、广告骚扰等。内容：{text[:500]}"""
    try:
        r = await glm_client.client.post("/chat/completions", json={
            "model": "glm-4-flash",
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "max_tokens": 128,
        })
        r.raise_for_status()
        data = r.json()
        content = data["choices"][0]["message"]["content"].strip()
        if content.startswith("```"):
            content = content.strip("`").strip("json").strip()
        result = json.loads(content)
        return bool(result.get("safe", True)), result.get("reason", "")
    except Exception:
        return True, ""

async def moderate_chat(text: str) -> tuple[bool, str]:
    ok, reason = keyword_check(text)
    if not ok:
        return False, reason
    return True, ""

async def moderate_post(text: str) -> tuple[bool, str]:
    ok, reason = keyword_check(text)
    if not ok:
        return False, reason
    safe, ai_reason = await ai_moderate(text)
    if not safe:
        return False, ai_reason
    return True, ""
