from pydantic import BaseModel
from datetime import date
from typing import Optional

class PersonaCreate(BaseModel):
    nome: Optional[str] = None
    cognome: Optional[str] = None
    gruppo_id: Optional[int] = None
    categoria_id: Optional[int] = None
    data_nascita: Optional[date] = None
    codice_fiscale: Optional[str] = None
    matricola: Optional[str] = None
    numero_maglia: Optional[int] = None
    scadenza_certificato: Optional[date] = None
    societa_id: Optional[int] = None
    residenza: Optional[str] = None
    indirizzo: Optional[str] = None
    cittadinanza: Optional[str] = None
    tel_papa: Optional[str] = None
    tel_mamma: Optional[str] = None
    email1: Optional[str] = None
    email2: Optional[str] = None
    prof_papa: Optional[str] = None
    prof_mamma: Optional[str] = None
    nome_papa: Optional[str] = None
    nome_mamma: Optional[str] = None
    comune_nato: Optional[str] = None
    anamnesi: Optional[str] = None
    taglia: Optional[str] = None
    note: Optional[str] = None
    totale_da_pagare: Optional[float] = None
    rata_iscrizione: Optional[float] = None
    rata1: Optional[float] = None
    rata2: Optional[float] = None
    rata3: Optional[float] = None
    rata4: Optional[float] = None
    rata_saldo: Optional[float] = None

class PersonaOut(BaseModel):
    id: int
    nome: str
    cognome: str
    gruppo_id: Optional[int]
    categoria_id: Optional[int]
    data_nascita: Optional[date]
    codice_fiscale: Optional[str]
    matricola: Optional[str]
    numero_maglia: Optional[int]
    scadenza_certificato: Optional[date]
    societa_id: Optional[int]
    residenza: Optional[str] = None
    indirizzo: Optional[str] = None
    cittadinanza: Optional[str] = None
    tel_papa: Optional[str] = None
    tel_mamma: Optional[str] = None
    email1: Optional[str] = None
    email2: Optional[str] = None
    prof_papa: Optional[str] = None
    prof_mamma: Optional[str] = None
    nome_papa: Optional[str] = None
    nome_mamma: Optional[str] = None
    comune_nato: Optional[str] = None
    anamnesi: Optional[str] = None
    taglia: Optional[str] = None
    note: Optional[str] = None
    class Config: from_attributes = True

class CodiceOut(BaseModel):
    codice: str
    descrizione: str
    tipo: str
    class Config: from_attributes = True

class RegistroEntry(BaseModel):
    persona_id: int
    data: date
    codice: Optional[str] = None
    categoria_id: Optional[int] = None
    societa_id: Optional[int] = None

class RegistroOut(BaseModel):
    id: int
    persona_id: int
    data: date
    codice: Optional[str]
    categoria_id: Optional[int]
    societa_id: Optional[int]
    is_portieri_readthrough: Optional[bool] = False
    class Config: from_attributes = True

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

class SpogliatoioAssegnazioneUpdate(BaseModel):
    spogliatoio_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None

class CampoCreate(BaseModel):
    etichetta: Optional[str] = None
    ordine: Optional[int] = 0
    societa_id: Optional[int] = None

class CampoUpdate(BaseModel):
    etichetta: Optional[str] = None
    ordine: Optional[int] = None

class CampoAssegnazioneCreate(BaseModel):
    campo_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None
    societa_id: Optional[int] = None

class CampoAssegnazioneUpdate(BaseModel):
    campo_id: Optional[int] = None
    categoria_id: Optional[int] = None
    nome_squadra_esterna: Optional[str] = None
    tipo: Optional[str] = "casa"
    data_inizio: Optional[str] = None
    data: Optional[str] = None
    weekend_id: Optional[int] = None
