from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from .. import models, schemas
from ..database import get_db
from ..routers.auth import get_current_user
from ..models import Utente
from typing import Optional

router = APIRouter(prefix="/registro", tags=["registro"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

@router.get("/mese/{categoria_id}/{anno}/{mese}")
def get_mese(categoria_id: int, anno: int, mese: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import extract
    societa_id = get_societa_filter(current_user)
    query = db.query(models.Registro).filter(
        models.Registro.categoria_id == categoria_id,
        extract("year", models.Registro.data) == anno,
        extract("month", models.Registro.data) == mese
    )
    if societa_id:
        query = query.filter(models.Registro.societa_id == societa_id)
    records = query.all()

    # Se non è la categoria Portieri, mergia anche le presenze dalla categoria Portieri per i portieri di questa categoria
    cat_row = db.execute(text("SELECT is_portieri, societa_id FROM categorie WHERE id = :id"), {"id": categoria_id}).first()
    if cat_row and cat_row.is_portieri != 1:
        target_societa = cat_row.societa_id or societa_id
        sid_param = {"sid": target_societa} if target_societa else {}
        portieri_cat = db.execute(text(
            "SELECT id FROM categorie WHERE is_portieri = 1 AND is_archiviata = 0" + (" AND societa_id = :sid" if target_societa else "")
        ), sid_param).first()

        if portieri_cat:
            home_keys = {(r.persona_id, str(r.data)) for r in records}
            portieri_rows = db.execute(text("""
                SELECT r.id, r.persona_id, r.data, r.codice, r.categoria_id, r.societa_id
                FROM registro r
                WHERE r.categoria_id = :pid
                AND r.persona_id IN (
                    SELECT p.id FROM persone p
                    WHERE p.categoria_id = :cid
                    AND p.gruppo_id IN (
                        SELECT g.id FROM gruppi g WHERE LOWER(g.nome) = 'portieri'
                    )
                )
                AND EXTRACT(YEAR FROM r.data) = :anno
                AND EXTRACT(MONTH FROM r.data) = :mese
            """), {"pid": portieri_cat.id, "cid": categoria_id, "anno": anno, "mese": mese}).fetchall()

            for pr in portieri_rows:
                key = (pr.persona_id, str(pr.data))
                if key not in home_keys:
                    from types import SimpleNamespace
                    records.append(SimpleNamespace(
                        id=pr.id, persona_id=pr.persona_id, data=pr.data,
                        codice=pr.codice, categoria_id=pr.categoria_id, societa_id=pr.societa_id,
                        is_portieri_readthrough=True
                    ))

    result = []
    for r in records:
        if hasattr(r, '__dict__'):
            d = r.__dict__.copy()
            d['is_portieri_readthrough'] = d.get('is_portieri_readthrough', False)
            if isinstance(d.get('data'), str):
                d['data'] = d['data'][:10]
            result.append(d)
        else:
            d = {
                'id': r.id, 'persona_id': r.persona_id, 'data': str(r.data)[:10],
                'codice': r.codice, 'categoria_id': r.categoria_id, 'societa_id': r.societa_id,
                'is_portieri_readthrough': False
            }
            result.append(d)
    return result

@router.post("/", response_model=schemas.RegistroOut)
def upsert_registro(entry: schemas.RegistroEntry, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    societa_id = get_societa_filter(current_user) or current_user.societa_id

    # La persona deve appartenere alla societa' dell'utente. persona_id arriva dalla richiesta e
    # fin qui non veniva mai controllato: si potevano scrivere presenze per tesserati di un'altra
    # societa'. Il super_admin va escluso esplicitamente perche' qui sopra si usa il
    # get_societa_filter LOCALE di questo modulo, che per lui torna None e lascia quindi
    # societa_id = societa_id propria: senza l'esclusione gli si bloccherebbe l'accesso alle
    # altre societa', che e' invece previsto.
    p_row = db.execute(text("SELECT societa_id FROM persone WHERE id = :pid"), {"pid": entry.persona_id}).first()
    if not p_row:
        raise HTTPException(status_code=404, detail="Persona non trovata")
    if not current_user.is_super_admin and p_row.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato su questa persona")

    # Se la categoria corrente NON è Portieri ma la persona è un portiere, reindirizza alla categoria Portieri
    target_categoria_id = entry.categoria_id
    if target_categoria_id:
        cat_row = db.execute(text("SELECT is_portieri, societa_id FROM categorie WHERE id = :id"), {"id": target_categoria_id}).first()
        if not cat_row:
            raise HTTPException(status_code=404, detail="Categoria non trovata")
        # Anche la categoria deve essere della societa' dell'utente: senza questo filtro, la
        # DELETE qui sotto (che usa categoria_id controllato dal client) poteva cancellare la
        # riga di presenza reale di un'altra societa'.
        if not current_user.is_super_admin and cat_row.societa_id != societa_id:
            raise HTTPException(status_code=403, detail="Non autorizzato su questa categoria")
        # NOTA (scelta del titolare, 2026-11-16): qui NON si applica il controllo di
        # assegnazione categorie (utente_categorie) che invece allenamenti.py fa. Il perche':
        # la lista che il mister clicca in Scelta.vue arriva da GET /categorie/by-stagione,
        # che filtra solo per societa' e non per assegnazione, quindi oggi i mister vedono e
        # usano legittimamente tutte le categorie della propria societa' pur avendo in media
        # una sola riga in utente_categorie. Aggiungerlo qui li bloccherebbe fuori dal registro.
        # Se in futuro si vuole stringere, prima vanno completate le assegnazioni in Admin e
        # allineato anche by-stagione, poi si riattiva questo controllo.
        if cat_row:
            if not societa_id:
                societa_id = cat_row.societa_id
            if cat_row.is_portieri != 1:
                persona = db.execute(text("SELECT gruppo_id FROM persone WHERE id = :pid"), {"pid": entry.persona_id}).first()
                if persona and persona.gruppo_id:
                    gruppo_row = db.execute(text("SELECT nome FROM gruppi WHERE id = :gid"), {"gid": persona.gruppo_id}).first()
                    if gruppo_row and gruppo_row.nome.lower() == "portieri":
                        portieri_cat = db.execute(text(
                            "SELECT id FROM categorie WHERE is_portieri = 1 AND is_archiviata = 0" + (" AND societa_id = :sid" if societa_id else "")
                        ), {"sid": societa_id} if societa_id else {}).first()
                        if portieri_cat:
                            target_categoria_id = portieri_cat.id

    data = entry.model_dump()
    data["societa_id"] = societa_id
    data["categoria_id"] = target_categoria_id
    data.pop("id", None)
    stmt = pg_insert(models.Registro).values(**data)
    stmt = stmt.on_conflict_do_update(
        index_elements=[models.Registro.persona_id, models.Registro.data, models.Registro.categoria_id],
        set_={
            "codice": stmt.excluded.codice,
            "societa_id": stmt.excluded.societa_id,
        }
    )
    db.execute(stmt)
    db.commit()
    if target_categoria_id is not None and target_categoria_id != entry.categoria_id:
        # categoria_id arriva dal client: senza il filtro di societa' questa DELETE poteva
        # colpire la riga di presenza reale di un'altra societa' (persona_id, data e
        # categoria_id sono tutti enumerabili). Il super_admin resta escluso, come sopra.
        extra = ""
        params = {"pid": entry.persona_id, "data": entry.data, "cid": entry.categoria_id}
        if not current_user.is_super_admin:
            extra = " AND societa_id = :sid"
            params["sid"] = societa_id
        db.execute(
            text(f"DELETE FROM registro WHERE persona_id = :pid AND data = :data AND categoria_id = :cid{extra}"),
            params
        )
        db.commit()
    r = db.query(models.Registro).filter(
        models.Registro.persona_id == entry.persona_id,
        models.Registro.data == entry.data,
        models.Registro.categoria_id == target_categoria_id
    ).first()
    return r
