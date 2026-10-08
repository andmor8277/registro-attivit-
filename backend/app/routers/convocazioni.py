from fastapi import APIRouter, Depends, HTTPException
import re
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from pydantic import BaseModel
from ..database import get_db
from ..models import Convocazione, ConvocazioneGara, ConvocazioneGiocatore, Persona, Utente
from .auth import get_current_user

router = APIRouter(prefix="/convocazioni", tags=["convocazioni"])

def get_societa_filter(current_user: Utente):
    if current_user.is_super_admin:
        return None
    return current_user.societa_id

class GiocatoreIn(BaseModel):
    persona_id: int
    posizione: int
    non_presente: bool = False

class GaraIn(BaseModel):
    numero: int
    partita_id: Optional[int] = None
    gara: Optional[str] = None
    data: Optional[date] = None
    campo: Optional[str] = None
    indirizzo: Optional[str] = None
    appuntamento: Optional[str] = None
    inizio_gara: Optional[str] = None
    allenatore: Optional[str] = None
    allenatori: Optional[List[int]] = None
    livello: Optional[str] = None
    giocatori: List[GiocatoreIn] = []

class ConvocazioneIn(BaseModel):
    categoria_id: int
    weekend_id: Optional[int] = None
    data_inizio: date
    data_fine: Optional[date] = None
    note: Optional[str] = None
    esclusioni: Optional[List[dict]] = []
    gare: List[GaraIn] = []

@router.get("/")
def lista(categoria_id: Optional[int] = None, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import text
    societa_id = get_societa_filter(current_user)
    where_soc = "AND c.societa_id = :sid" if societa_id else ""
    params = {}
    where_cat = ""
    if categoria_id is not None:
        where_cat = "AND c.categoria_id = :cid"
        params["cid"] = categoria_id
    if societa_id:
        params["sid"] = societa_id
    res = db.execute(text(f"""
        SELECT c.id, c.weekend_id, c.data_inizio, c.data_fine, c.categoria_id, w.nome as weekend_nome
        FROM convocazioni c
        LEFT JOIN weekend w ON c.weekend_id = w.id
        WHERE 1=1 {where_cat} {where_soc}
        ORDER BY c.data_inizio DESC
    """), params)
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/{cid}")
def dettaglio(cid: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    # Verifica società
    societa_id = get_societa_filter(current_user)
    if societa_id and c.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    gare = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).order_by(ConvocazioneGara.numero).all()
    result_gare = []
    for g in gare:
        giocatori = db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).order_by(ConvocazioneGiocatore.posizione).all()
        persone = []
        for gk in giocatori:
            p = db.query(Persona).filter(Persona.id == gk.persona_id).first()
            persone.append({"persona_id": gk.persona_id, "posizione": gk.posizione, "nome": p.nome if p else "", "cognome": p.cognome if p else "", "non_presente": bool(gk.non_presente)})
        livello_val = getattr(g, 'livello', None)
        if not livello_val and g.partita_id:
            p_row = db.execute(text("SELECT livello FROM partite WHERE id = :pid"), {"pid": g.partita_id}).fetchone()
            if p_row and p_row[0]:
                livello_val = p_row[0]
        result_gare.append({
            "id": g.id, "partita_id": g.partita_id, "numero": g.numero, "gara": g.gara, "data": g.data,
            "campo": g.campo, "indirizzo": g.indirizzo, "appuntamento": g.appuntamento,
            "inizio_gara": g.inizio_gara, "allenatore": g.allenatore, "allenatori": g.allenatori or [],
            "livello": livello_val or "", "giocatori": persone
        })
    w_row = db.execute(text("SELECT nome FROM weekend WHERE id = :wid"), {"wid": c.weekend_id}).fetchone() if c.weekend_id else None
    weekend_nome = w_row[0] if w_row else None
    return {"id": c.id, "categoria_id": c.categoria_id, "weekend_id": c.weekend_id, "weekend_nome": weekend_nome, "data_inizio": c.data_inizio, "data_fine": c.data_fine, "note": c.note, "esclusioni": c.esclusioni or [], "gare": result_gare}

