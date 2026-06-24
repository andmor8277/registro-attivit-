from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from ..database import get_db
from ..routers.auth import get_current_user, check_societa
from ..schemas import CampoCreate, CampoUpdate, CampoAssegnazioneCreate, CampoAssegnazioneUpdate

router = APIRouter(prefix="/campi", tags=["campi"])

def check_campo_access(db, campo_id, user):
    if user.is_super_admin:
        return
    res = db.execute(text("SELECT societa_id FROM campi_da_gioco WHERE id = :id"), {"id": campo_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Campo non trovato")
    check_societa(user, row.societa_id)

@router.get("/")
def lista_campi(societa_id: int = None, db=Depends(get_db), user=Depends(get_current_user)):
    if not user.is_super_admin:
        societa_id = user.societa_id
    if societa_id:
        res = db.execute(
            text("SELECT * FROM campi_da_gioco WHERE societa_id = :sid ORDER BY ordine, etichetta"),
            {"sid": societa_id}
        )
    else:
        res = db.execute(text("SELECT * FROM campi_da_gioco ORDER BY ordine, etichetta"))
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/assegnazioni/settimana/{data_inizio}")
def assegnazioni_settimana(data_inizio: str, db=Depends(get_db), user=Depends(get_current_user)):
    from datetime import timedelta
    data_date = data_inizio.replace('-', '')
    data_int = int(data_date)
    data_fine = data_int + 4
    societa_filter = ""
    params = {"data_inizio": data_inizio, "data_inizio_int": data_int, "data_fine_int": data_fine}
    if not user.is_super_admin:
        societa_filter = " AND sa.societa_id = :sid"
        params["sid"] = user.societa_id
    res = db.execute(
        text(f"""
            SELECT sa.*, c.etichetta as campo_etichetta, c.tipo_campo,
                   cat.nome as categoria_nome, cat.anno as categoria_anno,
                   cat.ora_allenamento, cat.giorni
            FROM campi_assegnazioni sa
            LEFT JOIN campi_da_gioco c ON sa.campo_id = c.id
            LEFT JOIN categorie cat ON sa.categoria_id = cat.id
            WHERE (sa.data IS NULL AND sa.data_inizio = :data_inizio)
               OR (sa.data IS NOT NULL AND CAST(REPLACE(sa.data::TEXT, '-', '') AS INTEGER) BETWEEN :data_inizio_int AND :data_fine_int){societa_filter}
            ORDER BY cat.ora_allenamento ASC, cat.anno ASC, c.ordine ASC
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
            SELECT sa.*, c.etichetta as campo_etichetta, c.tipo_campo,
                   cat.nome as categoria_nome, cat.anno as categoria_anno,
                   cat.ora_allenamento, cat.giorni
            FROM campi_assegnazioni sa
            LEFT JOIN campi_da_gioco c ON sa.campo_id = c.id
            LEFT JOIN categorie cat ON sa.categoria_id = cat.id
            WHERE sa.data = :data{societa_filter}
            ORDER BY cat.ora_allenamento ASC, cat.anno ASC, c.ordine ASC
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
            SELECT sa.*, c.etichetta as campo_etichetta, c.tipo_campo,
                   cat.nome as categoria_nome, cat.anno as categoria_anno
            FROM campi_assegnazioni sa
            LEFT JOIN campi_da_gioco c ON sa.campo_id = c.id
            LEFT JOIN categorie cat ON sa.categoria_id = cat.id
            WHERE sa.weekend_id = :wid{societa_filter}
            ORDER BY cat.anno ASC, c.ordine ASC
        """),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def crea_campo(data: CampoCreate, db=Depends(get_db), user=Depends(get_current_user)):
    societa_id = data.societa_id
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO campi_da_gioco (etichetta, ordine, societa_id, tipo_campo)
            VALUES (:etichetta, :ordine, :societa_id, :tipo_campo)
            RETURNING *
        """),
        {
            "etichetta": data.etichetta,
            "ordine": data.ordine,
            "societa_id": societa_id,
            "tipo_campo": data.tipo_campo or "11",
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{campo_id}")
def aggiorna_campo(campo_id: int, data: CampoUpdate, db=Depends(get_db), user=Depends(get_current_user)):
    check_campo_access(db, campo_id, user)
    res = db.execute(
        text("""
            UPDATE campi_da_gioco SET
                etichetta = :etichetta,
                ordine = :ordine,
                tipo_campo = :tipo_campo
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": campo_id,
            "etichetta": data.etichetta,
            "ordine": data.ordine,
            "tipo_campo": data.tipo_campo,
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Campo non trovato")
    return dict(row._mapping)

@router.delete("/{campo_id}")
def elimina_campo(campo_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    check_campo_access(db, campo_id, user)
    db.execute(text("DELETE FROM campi_assegnazioni WHERE campo_id = :id"), {"id": campo_id})
    db.execute(text("DELETE FROM campi_da_gioco WHERE id = :id"), {"id": campo_id})
    db.commit()
    return {"ok": True}

# ── Assegnazioni CRUD ──

@router.post("/assegnazioni")
def crea_assegnazione(data: CampoAssegnazioneCreate, db=Depends(get_db), user=Depends(get_current_user)):
    societa_id = data.societa_id
    if not societa_id and not user.is_super_admin:
        societa_id = user.societa_id
    check_societa(user, societa_id)
    res = db.execute(
        text("""
            INSERT INTO campi_assegnazioni (
                campo_id, categoria_id, nome_squadra_esterna,
                tipo, data_inizio, data, weekend_id, societa_id, metacampo, is_default
            )
            VALUES (
                :campo_id, :categoria_id, :nome_squadra_esterna,
                :tipo, :data_inizio, :data, :weekend_id, :societa_id, :metacampo, :is_default
            )
            RETURNING *
        """),
        {
            "campo_id": data.campo_id,
            "categoria_id": data.categoria_id,
            "nome_squadra_esterna": data.nome_squadra_esterna,
            "tipo": data.tipo,
            "data_inizio": data.data_inizio,
            "data": data.data,
            "weekend_id": data.weekend_id,
            "societa_id": societa_id,
            "metacampo": data.metacampo,
            "is_default": data.is_default or False,
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/assegnazioni/{assegnazione_id}")
def aggiorna_assegnazione(assegnazione_id: int, data: CampoAssegnazioneUpdate, db=Depends(get_db), user=Depends(get_current_user)):
    if not user.is_super_admin:
        res = db.execute(text("SELECT societa_id FROM campi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
        row = res.fetchone()
        if not row:
            raise HTTPException(404, "Assegnazione non trovata")
        check_societa(user, row.societa_id)
    res = db.execute(
        text("""
            UPDATE campi_assegnazioni SET
                campo_id = :campo_id,
                categoria_id = :categoria_id,
                nome_squadra_esterna = :nome_squadra_esterna,
                tipo = :tipo,
                data_inizio = :data_inizio,
                data = :data,
                weekend_id = :weekend_id,
                metacampo = :metacampo
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": assegnazione_id,
            "campo_id": data.campo_id,
            "categoria_id": data.categoria_id,
            "nome_squadra_esterna": data.nome_squadra_esterna,
            "tipo": data.tipo,
            "data_inizio": data.data_inizio,
            "data": data.data,
            "weekend_id": data.weekend_id,
            "metacampo": data.metacampo,
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Assegnazione non trovata")
    return dict(row._mapping)

@router.delete("/assegnazioni/{assegnazione_id}")
def elimina_assegnazione(assegnazione_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    if not user.is_super_admin:
        res = db.execute(text("SELECT societa_id FROM campi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
        row = res.fetchone()
        if not row:
            raise HTTPException(404, "Assegnazione non trovata")
        check_societa(user, row.societa_id)
    db.execute(text("DELETE FROM campi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
    db.commit()
    return {"ok": True}

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
            SELECT sa.*, c.etichetta as campo_etichetta, c.tipo_campo,
                   cat.nome as categoria_nome, cat.anno as categoria_anno,
                   cat.ora_allenamento, cat.giorni
            FROM campi_assegnazioni sa
            LEFT JOIN campi_da_gioco c ON sa.campo_id = c.id
            LEFT JOIN categorie cat ON sa.categoria_id = cat.id
            WHERE sa.is_default = TRUE{societa_filter}
            ORDER BY cat.ora_allenamento ASC, cat.anno ASC, c.ordine ASC
        """),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/assegnazioni/default/apply")
def apply_default_week(data_inizio: str, db=Depends(get_db), user=Depends(get_current_user)):
    societa_id = user.societa_id if not user.is_super_admin else None
    if societa_id:
        db.execute(text("DELETE FROM campi_assegnazioni WHERE data_inizio = :di AND is_default = FALSE AND societa_id = :sid"), {"di": data_inizio, "sid": societa_id})
    else:
        db.execute(text("DELETE FROM campi_assegnazioni WHERE data_inizio = :di AND is_default = FALSE"), {"di": data_inizio})
    db.execute(
        text("""
            INSERT INTO campi_assegnazioni (campo_id, categoria_id, nome_squadra_esterna, tipo, data_inizio, data, weekend_id, societa_id, metacampo)
            SELECT campo_id, categoria_id, nome_squadra_esterna, tipo, :data_inizio, data, weekend_id, societa_id, metacampo
            FROM campi_assegnazioni
            WHERE is_default = TRUE
              AND (:sid IS NULL OR societa_id = :sid)
        """),
        {"data_inizio": data_inizio, "sid": societa_id}
    )
    db.commit()
    return {"ok": True}
