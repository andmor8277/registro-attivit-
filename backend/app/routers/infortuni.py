from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import date, timedelta
from typing import Optional
from pydantic import BaseModel
from ..database import get_db
from ..routers.auth import get_current_user
from ..core.security import get_infermeria
from ..core.deps import get_societa_filter, resolve_tenant_societa_id
from ..models import Utente

router = APIRouter(prefix="/infortuni", tags=["infortuni"])

class InfortunioCreate(BaseModel):
    persona_id: int
    categoria_id: Optional[int] = None
    data_inizio: str
    giorni_assenza: int = 0
    tipo_infortunio: Optional[str] = None
    note: Optional[str] = None
    societa_id: Optional[int] = None

class InfortunioUpdate(BaseModel):
    data_inizio: Optional[str] = None
    giorni_assenza: Optional[int] = None
    data_fine: Optional[str] = None
    tipo_infortunio: Optional[str] = None
    note: Optional[str] = None

@router.get("/")
def lista_infortuni(
    categoria_id: Optional[int] = None,
    attivi: Optional[bool] = None,
    societa_id: Optional[int] = Query(None),
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    sid = get_societa_filter(current_user, societa_id, request)
    params = {"sid": sid} if sid else {}
    soc_filter = " AND i.societa_id = :sid" if sid else ""

    conditions = []
    if categoria_id:
        conditions.append("i.categoria_id = :cid")
        params["cid"] = categoria_id

    if attivi is not None:
        if attivi:
            conditions.append("(i.data_fine IS NULL OR i.data_fine >= CURRENT_DATE)")
        else:
            conditions.append("(i.data_fine IS NOT NULL AND i.data_fine < CURRENT_DATE)")

    where = " WHERE " + " AND ".join(["1=1"]) + soc_filter
    if conditions:
        where = " WHERE " + " AND ".join(conditions) + soc_filter

    query = f"""
        SELECT i.*, p.nome as persona_nome, p.cognome as persona_cognome,
               p.numero_maglia, c.nome as categoria_nome, c.anno as categoria_anno
        FROM infortuni i
        LEFT JOIN persone p ON i.persona_id = p.id
        LEFT JOIN categorie c ON i.categoria_id = c.id
        {where}
        ORDER BY
          CASE WHEN i.data_fine IS NULL OR i.data_fine >= CURRENT_DATE THEN 0 ELSE 1 END,
          i.data_inizio DESC
    """

    rows = db.execute(text(query), params).fetchall()

    # Le note dell'infortunio sono descrizioni cliniche in testo libero: le vede solo chi se ne
    # occupa (infermeria, e chi amministra). Nessun'altra pagina della UI le usa: Scelta.vue
    # mostra il tipo, Registro.vue solo le date, Home.vue il conteggio.
    is_admin = current_user.is_admin or current_user.is_super_admin or current_user.ruolo == 'segreteria'
    puo_vedere_note = is_admin or current_user.ruolo == 'infermeria'

    result = []
    for r in rows:
        d = dict(r._mapping)
        if isinstance(d.get('data_inizio'), date):
            d['data_inizio'] = d['data_inizio'].isoformat()
        if isinstance(d.get('data_fine'), date):
            d['data_fine'] = d['data_fine'].isoformat()
        if isinstance(d.get('creato_il'), (date,)):
            d['creato_il'] = d['creato_il'].isoformat()
        if not puo_vedere_note:
            d['note'] = None
        d['attivo'] = d['data_fine'] is None or d['data_fine'] >= date.today().isoformat()
        result.append(d)
    return result

@router.post("/")
def crea_infortunio(
    data: InfortunioCreate,
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_infermeria)
):
    societa_id = resolve_tenant_societa_id(
        current_user,
        data.societa_id,
        request,
        categoria_id=data.categoria_id,
        persona_id=data.persona_id,
        db=db
    )
    data_inizio = date.fromisoformat(data.data_inizio)
    data_fine = (data_inizio + timedelta(days=data.giorni_assenza)).isoformat() if data.giorni_assenza > 0 else None

    res = db.execute(
        text("""
            INSERT INTO infortuni (persona_id, categoria_id, societa_id, data_inizio, giorni_assenza, data_fine, tipo_infortunio, note, creato_il)
            VALUES (:pid, :cid, :sid, :di, :ga, :df, :ti, :n, NOW())
            RETURNING *
        """),
        {
            "pid": data.persona_id,
            "cid": data.categoria_id,
            "sid": societa_id,
            "di": data_inizio,
            "ga": data.giorni_assenza,
            "df": data_fine,
            "ti": data.tipo_infortunio,
            "n": data.note,
        }
    )
    db.commit()
    row = res.fetchone()
    d = dict(row._mapping)
    if isinstance(d.get('data_inizio'), date):
        d['data_inizio'] = d['data_inizio'].isoformat()
    if isinstance(d.get('data_fine'), date):
        d['data_fine'] = d['data_fine'].isoformat()
    return d

