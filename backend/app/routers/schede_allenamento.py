from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, func, extract
from datetime import date, datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel
from .. import models
from ..database import get_db
from ..routers.auth import get_current_user, get_admin
from ..models import Utente

router = APIRouter(prefix="/schede-allenamento", tags=["schede allenamento"])

class SchedaCreate(BaseModel):
    persona_id: int
    categoria_id: int
    data: date
    distanza_totale: Optional[float] = None
    distanza_alta_velocita: Optional[float] = None
    distanza_sprint: Optional[float] = None
    velocita_massima: Optional[float] = None
    accelerazioni: Optional[int] = None
    decelerazioni: Optional[int] = None
    metabolic_power: Optional[float] = None
    player_load: Optional[float] = None
    calorie: Optional[float] = None
    tempo_lavoro: Optional[int] = None
    rpe: Optional[int] = None
    note: Optional[str] = None

@router.get("/")
def get_schede(
    categoria_id: Optional[int] = Query(None),
    data: Optional[date] = Query(None),
    persona_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    query = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.societa_id == current_user.societa_id
    )
    if categoria_id:
        query = query.filter(models.SchedaAllenamento.categoria_id == categoria_id)
    if data:
        query = query.filter(models.SchedaAllenamento.data == data)
    if persona_id:
        query = query.filter(models.SchedaAllenamento.persona_id == persona_id)
    return query.order_by(models.SchedaAllenamento.data.desc()).all()

@router.post("/")
def create_scheda(data: SchedaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    from sqlalchemy import func
    result = db.execute(
        func.now(),
    )
    now = result.scalar()
    scheda = models.SchedaAllenamento(
        persona_id=data.persona_id,
        categoria_id=data.categoria_id,
        societa_id=current_user.societa_id,
        data=data.data,
        distanza_totale=data.distanza_totale,
        distanza_alta_velocita=data.distanza_alta_velocita,
        distanza_sprint=data.distanza_sprint,
        velocita_massima=data.velocita_massima,
        accelerazioni=data.accelerazioni,
        decelerazioni=data.decelerazioni,
        metabolic_power=data.metabolic_power,
        player_load=data.player_load,
        calorie=data.calorie,
        tempo_lavoro=data.tempo_lavoro,
        rpe=data.rpe,
        note=data.note,
        creato_il=now,
    )
    db.add(scheda)
    db.commit()
    db.refresh(scheda)
    return scheda

@router.put("/{scheda_id}")
def update_scheda(scheda_id: int, data: SchedaCreate, db: Session = Depends(get_db), current_user: Utente = Depends(get_current_user)):
    scheda = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.id == scheda_id,
        models.SchedaAllenamento.societa_id == current_user.societa_id
    ).first()
    if not scheda:
        raise HTTPException(status_code=404, detail="Scheda non trovata")
    for field in ['distanza_totale', 'distanza_alta_velocita', 'distanza_sprint', 'velocita_massima',
                  'accelerazioni', 'decelerazioni', 'metabolic_power', 'player_load', 'calorie',
                  'tempo_lavoro', 'rpe', 'note']:
        val = getattr(data, field)
        if val is not None:
            setattr(scheda, field, val)
    db.commit()
    db.refresh(scheda)
    return scheda

@router.delete("/{scheda_id}")
def delete_scheda(scheda_id: int, db: Session = Depends(get_db), current_user: Utente = Depends(get_admin)):
    scheda = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.id == scheda_id,
        models.SchedaAllenamento.societa_id == current_user.societa_id
    ).first()
    if not scheda:
        raise HTTPException(status_code=404, detail="Scheda non trovata")
    db.delete(scheda)
    db.commit()
    return {"ok": True}

METRICS = ['distanza_totale', 'distanza_alta_velocita', 'distanza_sprint', 'velocita_massima',
           'accelerazioni', 'decelerazioni', 'metabolic_power', 'player_load', 'calorie',
           'tempo_lavoro', 'rpe']

def _date_filter(period: str, now: datetime = None):
    if now is None:
        now = datetime.now()
    if period == 'week':
        return now - timedelta(days=7)
    elif period == 'month':
        return now - timedelta(days=30)
    elif period == 'season':
        season_start = now.replace(month=7, day=1)
        if now < season_start:
            season_start = season_start.replace(year=season_start.year - 1)
        return season_start
    return now - timedelta(days=365)

