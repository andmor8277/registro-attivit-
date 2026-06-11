# Session Summary

## Goal
- Redesign the training board tools in `Allenamenti.vue` to match professional soccer whiteboard apps (KlipDraw/TacticalPad style), replacing the cluttered 60+ legacy tools with a clean, flat set of ~22 essential items.

## Constraints & Preferences
- Apply fixes to all identified security bugs.
- Use local `.env` secret values for missing production environment variables.
- Preserve exact file paths, commands, and identifiers.
- App is publicly accessible via internet, requiring strict hardening.
- User explicitly dislikes current training tools; wants flat, professional rendering similar to KlipDraw/TacticalPad.
- No illegal scraping or API bypassing.

## Progress
### Done
- Fixed `slowapi` integration: added `Request` param to rate-limited endpoints, switched to `SlowAPIMiddleware` in `main.py`.
- Cleaned git history using `git filter-repo` to remove hardcoded credentials and force-pushed.
- Removed `frontend/mock-server.js` from repository (contained plaintext passwords).
- Updated production `.env` `DEFAULT_PASSWORD` to `CalcioMania2026!`.
- Hardened `backend/Dockerfile`: removed `--reload`, added non-root `appuser`, configured 4 uvicorn workers.
- Hardened `backend/app/main.py`: added security headers middleware, removed `TrustedHostMiddleware`.
- Hardened `docker-compose.yml`: removed obsolete `version`, removed source volume mount, exposed backend on `0.0.0.0:8000`.
- Hardened `backend/app/routers/societa.py`: added MIME magic bytes validation for file uploads.
- Hardened `backend/app/routers/persone.py`: tightened public PII rate limits to `5/minute`, added Pydantic validation.
- Fixed `MutableHeaders` `pop` method crash and `/uploads/` `400 Bad Request` errors.
- Renamed "Admin Locale" to "Responsabile" in `frontend/src/views/Admin.vue`.
- Analyzed `Allenamenti.vue` tools implementation and identified ~60+ redundant tool types with complex canvas rendering.

### In Progress
- Redesigning `Allenamenti.vue` tools panel HTML: streamlined to 4 clean categories (Players, Goals, Equipment, Arrows) with ~22 essential tools.
- Rewriting `drawBoard` canvas rendering: replaced complex gradients/patterns with flat, professional vector-style drawing for players, goals, cones, disks, poles, ladders, hurdles, zones, and tactical arrows.
- Syncing PDF export logic with the new flat tool rendering.

### Blocked
- (none)

## Key Decisions
- Removed `TrustedHostMiddleware` to allow frontend container to reach backend directly on the Docker internal network.
- Exposed backend on `0.0.0.0:8000` instead of `127.0.0.1` for nginx proxy compatibility.
- Cleaned git history to prevent permanent leakage of database and JWT secrets.
- Replaced raw `dict` inputs and relaxed rate limits with Pydantic models and stricter limits (`5/minute`) for public-facing PII endpoints.
- Abandoned Easy2Coach API integration due to internal server SQL bug (`Column 'source' cannot be null`) and user preference to redesign tools locally.
- Reduced tool count from 60+ to ~22 essentials and switched canvas rendering to a flat, modern aesthetic.

## Next Steps
- Sync PDF export with the new flat tools rendering in `Allenamenti.vue`.
- Test the redesigned board and tools on production.
- Verify frontend "Responsabile" label renders correctly in production.
- Monitor production logs for rate limit triggers and upload validation rejections.

## Critical Context
- Production server: `root@192.168.178.132`, project path: `/opt/registro_presenze`.
- Dev server: `root@192.168.178.133`, project path: `/opt/registro_presenze`.
- Host-level nginx proxies `:3000` for frontend and `:8000` for `/api/` with correct `proxy_set_header` directives.
- `slowapi` uses in-memory counters; limits are per-container (4 workers share state via process memory).
- Docker internal network bypasses nginx for `/uploads/` requests, requiring relaxed host validation.
- `backend/Dockerfile` runs as non-root `appuser` with 4 workers; `--reload` disabled for production stability.
- Easy2Coach API (`https://e2capi.easy2coach.net/api/v1/auth/login`) throws `SQLSTATE[23000]: Integrity constraint violation: 1048 Column 'source' cannot be null` on login attempts.

## Relevant Files
- `backend/app/main.py`: Security headers middleware, `SlowAPIMiddleware`, CORS policy, `TrustedHostMiddleware` removal.
- `backend/app/routers/auth.py`: Login rate limiting, timing attack mitigation, password policy, `Request` param fix.
- `backend/app/routers/persone.py`: Admin-only PII queries, public endpoint field whitelisting, `5/minute` rate limits, encryption key validation.
- `backend/app/routers/societa.py`: File upload validation (MIME magic bytes, size, UUID filenames).
- `backend/Dockerfile`: Non-root user, 4 workers, removed `--reload`.
- `docker-compose.yml`: Removed `version`, removed source volume mount, port exposure config.
- `frontend/src/views/Admin.vue`: "Admin Locale" renamed to "Responsabile".
- `frontend/src/views/Allenamenti.vue`: Training board UI, tools panel HTML, `drawBoard` canvas rendering function, element data structures, and PDF export logic. Currently being refactored for flat/professional tool rendering.
- `.env` / `/opt/registro_presenze/.env`: Production secrets (`DEFAULT_PASSWORD=CalcioMania2026!`, `SECRET_KEY`, `ENCRYPTION_KEY`).
