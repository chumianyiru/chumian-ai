import secrets
from pathlib import Path
from pydantic_settings import BaseSettings

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
DATA_DIR.mkdir(exist_ok=True)

class Settings(BaseSettings):
    glm_api_key: str = ""
    glm_base_url: str = "https://open.bigmodel.cn/api/paas/v4"
    db_path: Path = DATA_DIR / "app.db"
    secret_key: str = secrets.token_urlsafe(32)
    session_cookie_name: str = "chumian_session"
    session_max_age: int = 30 * 24 * 3600
    smtp_host: str = "smtp.qq.com"
    smtp_port: int = 465
    smtp_user: str = ""
    smtp_pass: str = ""
    expected_package: str = "com.chumian.ai"
    expected_md5: str = ""
    daily_points: int = 90_000_000
    max_concurrent_chats: int = 5
    host: str = "0.0.0.0"
    port: int = 24512
    class Config:
        env_file = ROOT / ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

settings = Settings()
