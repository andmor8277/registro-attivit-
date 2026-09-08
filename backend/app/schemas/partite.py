from pydantic import BaseModel
from typing import Optional


class PartitaCreate(BaseModel):
    categoria_id: Optional[int] = None
    data_partite: Optional[str] = None
    ora: Optional[str] = None
    ora_presentazione: Optional[str] = None
    avversario: Optional[str] = None
    campo: Optional[str] = None
    indirizzo: Optional[str] = None
    casa_fuori: Optional[str] = None
    mister_id: Optional[int] = None
    risultato: Optional[str] = None
    goal_punti: Optional[int] = 0
    goal_contro: Optional[int] = 0
    note: Optional[str] = None
    societa_id: Optional[int] = None
    weekend_id: Optional[int] = None


class PartitaUpdate(BaseModel):
    categoria_id: Optional[int] = None
    data_partite: Optional[str] = None
    ora: Optional[str] = None
    ora_presentazione: Optional[str] = None
    avversario: Optional[str] = None
    campo: Optional[str] = None
    indirizzo: Optional[str] = None
    casa_fuori: Optional[str] = None
    mister_id: Optional[int] = None
    risultato: Optional[str] = None
    goal_punti: Optional[int] = 0
    goal_contro: Optional[int] = 0
    note: Optional[str] = None
    weekend_id: Optional[int] = None


class WeekendCreate(BaseModel):
    nome: Optional[str] = None
    data_inizio: Optional[str] = None
    data_fine: Optional[str] = None
    societa_id: Optional[int] = None


class WeekendUpdate(BaseModel):
    nome: Optional[str] = None
    data_inizio: Optional[str] = None
    data_fine: Optional[str] = None


class SpogliatoioCreate(BaseModel):
    etichetta: Optional[str] = None
    ordine: Optional[int] = 0
    societa_id: Optional[int] = None


class SpogliatoioUpdate(BaseModel):
    etichetta: Optional[str] = None
    ordine: Optional[int] = None


class SpogliatoioAssegnazioneCreate(BaseModel):
    spogliatoio_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None
    societa_id: Optional[int] = None
    is_default: Optional[bool] = False


class SpogliatoioAssegnazioneUpdate(BaseModel):
    spogliatoio_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None
    is_default: Optional[bool] = None


class CampoCreate(BaseModel):
    etichetta: Optional[str] = None
    ordine: Optional[int] = 0
    societa_id: Optional[int] = None
    tipo_campo: Optional[str] = "11"


class CampoUpdate(BaseModel):
    etichetta: Optional[str] = None
    ordine: Optional[int] = None
    tipo_campo: Optional[str] = None


class CampoAssegnazioneCreate(BaseModel):
    campo_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None
    societa_id: Optional[int] = None
    metacampo: Optional[str] = None
    is_default: Optional[bool] = False


class CampoAssegnazioneUpdate(BaseModel):
    campo_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None
    metacampo: Optional[str] = None
    is_default: Optional[bool] = None
