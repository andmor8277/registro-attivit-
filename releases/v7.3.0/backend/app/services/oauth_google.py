import json
import os
from typing import Optional
from urllib.parse import urlencode

import httpx
from fastapi import HTTPException

GOOGLE_CREDENTIALS_PATH = os.environ.get("GOOGLE_CREDENTIALS_PATH", "/app/google-credentials.json")
FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:5173")

_google_config = None


def get_google_config():
    global _google_config
    if _google_config:
        return _google_config
    try:
        with open(GOOGLE_CREDENTIALS_PATH) as f:
            _google_config = json.load(f)
        if isinstance(_google_config, dict) and "web" in _google_config:
            _google_config = _google_config["web"]
    except Exception as e:
        print(f"Google credentials error: {e}")
        _google_config = None
    return _google_config


def get_google_authorize_url(state: str, login_hint: Optional[str] = None):
    config = get_google_config()
    if not config:
        raise HTTPException(status_code=500, detail="Google OAuth non configurato")

    client_id = config.get("client_id")
    redirect_uri = f"{FRONTEND_URL}/registrazione"

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "openid email profile",
        "prompt": "select_account",
        "state": state,
    }
    if login_hint:
        params["login_hint"] = login_hint
    return f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"


async def exchange_google_code(code: str, config: dict) -> dict:
    client_id = config.get("client_id")
    client_secret = config.get("client_secret")
    redirect_uri = f"{FRONTEND_URL}/registrazione"

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post("https://oauth2.googleapis.com/token", data={
                "code": code,
                "client_id": client_id,
                "client_secret": client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code"
            })
            resp.raise_for_status()
            token_data = resp.json()
            access_token = token_data["access_token"]

            resp = await client.get("https://www.googleapis.com/oauth2/v2/userinfo", headers={
                "Authorization": f"Bearer {access_token}"
            })
            resp.raise_for_status()
            return resp.json()
    except Exception as e:
        print(f"Google OAuth: errore comunicazione Google: {e}")
        raise HTTPException(status_code=400, detail="Errore nella comunicazione con Google")