@router.post("/")
def crea(data: ConvocazioneIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from ..models import Categoria
    from sqlalchemy import text
    cat = db.query(Categoria).filter(Categoria.id == data.categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    if not current_user.is_super_admin and cat.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa categoria")
    societa_id = cat.societa_id

    # Trova weekend corrispondente se non fornito
    weekend_id = data.weekend_id
    if not weekend_id and data.data_inizio:
        w_row = db.execute(text("""
            SELECT id, data_inizio, data_fine FROM weekend
            WHERE societa_id = :sid AND data_inizio <= :di AND data_fine >= :di
            LIMIT 1
        """), {"sid": societa_id, "di": data.data_inizio}).fetchone()
        if w_row:
            weekend_id = w_row[0]

    if not weekend_id:
        raise HTTPException(
            status_code=400,
            detail="Non è possibile creare una convocazione senza un weekend programmato dal Responsabile."
        )

    w_info = db.execute(text("SELECT data_inizio, data_fine FROM weekend WHERE id = :wid"), {"wid": weekend_id}).fetchone()
    data_inizio = w_info[0] if w_info else data.data_inizio
    data_fine = w_info[1] if w_info else data.data_fine

    c = Convocazione(societa_id=societa_id, categoria_id=data.categoria_id, weekend_id=weekend_id, data_inizio=data_inizio, data_fine=data_fine, note=data.note, esclusioni=data.esclusioni)
    db.add(c)
    db.flush()
    used_pids = {g.partita_id for g in data.gare if g.partita_id}
    for g in data.gare:
        partita_id = g.partita_id
        dt = g.data or data_inizio
        if not partita_id and dt:
            p_rows = db.execute(text("""
                SELECT id FROM partite
                WHERE categoria_id = :cid AND data_partite = :data
                ORDER BY ora ASC NULLS LAST, id ASC
            """), {"cid": data.categoria_id, "data": dt}).fetchall()
            for r in p_rows:
                if r[0] not in used_pids:
                    partita_id = r[0]
                    used_pids.add(partita_id)
                    break

        ora_short = None
        if g.inizio_gara:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.inizio_gara)
            if m:
                ora_short = m.group(0)
        appunt_time = None
        if g.appuntamento:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.appuntamento)
            if m:
                appunt_time = m.group(0)

        g_campo = g.campo.strip() if g.campo else ""
        g_indirizzo = g.indirizzo.strip() if g.indirizzo else ""
        if g_campo and not g_indirizzo and societa_id:
            cs = db.execute(
                text("SELECT indirizzo FROM campi_sportivi WHERE societa_id = :sid AND LOWER(TRIM(nome)) = LOWER(TRIM(:nome)) LIMIT 1"),
                {"sid": societa_id, "nome": g_campo}
            ).fetchone()
            if cs and cs[0]:
                g_indirizzo = cs[0]
        if g_campo and g_indirizzo and societa_id:
            try:
                db.execute(text("""
                    INSERT INTO campi_sportivi (societa_id, nome, indirizzo, updated_at)
                    VALUES (:sid, :nome, :indirizzo, CURRENT_TIMESTAMP)
                    ON CONFLICT (societa_id, nome) DO UPDATE
                    SET indirizzo = EXCLUDED.indirizzo,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE EXCLUDED.indirizzo IS NOT NULL AND TRIM(EXCLUDED.indirizzo) != ''
                """), {"sid": societa_id, "nome": g_campo, "indirizzo": g_indirizzo})
            except Exception as e:
                pass

        p_livello = None
        if partita_id:
            p_row = db.execute(text("SELECT livello FROM partite WHERE id = :pid"), {"pid": partita_id}).fetchone()
            if p_row and p_row[0]:
                p_livello = p_row[0]
        g_livello = g.livello or p_livello

        if not partita_id and weekend_id:
            # Nuova partita aggiunta dal mister al weekend del responsabile: registrala in partite
            res_p = db.execute(text("""
                INSERT INTO partite (
                    categoria_id, data_partite, ora, ora_presentazione,
                    avversario, campo, indirizzo, casa_fuori, societa_id, weekend_id, livello
                ) VALUES (
                    :cid, :data, :ora, :appunt,
                    :avv, :campo, :indirizzo, :cf, :sid, :wid, :livello
                ) RETURNING id
            """), {
                "cid": data.categoria_id,
                "data": dt,
                "ora": ora_short,
                "appunt": appunt_time,
                "avv": g.gara or "Gara",
                "campo": g_campo,
                "indirizzo": g_indirizzo,
                "cf": "casa",
                "sid": societa_id,
                "wid": weekend_id,
                "livello": g_livello
            })
            partita_id = res_p.scalar()
            if partita_id:
                used_pids.add(partita_id)
        elif partita_id:
            db.execute(text("""
                UPDATE partite SET
                    ora = COALESCE(:ora, ora),
                    ora_presentazione = COALESCE(:appunt, ora_presentazione),
                    campo = COALESCE(:campo, campo),
                    indirizzo = COALESCE(:indirizzo, indirizzo),
                    livello = COALESCE(:livello, livello)
                WHERE id = :pid
            """), {
                "pid": partita_id,
                "ora": ora_short,
                "appunt": appunt_time,
                "campo": g_campo if g_campo else None,
                "indirizzo": g_indirizzo if g_indirizzo else None,
                "livello": g.livello if g.livello else None
            })

        gara = ConvocazioneGara(convocazione_id=c.id, partita_id=partita_id, numero=g.numero, gara=g.gara, data=dt,
            campo=g_campo, indirizzo=g_indirizzo, appuntamento=g.appuntamento,
            inizio_gara=g.inizio_gara, allenatore=g.allenatore, allenatori=g.allenatori or [],
            livello=g_livello)
        db.add(gara)
        db.flush()
        for gk in g.giocatori:
            db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=gk.persona_id, posizione=gk.posizione, non_presente=1 if gk.non_presente else 0))
    db.commit()
    return {"id": c.id}

