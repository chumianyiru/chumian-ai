import random
import smtplib
import ssl
from email.mime.text import MIMEText
from email.header import Header
import asyncio
from app.config import settings


def generate_code(length: int = 6) -> str:
    return "".join(random.choices("0123456789", k=length))


def _send_sync(hostname: str, port: int, use_tls: bool, username: str, password: str, msg: MIMEText) -> None:
    """同步发送邮件，支持 STARTTLS 和 SSL。"""
    ctx = ssl.create_default_context()
    if use_tls and port == 465:
        server = smtplib.SMTP_SSL(hostname, port, timeout=15, context=ctx)
    else:
        server = smtplib.SMTP(hostname, port, timeout=15)
    try:
        if not use_tls and port == 587:
            server.starttls(context=ctx)
        server.login(username, password)
        server.send_message(msg)
    finally:
        try:
            server.quit()
        except Exception:
            pass


def _build_message(to_email: str, code: str) -> MIMEText:
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
    return msg


def _try_send_with_config(
    hostname: str,
    port: int,
    use_tls: bool,
    username: str,
    password: str,
    msg: MIMEText,
) -> None:
    try:
        _send_sync(hostname, port, use_tls, username, password, msg)
        return
    except Exception as e:
        raise RuntimeError(f"{hostname}:{port} (tls={use_tls}) 发送失败: {e}") from e


async def send_verification_email(to_email: str, code: str) -> None:
    msg = _build_message(to_email, code)
    username = settings.smtp_user
    password = settings.smtp_pass

    configs = [
        (settings.smtp_host, settings.smtp_port, True),   # SSL/TLS，如 465
        ("smtp.qq.com", 587, False),                       # STARTTLS
        ("smtp.qq.com", 465, True),                        # SSL
    ]

    last_error: Exception | None = None
    loop = asyncio.get_event_loop()
    for hostname, port, use_tls in configs:
        for attempt in range(2):
            try:
                await asyncio.wait_for(
                    loop.run_in_executor(
                        None,
                        _try_send_with_config,
                        hostname,
                        port,
                        use_tls,
                        username,
                        password,
                        msg,
                    ),
                    timeout=30,
                )
                return
            except Exception as e:
                last_error = e
                await asyncio.sleep(1)

    raise RuntimeError(f"邮件发送失败：{last_error}")
