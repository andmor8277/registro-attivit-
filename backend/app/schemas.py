from pydantic import BaseModel
from datetime import date
from typing import Optional

class PersonaCreate(BaseModel):
    nome: str
    cognome: str
    gruppo_id: Optional[int] = None
    categoria_id: Optional[int] = None
    data_nascita: Optional[date] = None
    codice_fiscale: Optional[str] = None
    telefono: Optional[str] = None
    matricola: Optional[str] = None

class PersonaOut(BaseModel):
    id: int
    nome: str
    cognome: str
    gruppo_id: Optional[int]
    categoria_id: Optional[int]
    data_nascita: Optional[date]
    codice_fiscale: Optional[str]
    telefono: Optional[str]
    matricola: Optional[str]
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

class RegistroOut(BaseModel):
    id: int
    persona_id: int
    data: date
    codice: Optional[str]
    categoria_id: Optional[int]
    class Config: from_attributes = True
