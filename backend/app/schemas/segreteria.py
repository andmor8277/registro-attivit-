from pydantic import BaseModel
from typing import Optional, List


class OpendayCreate(BaseModel):
    nome: str
    cognome: str
    data_nascita: str
    date_prova: Optional[List] = None
    nulla_osta: Optional[bool] = False
    certificato_medico: Optional[bool] = False
    scadenza_certificato: Optional[str] = None
    tel_papa: Optional[str] = None
    tel_mamma: Optional[str] = None
    email_papa: Optional[str] = None
    email_mamma: Optional[str] = None


class OpendayUpdate(BaseModel):
    nome: Optional[str] = None
    cognome: Optional[str] = None
    data_nascita: Optional[str] = None
    date_prova: Optional[List] = None
    nulla_osta: Optional[bool] = None
    certificato_medico: Optional[bool] = None
    scadenza_certificato: Optional[str] = None
    tel_papa: Optional[str] = None
    tel_mamma: Optional[str] = None
    email_papa: Optional[str] = None
    email_mamma: Optional[str] = None
