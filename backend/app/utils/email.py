import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

SMTP_HOST = os.environ.get("SMTP_HOST", "localhost")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "25"))
SMTP_FROM = os.environ.get("SMTP_FROM", "noreply@thof.crickethouse.mywire.org")


def send_email(to: str, subject: str, body_html: str):
    """Invia email via SMTP locale (Postfix send-only)."""
    msg = MIMEMultipart("alternative")
    msg["From"] = "THOF-The Home Of Football <noreply@thof.crickethouse.mywire.org>"
    msg["To"] = to
    msg["Subject"] = subject
    msg.attach(MIMEText(body_html, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.sendmail(SMTP_FROM, [to], msg.as_string())
        return True
    except Exception as e:
        print(f"SMTP error: {e}")
        return False
