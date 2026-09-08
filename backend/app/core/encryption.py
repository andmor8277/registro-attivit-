import os
import logging

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

ENCRYPTION_KEY = os.environ.get("ENCRYPTION_KEY")
if not ENCRYPTION_KEY:
    raise RuntimeError("ENCRYPTION_KEY environment variable is required")

PGCRYPTO_AVAILABLE = os.environ.get("PGCRYPTO_AVAILABLE", "false").lower() == "true"


def set_encryption_key(new_key: str):
    global ENCRYPTION_KEY
    os.environ["ENCRYPTION_KEY"] = new_key
    ENCRYPTION_KEY = new_key


def safe_encrypt(db: Session, value: str) -> str:
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    try:
        result = db.execute(
            text("SELECT encode(encrypt(CAST(:val AS bytea), :enc_key, 'aes'), 'hex')"),
            {"val": value, "enc_key": ENCRYPTION_KEY}
        ).scalar()
        return result
    except Exception as e:
        db.rollback()
        logger.error(f"Encryption failed: {e}")
        raise


def safe_decrypt(db: Session, value: str) -> str:
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    if not isinstance(value, str) or len(value) < 32 or not all(c in '0123456789abcdef' for c in value):
        return value
    try:
        db.rollback()
        decrypted = db.execute(
            text("SELECT convert_from(decrypt(decode(:val, 'hex'), :enc_key, 'aes'), 'UTF8')"),
            {"val": value, "enc_key": ENCRYPTION_KEY}
        ).scalar()
        return decrypted if decrypted else value
    except Exception as e:
        db.rollback()
        logger.warning(f"Could not decrypt: {e}")
        return value


def safe_decrypt_with_key(db: Session, value: str, key: str) -> str:
    if not value or not PGCRYPTO_AVAILABLE:
        return None
    if not isinstance(value, str) or len(value) < 32 or not all(c in '0123456789abcdef' for c in value):
        return None
    try:
        db.rollback()
        decrypted = db.execute(
            text("SELECT convert_from(decrypt(decode(:val, 'hex'), :enc_key, 'aes'), 'UTF8')"),
            {"val": value, "enc_key": key}
        ).scalar()
        return decrypted
    except Exception:
        db.rollback()
        return None


def safe_encrypt_with_key(db: Session, value: str, key: str) -> str:
    if not value or not PGCRYPTO_AVAILABLE:
        return value
    try:
        result = db.execute(
            text("SELECT encode(encrypt(CAST(:val AS bytea), :enc_key, 'aes'), 'hex')"),
            {"val": value, "enc_key": key}
        ).scalar()
        return result
    except Exception as e:
        db.rollback()
        logger.error(f"Encryption failed: {e}")
        raise
