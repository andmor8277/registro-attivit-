from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy import text
from typing import Optional
from ..database import get_db
from ..routers.auth import get_current_user, check_societa
from ..core.security import get_staff_admin
from ..core.deps import get_societa_filter, resolve_tenant_societa_id
from ..schemas import WeekendCreate, WeekendUpdate

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
def lista_weekend(societa_id: Optional[int] = Query(None), request: Request = None, db=Depends(get_db), user=Depends(get_current_user)):
    sid = get_societa_filter(user, societa_id, request)
    if sid:
        res = db.execute(
            text("SELECT * FROM weekend WHERE societa_id = :sid ORDER BY data_inizio DESC"),
            {"sid": sid}
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
def crea_weekend(data: WeekendCreate, request: Request = None, db=Depends(get_db), user=Depends(get_staff_admin)):
    societa_id = resolve_tenant_societa_id(user, data.societa_id, request)
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO weekend (nome, data_inizio, data_fine, societa_id)
            VALUES (:nome, :data_inizio, :data_fine, :societa_id)
            RETURNING *
        """),
        {
            "nome": data.nome,
            "data_inizio": data.data_inizio,
            "data_fine": data.data_fine,
            "societa_id": societa_id,
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{weekend_id}")
def aggiorna_weekend(weekend_id: int, data: WeekendUpdate, db=Depends(get_db), user=Depends(get_staff_admin)):
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
            "nome": data.nome,
            "data_inizio": data.data_inizio,
            "data_fine": data.data_fine,
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Weekend non trovato")
    return dict(row._mapping)

@router.delete("/{weekend_id}")
def elimina_weekend(weekend_id: int, db=Depends(get_db), user=Depends(get_staff_admin)):
    check_weekend_access(db, weekend_id, user)
    db.execute(text("DELETE FROM campi_assegnazioni WHERE weekend_id = :id"), {"id": weekend_id})
    db.execute(text("DELETE FROM spogliatoi_assegnazioni WHERE weekend_id = :id"), {"id": weekend_id})
    db.execute(text("DELETE FROM partite WHERE weekend_id = :id"), {"id": weekend_id})
    db.execute(text("DELETE FROM weekend WHERE id = :id"), {"id": weekend_id})
    db.commit()
    return {"ok": True}
