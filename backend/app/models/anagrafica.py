from sqlalchemy import Column, Integer, String, Date, ForeignKey, Boolean, Float, Text
from sqlalchemy.dialects.postgresql import JSONB
from ..database import Base


class Categoria(Base):
    __tablename__ = "categorie"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)
    anno = Column(Integer, nullable=True)
    stagione = Column(Integer, nullable=True)
    giorni = Column(String(20), nullable=True)
    ora_allenamento = Column(String(10), nullable=True)
    orari_giorni = Column(JSONB, nullable=True)
    is_portieri = Column(Integer, default=0)
    is_archiviata = Column(Integer, default=0)
    parent_id = Column(Integer, ForeignKey("categorie.id"), nullable=True)
    data_inizio_stagione = Column(Date, nullable=True)
    data_fine_stagione = Column(Date, nullable=True)


class Gruppo(Base):
    __tablename__ = "gruppi"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"))
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=True)
    is_misto = Column(Boolean, default=False)


class Persona(Base):
    __tablename__ = "persone"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    gruppo_id = Column(Integer, ForeignKey("gruppi.id"))
    categoria_id = Column(Integer, ForeignKey("categorie.id"))
    data_nascita = Column(Date, nullable=True)
    sesso = Column(String(1), nullable=True)
    codice_fiscale = Column(String(16), nullable=True)
    matricola = Column(String(50), nullable=True)
    numero_maglia = Column(Integer, nullable=True)
    scadenza_certificato = Column(Date, nullable=True)
    residenza = Column(String(100), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    cittadinanza = Column(String(50), nullable=True)
    tel_papa = Column(String(255), nullable=True)
    tel_mamma = Column(String(255), nullable=True)
    email1 = Column(String(100), nullable=True)
    email2 = Column(String(100), nullable=True)
    prof_papa = Column(String(100), nullable=True)
    prof_mamma = Column(String(100), nullable=True)
    anamnesi = Column(Text, nullable=True)
    taglia = Column(String(10), nullable=True)
    note = Column(Text, nullable=True)
    nome_papa = Column(String(100), nullable=True)
    nome_mamma = Column(String(100), nullable=True)
    comune_nato = Column(String(100), nullable=True)
    totale_da_pagare = Column(Float, nullable=True)
    rata_iscrizione = Column(Float, nullable=True)
    rata1 = Column(Float, nullable=True)
    rata2 = Column(Float, nullable=True)
    rata3 = Column(Float, nullable=True)
    rata4 = Column(Float, nullable=True)
    rata_saldo = Column(Float, nullable=True)
