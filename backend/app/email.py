import random
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.header import Header
import aiosmtplib
from app.config import settings

def generate_code(length: int = 6) -> str:
    return "".join(random.choices("0123456789", k=length))

async def send_verification_email(to_email: str, code: str) -> None:
    subject = "【初眠AI】您的注册验证码"
    body = f"""
<html><body style="font-family: sans-serif; color: #333;">
<h2>欢迎注册 初眠AI</h2>
<p>您的验证码为：</p>
<div style="font-size: 28px; font-weight: bold; letter-spacing: 4px; color: #6C63FF;">{code}</div>
<p>验证码 10 分钟内有效，请勿泄露给他人。</p>
<p style="color:#999;font-size:12px;">如非本人操作，请忽略本邮件。</p>
</body></html>
"""
    msg = MIMEText(body, "html", "utf-8")
    msg["From"] = Header(f"初眠AI <{settings.smtp_user}>", "utf-8")
    msg["To"] = Header(to_email, "utf-8")
    msg["Subject"] = Header(subject, "utf-8")
    await aiosmtplib.send(
        msg,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        use_tls=True,
        username=settings.smtp_user,
        password=settings.smtp_pass,
    )
