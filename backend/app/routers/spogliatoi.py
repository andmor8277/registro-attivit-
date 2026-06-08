from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from ..database import get_db
from ..routers.auth import get_current_user

router = APIRouter(prefix="/spogliatoi", tags=["spogliatoi"])

@router.get("/")
def lista_spogliatoi(societa_id: int = None, db=Depends(get_db), user=Depends(get_current_user)):
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
    from datetime import timedelta
    data_date = data_inizio.replace('-', '')
    data_int = int(data_date)
    data_fine = data_int + 4  # Mon-Fri
    res = db.execute(
        text("""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno,
                   c.ora_allenamento, c.giorni
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE (sa.data IS NULL AND sa.data_inizio = :data_inizio)
               OR (sa.data IS NOT NULL AND CAST(REPLACE(sa.data::TEXT, '-', '') AS INTEGER) BETWEEN :data_inizio_int AND :data_fine_int)
            ORDER BY c.ora_allenamento ASC, c.anno ASC, s.ordine ASC
        """),
        {"data_inizio": data_inizio, "data_inizio_int": data_int, "data_fine_int": data_fine}
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/assegnazioni/giorno/{data_giorno}")
def assegnazioni_giorno(data_giorno: str, db=Depends(get_db), user=Depends(get_current_user)):
    res = db.execute(
        text("""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno,
                   c.ora_allenamento, c.giorni
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE sa.data = :data
            ORDER BY c.ora_allenamento ASC, c.anno ASC, s.ordine ASC
        """),
        {"data": data_giorno}
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/assegnazioni/weekend/{weekend_id}")
def assegnazioni_weekend(weekend_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    res = db.execute(
        text("""
            SELECT sa.*, s.etichetta as spogliatoio_etichetta,
                   c.nome as categoria_nome, c.anno as categoria_anno
            FROM spogliatoi_assegnazioni sa
            LEFT JOIN spogliatoi s ON sa.spogliatoio_id = s.id
            LEFT JOIN categorie c ON sa.categoria_id = c.id
            WHERE sa.weekend_id = :wid
            ORDER BY c.anno ASC, s.ordine ASC
        """),
        {"wid": weekend_id}
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.post("/")
def crea_spogliatoio(data: dict, db=Depends(get_db), user=Depends(get_current_user)):
    res = db.execute(
        text("""
            INSERT INTO spogliatoi (etichetta, ordine, societa_id)
            VALUES (:etichetta, :ordine, :societa_id)
            RETURNING *
        """),
        {
            "etichetta": data.get("etichetta"),
            "ordine": data.get("ordine", 0),
            "societa_id": data.get("societa_id"),
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/{spogliatoio_id}")
def aggiorna_spogliatoio(spogliatoio_id: int, data: dict, db=Depends(get_db), user=Depends(get_current_user)):
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
            "etichetta": data.get("etichetta"),
            "ordine": data.get("ordine"),
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Spogliatoio non trovato")
    return dict(row._mapping)

@router.delete("/{spogliatoio_id}")
def elimina_spogliatoio(spogliatoio_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    db.execute(text("DELETE FROM spogliatoi_assegnazioni WHERE spogliatoio_id = :id"), {"id": spogliatoio_id})
    db.execute(text("DELETE FROM spogliatoi WHERE id = :id"), {"id": spogliatoio_id})
    db.commit()
    return {"ok": True}

# ── Assegnazioni CRUD ──

@router.post("/assegnazioni")
def crea_assegnazione(data: dict, db=Depends(get_db), user=Depends(get_current_user)):
    res = db.execute(
        text("""
            INSERT INTO spogliatoi_assegnazioni (
                spogliatoio_id, categoria_id, nome_squadra_esterna,
                tipo, data_inizio, data, weekend_id, societa_id
            )
            VALUES (
                :spogliatoio_id, :categoria_id, :nome_squadra_esterna,
                :tipo, :data_inizio, :data, :weekend_id, :societa_id
            )
            RETURNING *
        """),
        {
            "spogliatoio_id": data.get("spogliatoio_id"),
            "categoria_id": data.get("categoria_id"),
            "nome_squadra_esterna": data.get("nome_squadra_esterna"),
            "tipo": data.get("tipo", "casa"),
            "data_inizio": data.get("data_inizio"),
            "data": data.get("data"),
            "weekend_id": data.get("weekend_id"),
            "societa_id": data.get("societa_id"),
        }
    )
    db.commit()
    row = res.fetchone()
    return dict(row._mapping)

@router.put("/assegnazioni/{assegnazione_id}")
def aggiorna_assegnazione(assegnazione_id: int, data: dict, db=Depends(get_db), user=Depends(get_current_user)):
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
            "spogliatoio_id": data.get("spogliatoio_id"),
            "categoria_id": data.get("categoria_id"),
            "nome_squadra_esterna": data.get("nome_squadra_esterna"),
            "tipo": data.get("tipo", "casa"),
            "data_inizio": data.get("data_inizio"),
            "data": data.get("data"),
            "weekend_id": data.get("weekend_id"),
        }
    )
    db.commit()
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Assegnazione non trovata")
    return dict(row._mapping)

@router.delete("/assegnazioni/{assegnazione_id}")
def elimina_assegnazione(assegnazione_id: int, db=Depends(get_db), user=Depends(get_current_user)):
    db.execute(text("DELETE FROM spogliatoi_assegnazioni WHERE id = :id"), {"id": assegnazione_id})
    db.commit()
    return {"ok": True}