@router.put("/{infortunio_id}")
def aggiorna_infortunio(
    infortunio_id: int,
    data: InfortunioUpdate,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_infermeria)
):
    societa_id = get_societa_filter(current_user)
    if societa_id:
        check = db.execute(text("SELECT societa_id FROM infortuni WHERE id = :id"), {"id": infortunio_id}).first()
        if not check:
            raise HTTPException(status_code=404, detail="Infortunio non trovato")
        if check.societa_id != societa_id:
            raise HTTPException(status_code=403, detail="Non autorizzato")

    existing = db.execute(text("SELECT * FROM infortuni WHERE id = :id"), {"id": infortunio_id}).first()
    if not existing:
        raise HTTPException(status_code=404, detail="Infortunio non trovato")

    updates = []
    params = {"id": infortunio_id}

    # Si usa model_fields_set e non "if x is not None": con il secondo, un campo mandato vuoto
    # non veniva applicato e l'infermiere non riusciva piu' a svuotare giorni_assenza ne' a
    # cancellare le note. Si applica cio' che il client ha davvero mandato, vuoto compreso.
    campi = data.model_fields_set

    def _a_data(valore):
        return date.fromisoformat(valore) if valore else None

    if "data_inizio" in campi:
        updates.append("data_inizio = :di")
        params["di"] = _a_data(data.data_inizio)

    if "giorni_assenza" in campi:
        updates.append("giorni_assenza = :ga")
        params["ga"] = data.giorni_assenza

    if "tipo_infortunio" in campi:
        updates.append("tipo_infortunio = :ti")
        params["ti"] = data.tipo_infortunio

    if "note" in campi:
        updates.append("note = :n")
        params["n"] = data.note

    # data_fine deve restare coerente con data_inizio + giorni_assenza. Prima veniva ricalcolata
    # solo quando arrivava giorni_assenza, e una data_fine esplicita era accettata solo in assenza
    # di giorni: cambiando da sola la data di inizio, la data fine restava quella vecchia e la
    # scheda mostrava un periodo che non tornava.
    if "data_fine" in campi and "giorni_assenza" not in campi:
        updates.append("data_fine = :df")
        params["df"] = _a_data(data.data_fine)
    elif "data_inizio" in campi or "giorni_assenza" in campi:
        inizio = _a_data(data.data_inizio) if "data_inizio" in campi else existing.data_inizio
        giorni = data.giorni_assenza if "giorni_assenza" in campi else existing.giorni_assenza
        updates.append("data_fine = :df")
        params["df"] = (inizio + timedelta(days=giorni)).isoformat() if (inizio and giorni and giorni > 0) else None

    if not updates:
        return {"ok": True}

    res = db.execute(
        text(f"UPDATE infortuni SET {', '.join(updates)} WHERE id = :id RETURNING *"),
        params
    )
    db.commit()
    row = res.fetchone()
    d = dict(row._mapping)
    if isinstance(d.get('data_inizio'), date):
        d['data_inizio'] = d['data_inizio'].isoformat()
    if isinstance(d.get('data_fine'), date):
        d['data_fine'] = d['data_fine'].isoformat()
    return d

@router.delete("/{infortunio_id}")
def elimina_infortunio(
    infortunio_id: int,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_infermeria)
):
    societa_id = get_societa_filter(current_user)
    if societa_id:
        check = db.execute(text("SELECT societa_id FROM infortuni WHERE id = :id"), {"id": infortunio_id}).first()
        if not check:
            raise HTTPException(status_code=404, detail="Infortunio non trovato")
        if check.societa_id != societa_id:
            raise HTTPException(status_code=403, detail="Non autorizzato")

    db.execute(text("DELETE FROM infortuni WHERE id = :id"), {"id": infortunio_id})
    db.commit()
    return {"ok": True}

@router.post("/{infortunio_id}/chiudi")
def chiudi_infortunio(
    infortunio_id: int,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_infermeria)
):
    societa_id = get_societa_filter(current_user)
    if societa_id:
        check = db.execute(text("SELECT societa_id FROM infortuni WHERE id = :id"), {"id": infortunio_id}).first()
        if not check:
            raise HTTPException(status_code=404, detail="Infortunio non trovato")
        if check.societa_id != societa_id:
            raise HTTPException(status_code=403, detail="Non autorizzato")

    res = db.execute(
        text("UPDATE infortuni SET data_fine = CURRENT_DATE WHERE id = :id RETURNING *"),
        {"id": infortunio_id}
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Infortunio non trovato")
    d = dict(row._mapping)
    if isinstance(d.get('data_inizio'), date):
        d['data_inizio'] = d['data_inizio'].isoformat()
    if isinstance(d.get('data_fine'), date):
        d['data_fine'] = d['data_fine'].isoformat()
    return d

@router.get("/scaduti")
def segnala_scaduti(
    societa_id: Optional[int] = Query(None),
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    sid = get_societa_filter(current_user, societa_id, request)
    params = {"sid": sid} if sid else {}
    soc_filter = " AND i.societa_id = :sid" if sid else ""

    rows = db.execute(
        text(f"""
            SELECT i.*, p.nome as persona_nome, p.cognome as persona_cognome
            FROM infortuni i
            LEFT JOIN persone p ON i.persona_id = p.id
            WHERE i.data_fine IS NOT NULL AND i.data_fine < CURRENT_DATE AND i.data_fine >= CURRENT_DATE - INTERVAL '7 days'{soc_filter}
            ORDER BY i.data_fine DESC
        """),
        params
    ).fetchall()

    result = []
    for r in rows:
        d = dict(r._mapping)
        if isinstance(d.get('data_inizio'), date):
            d['data_inizio'] = d['data_inizio'].isoformat()
        if isinstance(d.get('data_fine'), date):
            d['data_fine'] = d['data_fine'].isoformat()
        result.append(d)
    return result