@router.put("/{cid}")
def aggiorna(cid: int, data: ConvocazioneIn, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import text
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    # Verifica società
    societa_id = get_societa_filter(current_user)
    if societa_id and c.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")

    weekend_id = data.weekend_id or c.weekend_id
    if not weekend_id and data.data_inizio and c.societa_id:
        w_row = db.execute(text("""
            SELECT id, data_inizio, data_fine FROM weekend
            WHERE societa_id = :sid AND data_inizio <= :di AND data_fine >= :di
            LIMIT 1
        """), {"sid": c.societa_id, "di": data.data_inizio}).fetchone()
        if w_row:
            weekend_id = w_row[0]

    if not weekend_id:
        raise HTTPException(
            status_code=400,
            detail="La convocazione deve essere associata a un weekend programmato dal Responsabile."
        )

    w_info = db.execute(text("SELECT data_inizio, data_fine FROM weekend WHERE id = :wid"), {"wid": weekend_id}).fetchone()
    if w_info:
        c.data_inizio = w_info[0]
        c.data_fine = w_info[1]
    else:
        c.data_inizio = data.data_inizio
        c.data_fine = data.data_fine

    c.weekend_id = weekend_id
    c.note = data.note
    c.esclusioni = data.esclusioni

    # Elimina e ricrea gare
    gare_old = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).all()
    for g in gare_old:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).delete()
    db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).delete()
    used_pids = {g.partita_id for g in data.gare if g.partita_id}
    for g in data.gare:
        partita_id = g.partita_id
        dt = g.data or c.data_inizio
        if not partita_id and dt:
            p_rows = db.execute(text("""
                SELECT id FROM partite
                WHERE categoria_id = :cid AND data_partite = :data
                ORDER BY ora ASC NULLS LAST, id ASC
            """), {"cid": c.categoria_id, "data": dt}).fetchall()
            for r in p_rows:
                if r[0] not in used_pids:
                    partita_id = r[0]
                    used_pids.add(partita_id)
                    break

        ora_short = None
        if g.inizio_gara:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.inizio_gara)
            if m:
                ora_short = m.group(0)
        appunt_time = None
        if g.appuntamento:
            m = re.search(r'\b([01]?\d|2[0-3]):[0-5]\d\b', g.appuntamento)
            if m:
                appunt_time = m.group(0)

        g_campo = g.campo.strip() if g.campo else ""
        g_indirizzo = g.indirizzo.strip() if g.indirizzo else ""
        if g_campo and not g_indirizzo and c.societa_id:
            cs = db.execute(
                text("SELECT indirizzo FROM campi_sportivi WHERE societa_id = :sid AND LOWER(TRIM(nome)) = LOWER(TRIM(:nome)) LIMIT 1"),
                {"sid": c.societa_id, "nome": g_campo}
            ).fetchone()
            if cs and cs[0]:
                g_indirizzo = cs[0]
        if g_campo and g_indirizzo and c.societa_id:
            try:
                db.execute(text("""
                    INSERT INTO campi_sportivi (societa_id, nome, indirizzo, updated_at)
                    VALUES (:sid, :nome, :indirizzo, CURRENT_TIMESTAMP)
                    ON CONFLICT (societa_id, nome) DO UPDATE
                    SET indirizzo = EXCLUDED.indirizzo,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE EXCLUDED.indirizzo IS NOT NULL AND TRIM(EXCLUDED.indirizzo) != ''
                """), {"sid": c.societa_id, "nome": g_campo, "indirizzo": g_indirizzo})
            except Exception as e:
                pass

        p_livello = None
        if partita_id:
            p_row = db.execute(text("SELECT livello FROM partite WHERE id = :pid"), {"pid": partita_id}).fetchone()
            if p_row and p_row[0]:
                p_livello = p_row[0]
        g_livello = g.livello or p_livello

        if not partita_id and weekend_id:
            # Nuova partita aggiunta dal mister al weekend del responsabile: registrala in partite
            res_p = db.execute(text("""
                INSERT INTO partite (
                    categoria_id, data_partite, ora, ora_presentazione,
                    avversario, campo, indirizzo, casa_fuori, societa_id, weekend_id, livello
                ) VALUES (
                    :cid, :data, :ora, :appunt,
                    :avv, :campo, :indirizzo, :cf, :sid, :wid, :livello
                ) RETURNING id
            """), {
                "cid": c.categoria_id,
                "data": dt,
                "ora": ora_short,
                "appunt": appunt_time,
                "avv": g.gara or "Gara",
                "campo": g_campo,
                "indirizzo": g_indirizzo,
                "cf": "casa",
                "sid": c.societa_id,
                "wid": weekend_id,
                "livello": g_livello
            })
            partita_id = res_p.scalar()
            if partita_id:
                used_pids.add(partita_id)
        elif partita_id:
            db.execute(text("""
                UPDATE partite SET
                    ora = COALESCE(:ora, ora),
                    ora_presentazione = COALESCE(:appunt, ora_presentazione),
                    campo = COALESCE(:campo, campo),
                    indirizzo = COALESCE(:indirizzo, indirizzo),
                    livello = COALESCE(:livello, livello)
                WHERE id = :pid
            """), {
                "pid": partita_id,
                "ora": ora_short,
                "appunt": appunt_time,
                "campo": g_campo if g_campo else None,
                "indirizzo": g_indirizzo if g_indirizzo else None,
                "livello": g.livello if g.livello else None
            })

        gara = ConvocazioneGara(convocazione_id=cid, partita_id=partita_id, numero=g.numero, gara=g.gara, data=dt,
            campo=g_campo, indirizzo=g_indirizzo, appuntamento=g.appuntamento,
            inizio_gara=g.inizio_gara, allenatore=g.allenatore, allenatori=g.allenatori or [],
            livello=g_livello)
        db.add(gara)
        db.flush()
        for gk in g.giocatori:
            db.add(ConvocazioneGiocatore(gara_id=gara.id, persona_id=gk.persona_id, posizione=gk.posizione, non_presente=1 if gk.non_presente else 0))
    db.commit()
    return {"ok": True}

