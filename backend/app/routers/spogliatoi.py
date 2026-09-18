from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from ..database import get_db
from ..routers.auth import get_current_user, check_societa
from ..core.security import get_staff_admin
from ..schemas import SpogliatoioCreate, SpogliatoioUpdate, SpogliatoioAssegnazioneCreate, SpogliatoioAssegnazioneUpdate, SpogliatoioAssegnazioneSettimanaSave

router = APIRouter(prefix="/spogliatoi", tags=["spogliatoi"])

def check_spogliatoio_access(db, spogliatoio_id, user):
    if user.is_super_admin:
        return
    res = db.execute(text("SELECT societa_id FROM spogliatoi WHERE id = :id"), {"id": spogliatoio_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Spogliatoio non trovato")
    check_societa(user, row.societa_id)

@router.get("/")
def lista_spogliatoi(societa_id: int = None, db=Depends(get_db), user=Depends(get_current_user)):
    if not user.is_super_admin:
        societa_id = user.societa_id
    if societa_id:
        res = db.execute(
            text("SELECT * FROM spogliatoi WHERE societa_id = :sid ORDER BY ordine, etichetta"),
            {"sid": societa_id}
        )
    else:
        res = db.execute(text("SELECT * FROM spogliatoi ORDER BY ordine, etichetta"))
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/assegnazioni/settimana/{data_inizio}")
def assegnazioni_settimana(data_inizio: str, db=Depends(get_db), user=Depends(get_current_user)):
    from datetime import datetime, timedelta
    data_inizio_date = datetime.strptime(data_inizio, "%Y-%m-%d").date()
    data_fine_date = data_inizio_date + timedelta(days=4)
    societa_filter = ""
    params = {"data_inizio": data_inizio, "data_inizio_date": data_inizio_date, "data_fine_date": data_fine_date}
    if not user.is_super_admin:
        societa_filter = " AND sa.societa_id = :sid"
        params["sid"] = user.societa_id
    res = db.execute(
        text(f"""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno,
                   c.ora_allenamento, c.giorni
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE COALESCE(sa.is_default, FALSE) = FALSE
              AND (
                (sa.data IS NULL AND sa.data_inizio = :data_inizio_date)
                OR (sa.data IS NOT NULL AND sa.data BETWEEN :data_inizio_date AND :data_fine_date)
              ){societa_filter}
            ORDER BY c.ora_allenamento ASC, c.anno ASC, s.ordine ASC
        """),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/assegnazioni/giorno/{data_giorno}")
def assegnazioni_giorno(data_giorno: str, db=Depends(get_db), user=Depends(get_current_user)):
    societa_filter = ""
    params = {"data": data_giorno}
    if not user.is_super_admin:
        societa_filter = " AND sa.societa_id = :sid"
        params["sid"] = user.societa_id
    res = db.execute(
        text(f"""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno,
                   c.ora_allenamento, c.giorni
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE sa.data = :data{societa_filter}
            ORDER BY c.ora_allenamento ASC, c.anno ASC, s.ordine ASC
        """),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/assegnazioni/weekend/{weekend_id}")
def assegnazioni_weekend(weekend_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    societa_filter = ""
    params = {"wid": weekend_id}
    if not user.is_super_admin:
        societa_filter = " AND sa.societa_id = :sid"
        params["sid"] = user.societa_id
    res = db.execute(
        text(f"""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE sa.weekend_id = :wid{societa_filter}
            ORDER BY c.anno ASC, s.ordine ASC
        """),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def crea_spogliatoio(data: SpogliatoioCreate, db=Depends(get_db), user=Depends(get_staff_admin)):
    societa_id = data.societa_id
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO spogliatoi (etichetta, ordine, societa_id)
            VALUES (:etichetta, :ordine, :societa_id)
            RETURNING *
        """),
        {
            "etichetta": data.etichetta,
            "ordine": data.ordine,
            "societa_id": societa_id,
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{spogliatoio_id}")
def aggiorna_spogliatoio(spogliatoio_id: int, data: SpogliatoioUpdate, db=Depends(get_db), user=Depends(get_staff_admin)):
    check_spogliatoio_access(db, spogliatoio_id, user)
    res = db.execute(
        text("""
            UPDATE spogliatoi SET
                etichetta = :etichetta,
                ordine = :ordine
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": spogliatoio_id,
            "etichetta": data.etichetta,
            "ordine": data.ordine,
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Spogliatoio non trovato")
    return dict(row._mapping)

@router.delete("/{spogliatoio_id}")
def elimina_spogliatoio(spogliatoio_id: int, db=Depends(get_db), user=Depends(get_staff_admin)):
    check_spogliatoio_access(db, spogliatoio_id, user)
    db.execute(text("DELETE FROM spogliatoi_assegnazioni WHERE spogliatoio_id = :id"), {"id": spogliatoio_id})
    db.execute(text("DELETE FROM spogliatoi WHERE id = :id"), {"id": spogliatoio_id})
    db.commit()
    return {"ok": True}

# ── Assegnazioni CRUD ──

@router.post("/assegnazioni")
def crea_assegnazione(data: SpogliatoioAssegnazioneCreate, db=Depends(get_db), user=Depends(get_staff_admin)):
    societa_id = data.societa_id
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO spogliatoi_assegnazioni (
                spogliatoio_id, categoria_id, nome_squadra_esterna,
                tipo, data_inizio, data, weekend_id, societa_id, is_default
            )
            VALUES (
                :spogliatoio_id, :categoria_id, :nome_squadra_esterna,
                :tipo, :data_inizio, :data, :weekend_id, :societa_id, :is_default
            )
            RETURNING *
        """),
        {
            "spogliatoio_id": data.spogliatoio_id,
            "categoria_id": data.categoria_id,
            "nome_squadra_esterna": data.nome_squadra_esterna,
            "tipo": data.tipo,
            "data_inizio": data.data_inizio,
            "data": data.data,
            "weekend_id": data.weekend_id,
            "societa_id": societa_id,
            "is_default": data.is_default or False,
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/assegnazioni/{assegnazione_id}")
def aggiorna_assegnazione(assegnazione_id: int, data: SpogliatoioAssegnazioneUpdate, db=Depends(get_db), user=Depends(get_staff_admin)):
    if not user.is_super_admin:
        res = db.execute(text("SELECT societa_id FROM spogliatoi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
        row = res.fetchone()
        if not row:
            raise HTTPException(404, "Assegnazione non trovata")
        check_societa(user, row.societa_id)
    res = db.execute(
        text("""
            UPDATE spogliatoi_assegnazioni SET
                spogliatoio_id = :spogliatoio_id,
                categoria_id = :categoria_id,
                nome_squadra_esterna = :nome_squadra_esterna,
                tipo = :tipo,
                data_inizio = :data_inizio,
                data = :data,
                weekend_id = :weekend_id
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": assegnazione_id,
            "spogliatoio_id": data.spogliatoio_id,
            "categoria_id": data.categoria_id,
            "nome_squadra_esterna": data.nome_squadra_esterna,
            "tipo": data.tipo,
            "data_inizio": data.data_inizio,
            "data": data.data,
            "weekend_id": data.weekend_id,
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Assegnazione non trovata")
    return dict(row._mapping)

@router.delete("/assegnazioni/{assegnazione_id}")
def elimina_assegnazione(assegnazione_id: int, db=Depends(get_db), user=Depends(get_staff_admin)):
    if not user.is_super_admin:
        res = db.execute(text("SELECT societa_id FROM spogliatoi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
        row = res.fetchone()
        if not row:
            raise HTTPException(404, "Assegnazione non trovata")
        check_societa(user, row.societa_id)
    db.execute(text("DELETE FROM spogliatoi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
    db.commit()
    return {"ok": True}

@router.post("/assegnazioni/settimana")
def salva_assegnazioni_settimana(data: SpogliatoioAssegnazioneSettimanaSave, db=Depends(get_db), user=Depends(get_staff_admin)):
    from datetime import datetime, timedelta
    societa_id = data.societa_id
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    data_inizio_date = datetime.strptime(data.data_inizio, "%Y-%m-%d").date()
    data_fine_date = data_inizio_date + timedelta(days=4)
    db.execute(
        text("""
            DELETE FROM spogliatoi_assegnazioni
            WHERE weekend_id IS NULL
              AND COALESCE(is_default, FALSE) = FALSE
              AND (data_inizio = :data_inizio_date OR data BETWEEN :data_inizio_date AND :data_fine_date)
              AND (:sid IS NULL OR societa_id = :sid)
        """),
        {"data_inizio_date": data_inizio_date, "data_fine_date": data_fine_date, "sid": societa_id}
    )
    for a in data.assegnazioni:
        db.execute(
            text("""
                INSERT INTO spogliatoi_assegnazioni (
                    spogliatoio_id, categoria_id, nome_squadra_esterna,
                    tipo, data_inizio, data, weekend_id, societa_id, is_default
                )
                VALUES (
                    :spogliatoio_id, :categoria_id, :nome_squadra_esterna,
                    :tipo, :data_inizio, :data, :weekend_id, :societa_id, FALSE
                )
            """),
            {
                "spogliatoio_id": a.spogliatoio_id,
                "categoria_id": a.categoria_id,
                "nome_squadra_esterna": a.nome_squadra_esterna,
                "tipo": a.tipo or "casa",
                "data_inizio": data.data_inizio,
                "data": a.data,
                "weekend_id": a.weekend_id,
                "societa_id": a.societa_id or societa_id,
            }
        )
    db.commit()
    return {"ok": True, "count": len(data.assegnazioni)}

# ── Settimana Tipo (Default Week) ──

@router.get("/assegnazioni/default")
def assegnazioni_default(db=Depends(get_db), user=Depends(get_current_user)):
    societa_filter = ""
    params = {}
    if not user.is_super_admin:
        societa_filter = " AND sa.societa_id = :sid"
        params["sid"] = user.societa_id
    res = db.execute(
        text(f"""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno,
                   c.ora_allenamento, c.giorni
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE sa.is_default = TRUE{societa_filter}
            ORDER BY c.ora_allenamento ASC, c.anno ASC, s.ordine ASC
        """),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/assegnazioni/default/apply")
def apply_default_week(data_inizio: str, db=Depends(get_db), user=Depends(get_staff_admin)):
    from datetime import datetime, timedelta
    data_inizio_date = datetime.strptime(data_inizio, "%Y-%m-%d").date()
    data_fine_date = data_inizio_date + timedelta(days=4)
    societa_id = user.societa_id if not user.is_super_admin else None
    db.execute(
        text("""
            DELETE FROM spogliatoi_assegnazioni
            WHERE weekend_id IS NULL
              AND COALESCE(is_default, FALSE) = FALSE
              AND (data_inizio = :data_inizio_date OR data BETWEEN :data_inizio_date AND :data_fine_date)
              AND (:sid IS NULL OR societa_id = :sid)
        """),
        {"data_inizio_date": data_inizio_date, "data_fine_date": data_fine_date, "sid": societa_id}
    )
    db.execute(
        text("""
            INSERT INTO spogliatoi_assegnazioni (spogliatoio_id, categoria_id, nome_squadra_esterna, tipo, data_inizio, data, weekend_id, societa_id)
            SELECT spogliatoio_id, categoria_id, nome_squadra_esterna, tipo, :data_inizio, data, weekend_id, societa_id
            FROM spogliatoi_assegnazioni
            WHERE is_default = TRUE
              AND (:sid IS NULL OR societa_id = :sid)
        """),
        {"data_inizio": data_inizio, "sid": societa_id}
    )
    db.commit()
    return {"ok": True}