@router.get("/stats/trend")
def get_trend(
    categoria_id: int = Query(...),
    period: str = Query('week', regex='^(day|week|month|season)$'),
    metric: str = Query('distanza_totale', regex='^(' + '|'.join(METRICS) + ')$'),
    persona_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    base_q = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.societa_id == current_user.societa_id,
        models.SchedaAllenamento.categoria_id == categoria_id,
        models.SchedaAllenamento.data >= _date_filter(period)
    )
    if persona_id:
        base_q = base_q.filter(models.SchedaAllenamento.persona_id == persona_id)

    if period == 'day':
        group_expr = func.date(models.SchedaAllenamento.data)
    elif period == 'week':
        group_expr = func.date_trunc('week', models.SchedaAllenamento.data)
    elif period == 'month':
        group_expr = func.date_trunc('month', models.SchedaAllenamento.data)
    else:
        group_expr = func.date_trunc('month', models.SchedaAllenamento.data)

    col = getattr(models.SchedaAllenamento, metric)
    rows = base_q.with_entities(
        group_expr.label('period'),
        func.avg(col).label('avg'),
        func.max(col).label('max'),
        func.count(col).label('count')
    ).group_by(group_expr).order_by(group_expr).all()

    return [{
        'period': str(r.period.date() if hasattr(r.period, 'date') else r.period),
        'avg': round(float(r.avg), 1) if r.avg else 0,
        'max': round(float(r.max), 1) if r.max else 0,
        'count': int(r.count)
    } for r in rows]

@router.get("/stats/summary")
def get_summary(
    categoria_id: int = Query(...),
    period: str = Query('week', regex='^(week|month|season)$'),
    persona_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    base_q = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.societa_id == current_user.societa_id,
        models.SchedaAllenamento.categoria_id == categoria_id,
        models.SchedaAllenamento.data >= _date_filter(period)
    )
    if persona_id:
        base_q = base_q.filter(models.SchedaAllenamento.persona_id == persona_id)

    result = {}
    for m in METRICS:
        col = getattr(models.SchedaAllenamento, m)
        avg_val = base_q.with_entities(func.avg(col)).scalar()
        max_val = base_q.with_entities(func.max(col)).scalar()
        sum_val = base_q.with_entities(func.sum(col)).scalar()
        count_val = base_q.with_entities(func.count(col)).scalar()
        result[m] = {
            'avg': round(float(avg_val), 1) if avg_val else 0,
            'max': round(float(max_val), 1) if max_val else 0,
            'sum': round(float(sum_val), 1) if sum_val else 0,
            'sessions': int(count_val) if count_val else 0
        }
    total_sessions = base_q.with_entities(func.count(models.SchedaAllenamento.id)).scalar() or 0
    result['_total_sessions'] = int(total_sessions)
    return result

@router.get("/stats/team")
def get_team_stats(
    categoria_id: int = Query(...),
    period: str = Query('week', regex='^(week|month|season)$'),
    metric: str = Query('distanza_totale', regex='^(' + '|'.join(METRICS) + ')$'),
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    col = getattr(models.SchedaAllenamento, metric)
    rows = db.query(
        models.SchedaAllenamento.persona_id,
        func.avg(col).label('avg'),
        func.max(col).label('max'),
        func.sum(col).label('sum'),
        func.count(col).label('count')
    ).join(models.Persone).filter(
        models.SchedaAllenamento.societa_id == current_user.societa_id,
        models.SchedaAllenamento.categoria_id == categoria_id,
        models.SchedaAllenamento.data >= _date_filter(period)
    ).group_by(
        models.SchedaAllenamento.persona_id,
        models.Persone.nome,
        models.Persone.cognome
    ).order_by(func.avg(col).desc()).all()

    return [{
        'persona_id': r.persona_id,
        'nome': r.nome,
        'cognome': r.cognome,
        'avg': round(float(r.avg), 1) if r.avg else 0,
        'max': round(float(r.max), 1) if r.max else 0,
        'sum': round(float(r.sum), 1) if r.sum else 0,
        'sessions': int(r.count) if r.count else 0
    } for r in rows]

@router.get("/stats/player-trend")
def get_player_trend(
    categoria_id: int = Query(...),
    persona_id: int = Query(...),
    period: str = Query('month', regex='^(week|month|season)$'),
    db: Session = Depends(get_db),
    current_user: Utente = Depends(get_current_user)
):
    rows = db.query(models.SchedaAllenamento).filter(
        models.SchedaAllenamento.societa_id == current_user.societa_id,
        models.SchedaAllenamento.categoria_id == categoria_id,
        models.SchedaAllenamento.persona_id == persona_id,
        models.SchedaAllenamento.data >= _date_filter(period)
    ).order_by(models.SchedaAllenamento.data.asc()).all()

    return [{
        'data': str(r.data),
        'distanza_totale': r.distanza_totale,
        'distanza_alta_velocita': r.distanza_alta_velocita,
        'distanza_sprint': r.distanza_sprint,
        'velocita_massima': r.velocita_massima,
        'accelerazioni': r.accelerazioni,
        'decelerazioni': r.decelerazioni,
        'metabolic_power': r.metabolic_power,
        'player_load': r.player_load,
        'calorie': r.calorie,
        'tempo_lavoro': r.tempo_lavoro,
        'rpe': r.rpe,
    } for r in rows]