@router.delete("/{cid}")
def elimina(cid: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    c = db.query(Convocazione).filter(Convocazione.id == cid).first()
    if not c:
        raise HTTPException(status_code=404, detail="Non trovata")
    societa_id = get_societa_filter(current_user)
    if societa_id and c.societa_id != societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato")
    gare = db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).all()
    for g in gare:
        db.query(ConvocazioneGiocatore).filter(ConvocazioneGiocatore.gara_id == g.id).delete()
    db.query(ConvocazioneGara).filter(ConvocazioneGara.convocazione_id == cid).delete()
    db.delete(c)
    db.commit()
    return {"ok": True}

from datetime import timedelta

@router.get("/presenze-settimana/{categoria_id}")
def presenze_settimana(categoria_id: int, data_gara: date, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    from ..models import Registro, CodicePresenza, Categoria
    cat = db.query(Categoria).filter(Categoria.id == categoria_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Categoria non trovata")
    if not current_user.is_super_admin and cat.societa_id != current_user.societa_id:
        raise HTTPException(status_code=403, detail="Non autorizzato a operare su questa categoria")
    # Settimana precedente: lun-dom prima del weekend di gara
    giorno_settimana = data_gara.weekday()  # 0=lun, 6=dom
    inizio_sett = data_gara - timedelta(days=giorno_settimana + 7)
    fine_sett = inizio_sett + timedelta(days=6)

    # Codici assenza
    codici_assenza = [c.codice for c in db.query(CodicePresenza).filter(CodicePresenza.tipo == "assenza").all()]

    persone = db.query(Persona).filter(Persona.categoria_id == categoria_id).all()
    result = []
    for p in persone:
        count = db.query(Registro).filter(
            Registro.persona_id == p.id,
            Registro.categoria_id == categoria_id,
            Registro.data >= inizio_sett,
            Registro.data <= fine_sett,
            ~Registro.codice.in_(codici_assenza)
        ).count()
        result.append({
            "persona_id": p.id,
            "nome": p.nome,
            "cognome": p.cognome,
            "allenamenti": count
        })
    return result
