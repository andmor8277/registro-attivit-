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
    class Config: from_attributes = True
