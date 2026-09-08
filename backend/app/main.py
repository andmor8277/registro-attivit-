from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
import os
from .rate_limit import limiter
from .database import Base, engine
from .routers import persone, registro, codici, categorie, convocazioni, allenatori, societa, allenamenti, partite, weekend, spogliatoi, campi, presenze_allenatori, valutazioni, infortuni, openday, planning_eventi, schede_allenamento
from .routers.gruppi import router as gruppi_router
from .routers.liste_tornei import router as liste_tornei_router
from .routers.inviti import router as inviti_router
from .routers.auth import router as auth_router, get_current_user
from sqlalchemy import text

app = FastAPI(title="Registro Presenze API")
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_exceeded_handler(request, exc):
    return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"})

@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    if "Server" in response.headers:
        del response.headers["Server"]
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://thof.crickethouse.mywire.org", "https://dev-thof.crickethouse.mywire.org", "http://localhost:5173", "http://localhost:3000", "http://192.168.178.133:3000"],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["Content-Disposition"]
)



UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

from .migrations import run_migrations

Base.metadata.create_all(bind=engine)
run_migrations()

app.include_router(auth_router)
app.include_router(inviti_router)
app.include_router(societa.router, dependencies=[Depends(get_current_user)])
app.include_router(persone.router)
app.include_router(registro.router, dependencies=[Depends(get_current_user)])
app.include_router(codici.router, dependencies=[Depends(get_current_user)])
app.include_router(categorie.router, dependencies=[Depends(get_current_user)])
app.include_router(convocazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(allenatori.router, dependencies=[Depends(get_current_user)])
app.include_router(allenamenti.router, dependencies=[Depends(get_current_user)])
app.include_router(gruppi_router, dependencies=[Depends(get_current_user)])
app.include_router(partite.router, dependencies=[Depends(get_current_user)])
app.include_router(weekend.router, dependencies=[Depends(get_current_user)])
app.include_router(spogliatoi.router, dependencies=[Depends(get_current_user)])
app.include_router(campi.router, dependencies=[Depends(get_current_user)])
app.include_router(presenze_allenatori.router, dependencies=[Depends(get_current_user)])
app.include_router(valutazioni.router, dependencies=[Depends(get_current_user)])
app.include_router(infortuni.router, dependencies=[Depends(get_current_user)])
app.include_router(openday.router, prefix="/openday", dependencies=[Depends(get_current_user)])
app.include_router(planning_eventi.router, dependencies=[Depends(get_current_user)])
app.include_router(schede_allenamento.router, dependencies=[Depends(get_current_user)])
app.include_router(liste_tornei_router, dependencies=[Depends(get_current_user)])

@app.get("/")
def root():
    return {"status": "ok"}
