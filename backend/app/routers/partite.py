from fastapi import APIRouter, Depends, HTTPException, Request, Query
from sqlalchemy import text
import re
from typing import Optional
from ..database import get_db
from ..routers.auth import get_current_user, check_societa
from ..core.security import get_staff_admin
from ..core.deps import get_societa_filter, resolve_tenant_societa_id
from ..schemas import PartitaCreate, PartitaUpdate

router = APIRouter(prefix="/partite", tags=["partite"])

def check_partite_access(db, partita_id, user):
    """Verifica che la partita appartenga alla societa dell'utente."""
    if user.is_super_admin:
        return
    res = db.execute(text("SELECT societa_id FROM partite WHERE id = :id"), {"id": partita_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Partita non trovata")
    check_societa(user, row.societa_id)

def check_categoria(db, user, categoria_id):
    """Verifica che la categoria appartenga alla societa dell'utente."""
    if user.is_super_admin or not categoria_id:
        return
    res = db.execute(text("SELECT societa_id FROM categorie WHERE id = :id"), {"id": categoria_id})
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Categoria non trovata")
    if row.societa_id != user.societa_id:
        raise HTTPException(403, "Categoria di un'altra società")

@router.get("/")
def lista_partite(
    categoria_id: Optional[int] = None,
    societa_id: Optional[int] = Query(None),
    request: Request = None,
    db=Depends(get_db),
    user=Depends(get_current_user)
):
    sid = get_societa_filter(user, societa_id, request)
    conditions = []
    params = {}
    if sid:
        conditions.append("p.societa_id = :sid")
        params["sid"] = sid
    if categoria_id:
        conditions.append("p.categoria_id = :cid")
        params["cid"] = categoria_id
    where = " WHERE " + " AND ".join(conditions) if conditions else ""
    res = db.execute(text(f"SELECT * FROM partite p{where} ORDER BY data_partite DESC"), params)
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

@router.get("/campi-sportivi")
def lista_campi_sportivi(
    societa_id: Optional[int] = Query(None),
    request: Request = None,
    db=Depends(get_db),
    user=Depends(get_current_user)
):
    sid = get_societa_filter(user, societa_id, request)
    where = "WHERE societa_id = :sid" if sid else ""
    params = {"sid": sid} if sid else {}
    res = db.execute(
        text(f"SELECT id, nome, indirizzo FROM campi_sportivi {where} ORDER BY nome ASC"),
        params
    )
    rows = res.fetchall()
    return [dict(r._mapping) for r in rows]

def _clean_str(val):
    if val is None:
        return None
    s = str(val).strip()
    return s if s else None

def _clean_int(val):
    if val is None or val == "":
        return None
    try:
        return int(val)
    except (ValueError, TypeError):
        return None


# Anticipo dell'ora di presentazione rispetto all'inizio gara, in minuti.
# E' una precompilazione: il Responsabile la vede nel form e la puo' sempre cambiare.
MINUTI_PRESENTAZIONE = {"casa": 45, "fuori": 60}


def _default_ora_presentazione(ora, casa_fuori):
    """Calcola l'ora di presentazione: 45' prima in casa, 60' in trasferta.

    Restituisce None se l'ora gara non e' impostata o non e' leggibile, cosi' il
    campo resta vuoto invece di riempirsi di un valore inventato.
    """
    if not ora:
        return None
    m = re.match(r"^\s*(\d{1,2}):(\d{2})", str(ora))
    if not m:
        return None
    h, mi = int(m.group(1)), int(m.group(2))
    if h > 23 or mi > 59:
        return None
    taglio = MINUTI_PRESENTAZIONE["fuori" if str(casa_fuori or "").strip().lower() == "fuori" else "casa"]
    totale = h * 60 + mi - taglio
    if totale < 0:
        # una gara poco dopo mezzanotte non puo' produrre un'ora negativa: si resta a mezzanotte
        totale = 0
    return "%02d:%02d" % (totale // 60, totale % 60)

@router.post("/")
def crea_partita(data: PartitaCreate, request: Request = None, db=Depends(get_db), user=Depends(get_staff_admin)):
    societa_id = resolve_tenant_societa_id(user, data.societa_id, request, categoria_id=data.categoria_id, db=db)
    check_societa(user, societa_id)
    check_categoria(db, user, data.categoria_id)

    if not data.data_partite or not str(data.data_partite).strip():
        raise HTTPException(400, "La data della partita è obbligatoria")
    if not data.categoria_id:
        raise HTTPException(400, "La categoria è obbligatoria")

    ora = _clean_str(data.ora)
    ora_pres = _clean_str(data.ora_presentazione)
    if ora_pres is None:
        # In creazione la presentazione viene precompilata dall'orario gara (45' casa, 60'
        # trasferta). Non e' un vincolo: il Responsabile la modifica dal form quando serve.
        ora_pres = _default_ora_presentazione(ora, data.casa_fuori)
    avversario = _clean_str(data.avversario)
    campo = _clean_str(data.campo)
    indirizzo = _clean_str(data.indirizzo)
    casa_fuori = _clean_str(data.casa_fuori) or "casa"
    mister_id = _clean_int(data.mister_id)
    mister_manuale = _clean_str(data.mister_manuale)
    risultato = _clean_str(data.risultato)
    note = _clean_str(data.note)
    weekend_id = _clean_int(data.weekend_id)
    livello = _clean_str(data.livello)

    # Se il campo è specificato ma l'indirizzo è vuoto, recupera l'indirizzo memorizzato
    if campo and not indirizzo:
        cs = db.execute(
            text("SELECT indirizzo FROM campi_sportivi WHERE societa_id = :sid AND LOWER(TRIM(nome)) = LOWER(TRIM(:nome)) LIMIT 1"),
            {"sid": societa_id, "nome": campo}
        ).fetchone()
        if cs and cs[0]:
            indirizzo = cs[0]

    res = db.execute(
        text("""
            INSERT INTO partite (categoria_id, data_partite, ora, ora_presentazione, avversario, campo, indirizzo, casa_fuori, mister_id, mister_manuale, risultato, goal_punti, goal_contro, note, societa_id, weekend_id, livello)
            VALUES (:categoria_id, :data_partite, :ora, :ora_presentazione, :avversario, :campo, :indirizzo, :casa_fuori, :mister_id, :mister_manuale, :risultato, :goal_punti, :goal_contro, :note, :societa_id, :weekend_id, :livello)
            RETURNING *
        """),
        {
            "categoria_id": data.categoria_id,
            "data_partite": data.data_partite,
            "ora": ora,
            "ora_presentazione": ora_pres,
            "avversario": avversario,
            "campo": campo,
            "indirizzo": indirizzo,
            "casa_fuori": casa_fuori,
            "mister_id": mister_id,
            "mister_manuale": mister_manuale,
            "risultato": risultato,
            "goal_punti": data.goal_punti or 0,
            "goal_contro": data.goal_contro or 0,
            "note": note,
            "societa_id": societa_id,
            "weekend_id": weekend_id,
            "livello": livello,
        }
    )
    row = res.fetchone()
    if not row:
        raise HTTPException(500, "Errore creazione partita")
    db.commit()

    partita_dict = dict(row._mapping)
    pid = partita_dict["id"]

    # Salva o aggiorna indirizzo del campo sportivo per riutilizzo futuro
    if campo and indirizzo:
        try:
            db.execute(text("""
                INSERT INTO campi_sportivi (societa_id, nome, indirizzo, updated_at)
                VALUES (:sid, :nome, :indirizzo, CURRENT_TIMESTAMP)
                ON CONFLICT (societa_id, nome) DO UPDATE
                SET indirizzo = EXCLUDED.indirizzo,
                    updated_at = CURRENT_TIMESTAMP
                WHERE EXCLUDED.indirizzo IS NOT NULL AND TRIM(EXCLUDED.indirizzo) != ''
            """), {"sid": societa_id, "nome": campo, "indirizzo": indirizzo})
            db.commit()
        except Exception as e:
            print(f"Avviso salvataggio campo_sportivo: {e}")

    # Collega retroattivamente eventuale convocazione_gara esistente per la stessa categoria e data
    try:
        db.execute(text("""
            UPDATE convocazione_gare cg
            SET partita_id = :pid
            FROM convocazioni c
            WHERE cg.convocazione_id = c.id
              AND c.categoria_id = :cid
              AND (cg.data = :dt OR (cg.data IS NULL AND c.data_inizio = :dt))
              AND cg.partita_id IS NULL
        """), {"pid": pid, "cid": data.categoria_id, "dt": data.data_partite})
        db.commit()
    except Exception as e:
        print(f"Avviso auto-collegamento convocazione_gare: {e}")

    return partita_dict

@router.put("/{partita_id}")
def aggiorna_partita(partita_id: int, data: PartitaUpdate, db=Depends(get_db), user=Depends(get_staff_admin)):
    check_partite_access(db, partita_id, user)
    check_categoria(db, user, data.categoria_id)

    ora = _clean_str(data.ora)
    # "non mandato" e "mandato vuoto" sono due cose diverse qui: questa rotta riscrive tutta la
    # riga, quindi un client che non include il campo lo scriverebbe NULL. E' esattamente cosi'
    # che l'ora di presentazione spariva salvando dalla pagina Programmazione Gare, il cui form
    # non lo prevede. Si conserva il valore gia' a posto quando il campo non arriva.
    ora_pres_inviato = "ora_presentazione" in data.model_fields_set
    ora_pres = _clean_str(data.ora_presentazione) if ora_pres_inviato else None
    avversario = _clean_str(data.avversario)
    campo = _clean_str(data.campo)
    indirizzo = _clean_str(data.indirizzo)
    casa_fuori = _clean_str(data.casa_fuori) or "casa"
    mister_id = _clean_int(data.mister_id)
    mister_manuale = _clean_str(data.mister_manuale)
    risultato = _clean_str(data.risultato)
    note = _clean_str(data.note)
    weekend_id = _clean_int(data.weekend_id)
    livello = _clean_str(data.livello)
    data_partite = _clean_str(data.data_partite)

    res_soc = db.execute(text("SELECT societa_id, ora_presentazione FROM partite WHERE id = :id"), {"id": partita_id}).fetchone()
    soc_id = res_soc[0] if res_soc else user.societa_id

    if not ora_pres_inviato:
        # Il campo non e' nel payload: si riporta quello gia' salvato (il tipo TIME arriva come
        # datetime.time, si riduce a HH:MM). Se la riga non ce l'ha proprio, si precompila.
        ora_pres = str(res_soc[1])[:5] if res_soc and res_soc[1] else None
        if ora_pres is None:
            ora_pres = _default_ora_presentazione(ora, casa_fuori)

    # Se il campo è specificato ma l'indirizzo è vuoto, recupera l'indirizzo memorizzato
    if campo and not indirizzo:
        cs = db.execute(
            text("SELECT indirizzo FROM campi_sportivi WHERE societa_id = :sid AND LOWER(TRIM(nome)) = LOWER(TRIM(:nome)) LIMIT 1"),
            {"sid": soc_id, "nome": campo}
        ).fetchone()
        if cs and cs[0]:
            indirizzo = cs[0]

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
                mister_manuale = :mister_manuale,
                risultato = :risultato,
                goal_punti = :goal_punti,
                goal_contro = :goal_contro,
                note = :note,
                weekend_id = :weekend_id,
                livello = :livello
            WHERE id = :id
            RETURNING *
        """),
        {
            "id": partita_id,
            "categoria_id": data.categoria_id,
            "data_partite": data_partite,
            "ora": ora,
            "ora_presentazione": ora_pres,
            "avversario": avversario,
            "campo": campo,
            "indirizzo": indirizzo,
            "casa_fuori": casa_fuori,
            "mister_id": mister_id,
            "mister_manuale": mister_manuale,
            "risultato": risultato,
            "goal_punti": data.goal_punti or 0,
            "goal_contro": data.goal_contro or 0,
            "note": note,
            "weekend_id": weekend_id,
            "livello": livello,
        }
    )
    row = res.fetchone()
    if not row:
        raise HTTPException(404, "Partita non trovata")
    db.commit()

    partita_dict = dict(row._mapping)

    # Salva o aggiorna indirizzo del campo sportivo per riutilizzo futuro
    if campo and indirizzo:
        try:
            db.execute(text("""
                INSERT INTO campi_sportivi (societa_id, nome, indirizzo, updated_at)
                VALUES (:sid, :nome, :indirizzo, CURRENT_TIMESTAMP)
                ON CONFLICT (societa_id, nome) DO UPDATE
                SET indirizzo = EXCLUDED.indirizzo,
                    updated_at = CURRENT_TIMESTAMP
                WHERE EXCLUDED.indirizzo IS NOT NULL AND TRIM(EXCLUDED.indirizzo) != ''
            """), {"sid": partita_dict["societa_id"], "nome": campo, "indirizzo": indirizzo})
            db.commit()
        except Exception as e:
            print(f"Avviso salvataggio campo_sportivo: {e}")

    # Sincronizza automaticamente le gare collegate in convocazione_gare
    try:
        ora_short = ora[:5] if ora else None
        soc_row = db.execute(text("SELECT nome, nome_breve FROM societa WHERE id = :sid"), {"sid": partita_dict["societa_id"]}).fetchone()
        nome_soc = "Noi"
        if soc_row:
            s_map = soc_row._mapping
            nome_soc = s_map.get("nome_breve") or s_map.get("nome") or "Noi"
        gara_nome = f"{avversario or 'TBD'} vs {nome_soc}" if casa_fuori == "fuori" else f"{nome_soc} vs {avversario or 'TBD'}"

        db.execute(text("""
            UPDATE convocazione_gare SET
                data = :data_partite,
                inizio_gara = :ora,
                campo = :campo,
                indirizzo = :indirizzo,
                gara = :gara
            WHERE partita_id = :pid
        """), {
            "pid": partita_id,
            "data_partite": data_partite,
            "ora": ora_short,
            "campo": campo,
            "indirizzo": indirizzo,
            "gara": gara_nome
        })
        db.commit()
    except Exception as e:
        print(f"Avviso sincronizzazione convocazione_gare: {e}")

    return partita_dict

@router.delete("/{partita_id}")
def elimina_partita(partita_id: int, db=Depends(get_db), user=Depends(get_staff_admin)):
    check_partite_access(db, partita_id, user)
    try:
        db.execute(text("UPDATE convocazione_gare SET partita_id = NULL WHERE partita_id = :id"), {"id": partita_id})
    except Exception:
        pass
    db.execute(text("DELETE FROM partite WHERE id = :id"), {"id": partita_id})
    db.commit()
    return {"ok": True}
