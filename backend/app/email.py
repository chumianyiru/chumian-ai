import random
import smtplib
import ssl
import socket
from email.mime.text import MIMEText
import asyncio
import logging
from app.config import settings

logger = logging.getLogger(__name__)


def generate_code(length: int = 6) -> str:
    return "".join(random.choices("0123456789", k=length))


def _local_hostname() -> str:
    try:
        return socket.getfqdn()
    except Exception:
        return "chumian.ai"


def _send_sync(hostname: str, port: int, use_tls: bool, username: str, password: str, msg: MIMEText) -> None:
    """同步发送邮件，支持 STARTTLS 和 SSL。"""
    local_hostname = _local_hostname()
    ctx = ssl.create_default_context()
    logger.info(f"[smtp] connecting {hostname}:{port} tls={use_tls} local_hostname={local_hostname}")
    if use_tls and port == 465:
        server = smtplib.SMTP_SSL(hostname, port, timeout=20, context=ctx, local_hostname=local_hostname)
    else:
        server = smtplib.SMTP(hostname, port, timeout=20, local_hostname=local_hostname)
    try:
        if not use_tls and port == 587:
            server.starttls(context=ctx)
        server.login(username, password)
        server.send_message(msg)
        logger.info(f"[smtp] sent via {hostname}:{port}")
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
    msg["From"] = settings.smtp_user
    msg["To"] = to_email
    msg["Subject"] = subject
    return msg


async def send_verification_email(to_email: str, code: str) -> None:
    msg = _build_message(to_email, code)
    username = settings.smtp_user
    password = settings.smtp_pass

    if not username or not password:
        raise RuntimeError("SMTP 用户名或授权码未配置")

    configs = [
        (settings.smtp_host or "smtp.qq.com", settings.smtp_port or 465, True),
        ("smtp.qq.com", 587, False),
        ("smtp.qq.com", 465, True),
    ]

    errors = []
    loop = asyncio.get_event_loop()
    for hostname, port, use_tls in configs:
        for attempt in range(2):
            try:
                await asyncio.wait_for(
                    loop.run_in_executor(
                        None,
                        _send_sync,
                        hostname,
                        port,
                        use_tls,
                        username,
                        password,
                        msg,
                    ),
                    timeout=40,
                )
                return
            except Exception as e:
                err_text = f"{hostname}:{port} (tls={use_tls}) attempt={attempt+1}: {e}"
                logger.warning(f"[smtp] {err_text}")
                errors.append(err_text)
                await asyncio.sleep(1)

    raise RuntimeError("邮件发送失败：" + "; ".join(errors))
