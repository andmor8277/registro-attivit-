from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from ..database import get_db
from ..routers.auth import get_current_user, check_societa
from ..schemas import PartitaCreate, PartitaUpdate

router = APIRouter(prefix="/partite", tags=["partite"])

def check_partita_access(db, partita_id, user):
    """Verifica che la partita appartenga alla societa dell'utente."""
    if user.is_super_admin:
        return
    res = db.execute(text("SELECT societa_id FROM partite WHERE id = :id"), {"id": partita_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Partita non trovata")
    check_societa(user, row.societa_id)

@router.get("/")
def lista_partite(categoria_id: int = None, societa_id: int = None, db=Depends(get_db), user=Depends(get_current_user)):
    if not user.is_super_admin:
        societa_id = user.societa_id
    conditions = []
    params = {}
    if societa_id:
        conditions.append("p.societa_id = :sid")
        params["sid"] = societa_id
    if categoria_id:
        conditions.append("p.categoria_id = :cid")
        params["cid"] = categoria_id
    where = " WHERE " + " AND ".join(conditions) if conditions else ""
    res = db.execute(text(f"SELECT * FROM partite p{where} ORDER BY data_partite DESC"), params)
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def crea_partita(data: PartitaCreate, db=Depends(get_db), user=Depends(get_current_user)):
    societa_id = data.societa_id
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO partite (categoria_id, data_partite, ora, ora_presentazione, avversario, campo, indirizzo, casa_fuori, mister_id, risultato, goal_punti, goal_contro, note, societa_id, weekend_id)
            VALUES (:categoria_id, :data_partite, :ora, :ora_presentazione, :avversario, :campo, :indirizzo, :casa_fuori, :mister_id, :risultato, :goal_punti, :goal_contro, :note, :societa_id, :weekend_id)
            RETURNING *
        """),
        {
            "categoria_id": data.categoria_id,
            "data_partite": data.data_partite,
            "ora": data.ora,
            "ora_presentazione": data.ora_presentazione,
            "avversario": data.avversario,
            "campo": data.campo,
            "indirizzo": data.indirizzo,
            "casa_fuori": data.casa_fuori,
            "mister_id": data.mister_id,
            "risultato": data.risultato,
            "goal_punti": data.goal_punti,
            "goal_contro": data.goal_contro,
            "note": data.note,
            "societa_id": societa_id,
            "weekend_id": data.weekend_id,
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{partita_id}")
def aggiorna_partita(partita_id: int, data: PartitaUpdate, db=Depends(get_db), user=Depends(get_current_user)):
    check_partita_access(db, partita_id, user)
    res = db.execute(
        text("""
            UPDATE partite SET
                categoria_id = :categoria_id,
                data_partite = :data_partite,
                ora = :ora,
                ora_presentazione = :ora_presentazione,
                avversario = :avversario,
                campo = :campo,
                indirizzo = :indirizzo,
                casa_fuori = :casa_fuori,
                mister_id = :mister_id,
                risultato = :risultato,
                goal_punti = :goal_punti,
                goal_contro = :goal_contro,
                note = :note,
                weekend_id = :weekend_id
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": partita_id,
            "categoria_id": data.categoria_id,
            "data_partite": data.data_partite,
            "ora": data.ora,
            "ora_presentazione": data.ora_presentazione,
            "avversario": data.avversario,
            "campo": data.campo,
            "indirizzo": data.indirizzo,
            "casa_fuori": data.casa_fuori,
            "mister_id": data.mister_id,
            "risultato": data.risultato,
            "goal_punti": data.goal_punti,
            "goal_contro": data.goal_contro,
            "note": data.note,
            "weekend_id": data.weekend_id,
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Partita non trovata")
    return dict(row._mapping)

@router.delete("/{partita_id}")
def elimina_partita(partita_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    check_partita_access(db, partita_id, user)
    db.execute(text("DELETE FROM partite WHERE id = :id"), {"id": partita_id})
    db.commit()
    return {"ok": True}
