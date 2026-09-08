from sqlalchemy import Column, Integer, String, Date, ForeignKey, Boolean, Text, DateTime
from sqlalchemy.dialects.postgresql import JSONB
from ..database import Base


class Openday(Base):
    __tablename__ = "openday"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    data_nascita = Column(Date, nullable=False)
    iscritto = Column(Boolean, default=False)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=True)
    creato_il = Column(DateTime, nullable=True)
    date_prova = Column(JSONB, default=[])
    nulla_osta = Column(Boolean, default=False)
    certificato_medico = Column(Boolean, default=False)
    scadenza_certificato = Column(Date, nullable=True)
    tel_papa = Column(String(255), nullable=True)
    tel_mamma = Column(String(255), nullable=True)
    email_papa = Column(String(100), nullable=True)
    email_mamma = Column(String(100), nullable=True)


class Valutazione(Base):
    __tablename__ = "valutazioni"
    id = Column(Integer, primary_key=True)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    tecnica = Column(Integer, nullable=True)
    velocita = Column(Integer, nullable=True)
    resistenza = Column(Integer, nullable=True)
    attitudine = Column(Integer, nullable=True)
    posizione = Column(Integer, nullable=True)
    gioco_di_testa = Column(Integer, nullable=True)
    tiro = Column(Integer, nullable=True)
    passaggio = Column(Integer, nullable=True)
    dribbling = Column(Integer, nullable=True)
    disciplina = Column(Integer, nullable=True)
    note = Column(Text, nullable=True)
