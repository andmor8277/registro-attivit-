from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from ..database import get_db
from ..routers.auth import get_current_user, check_societa

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
def crea_partita(data: dict, db=Depends(get_db), user=Depends(get_current_user)):
    societa_id = data.get("societa_id")
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
            "categoria_id": data.get("categoria_id"),
            "data_partite": data.get("data_partite"),
            "ora": data.get("ora"),
            "ora_presentazione": data.get("ora_presentazione"),
            "avversario": data.get("avversario"),
            "campo": data.get("campo"),
            "indirizzo": data.get("indirizzo"),
            "casa_fuori": data.get("casa_fuori"),
            "mister_id": data.get("mister_id"),
            "risultato": data.get("risultato"),
            "goal_punti": data.get("goal_punti", 0),
            "goal_contro": data.get("goal_contro", 0),
            "note": data.get("note"),
            "societa_id": societa_id,
            "weekend_id": data.get("weekend_id"),
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{partita_id}")
def aggiorna_partita(partita_id: int, data: dict, db=Depends(get_db), user=Depends(get_current_user)):
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
            "categoria_id": data.get("categoria_id"),
            "data_partite": data.get("data_partite"),
            "ora": data.get("ora"),
            "ora_presentazione": data.get("ora_presentazione"),
            "avversario": data.get("avversario"),
            "campo": data.get("campo"),
            "indirizzo": data.get("indirizzo"),
            "casa_fuori": data.get("casa_fuori"),
            "mister_id": data.get("mister_id"),
            "risultato": data.get("risultato"),
            "goal_punti": data.get("goal_punti", 0),
            "goal_contro": data.get("goal_contro", 0),
            "note": data.get("note"),
            "weekend_id": data.get("weekend_id"),
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
