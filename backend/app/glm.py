import json
import httpx
from app.config import settings

MODEL_MAP = {
    "GLM-4-Flash": "glm-4-flash",
    "GLM-4-Flash-250414": "glm-4-flash-250414",
    "GLM-4.7-Flash": "glm-4.7-flash",
    "GLM-Z1-Flash": "glm-z1-flash",
    "GLM-4V-Flash": "glm-4v-flash",
    "GLM-4.6V-Flash": "glm-4.6v-flash",
    "GLM-4.1V-Thinking-Flash": "glm-4.1v-thinking-flash",
    "CogView-3-Flash": "cogview-3-flash",
    "CogVideoX-Flash": "cogvideox-flash",
}

VISION_MODELS = {"GLM-4V-Flash", "GLM-4.6V-Flash", "GLM-4.1V-Thinking-Flash"}
IMAGE_MODELS = {"CogView-3-Flash"}
VIDEO_MODELS = {"CogVideoX-Flash"}

def api_model(name: str) -> str:
    return MODEL_MAP.get(name, name.lower())

SYSTEM_PROMPT = "你是初眠，一个由初眠AI提供的AI助手。请用中文回答，支持Markdown格式。"

class GlmClient:
    def __init__(self):
        self.client = httpx.AsyncClient(
            base_url=settings.glm_base_url,
            headers={"Authorization": f"Bearer {settings.glm_api_key}"},
            timeout=120.0,
        )

    async def chat_stream(self, messages, model: str, system: str = ""):
        api_id = api_model(model)
        sys = (system or "") + "\n" + SYSTEM_PROMPT
        payload_messages = [{"role": "system", "content": sys.strip()}]
        for m in messages:
            payload_messages.append(m)
        payload = {
            "model": api_id,
            "messages": payload_messages,
            "stream": True,
            "temperature": 0.7,
            "top_p": 0.95,
        }
        async with self.client.stream("POST", "/chat/completions", json=payload) as resp:
            resp.raise_for_status()
            async for line in resp.aiter_lines():
                if not line or not line.startswith("data: "):
                    continue
                data = line[6:]
                if data == "[DONE]":
                    break
                try:
                    chunk = json.loads(data)
                    delta = chunk.get("choices", [{}])[0].get("delta", {})
                    content = delta.get("content") or ""
                    reasoning = delta.get("reasoning_content") or ""
                    if content or reasoning:
                        yield {"content": content, "reasoning": reasoning}
                except Exception:
                    continue

    async def generate_image(self, prompt: str, size: str = "1024x1024"):
        payload = {
            "model": api_model("CogView-3-Flash"),
            "prompt": prompt,
            "size": size,
            "n": 1,
        }
        r = await self.client.post("/images/generations", json=payload)
        r.raise_for_status()
        data = r.json()
        return data["data"][0]["url"]

    async def generate_video(self, prompt: str, image_url: str = "", size: str = "1280x720"):
        payload = {
            "model": api_model("CogVideoX-Flash"),
            "prompt": prompt,
            "size": size,
            "quality": "speed",
            "duration": 5,
            "with_audio": False,
        }
        if image_url:
            payload["image_url"] = image_url
        r = await self.client.post("/videos/generations", json=payload)
        r.raise_for_status()
        return r.json()

    async def video_result(self, task_id: str):
        r = await self.client.get(f"/async-result/{task_id}")
        r.raise_for_status()
        return r.json()

    async def close(self):
        await self.client.aclose()

glm_client = GlmClient()
