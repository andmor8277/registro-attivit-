from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from ..database import get_db
from ..routers.auth import get_current_user, check_societa

router = APIRouter(prefix="/weekend", tags=["weekend"])

def check_weekend_access(db, weekend_id, user):
    if user.is_super_admin:
        return
    res = db.execute(text("SELECT societa_id FROM weekend WHERE id = :id"), {"id": weekend_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Weekend non trovato")
    check_societa(user, row.societa_id)

@router.get("/")
def lista_weekend(societa_id: int = None, db=Depends(get_db), user=Depends(get_current_user)):
    if not user.is_super_admin:
        societa_id = user.societa_id
    if societa_id:
        res = db.execute(
            text("SELECT * FROM weekend WHERE societa_id = :sid ORDER BY data_inizio DESC"),
            {"sid": societa_id}
        )
    else:
        res = db.execute(text("SELECT * FROM weekend ORDER BY data_inizio DESC"))
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/{weekend_id}/partite")
def weekend_partite(weekend_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    check_weekend_access(db, weekend_id, user)
    res = db.execute(
        text("""
            SELECT p.*, c.nome as categoria_nome, c.anno as categoria_anno
            FROM partite p
            LEFT JOIN categorie c ON p.categoria_id = c.id
            WHERE p.weekend_id = :wid
            ORDER BY c.anno ASC, p.data_partite DESC, p.ora ASC
        """),
        {"wid": weekend_id}
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def crea_weekend(data: dict, db=Depends(get_db), user=Depends(get_current_user)):
    societa_id = data.get("societa_id")
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO weekend (nome, data_inizio, data_fine, societa_id)
            VALUES (:nome, :data_inizio, :data_fine, :societa_id)
            RETURNING *
        """),
        {
            "nome": data.get("nome"),
            "data_inizio": data.get("data_inizio"),
            "data_fine": data.get("data_fine"),
            "societa_id": societa_id,
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{weekend_id}")
def aggiorna_weekend(weekend_id: int, data: dict, db=Depends(get_db), user=Depends(get_current_user)):
    check_weekend_access(db, weekend_id, user)
    res = db.execute(
        text("""
            UPDATE weekend SET
                nome = :nome,
                data_inizio = :data_inizio,
                data_fine = :data_fine
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": weekend_id,
            "nome": data.get("nome"),
            "data_inizio": data.get("data_inizio"),
            "data_fine": data.get("data_fine"),
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Weekend non trovato")
    return dict(row._mapping)

@router.delete("/{weekend_id}")
def elimina_weekend(weekend_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    check_weekend_access(db, weekend_id, user)
    db.execute(text("DELETE FROM weekend WHERE id = :id"), {"id": weekend_id})
    db.commit()
    return {"ok": True}
