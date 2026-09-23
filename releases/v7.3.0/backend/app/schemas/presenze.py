from pydantic import BaseModel
from datetime import date
from typing import Optional


class CodiceOut(BaseModel):
    codice: str
    descrizione: str
    tipo: str

    class Config:
        from_attributes = True


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

    class Config:
        from_attributes = True
