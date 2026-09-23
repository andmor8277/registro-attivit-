from sqlalchemy import Column, Integer, String, ForeignKey
from ..database import Base


class Societa(Base):
    __tablename__ = "societa"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    nome_breve = Column(String(50), nullable=True)
    logo = Column(String(200), nullable=True)
    logosponsor = Column(String(200), nullable=True)
    colore_primario = Column(String(7), default="#dc2626")
    colore_secondario = Column(String(7), default="#1f2937")
    is_attiva = Column(Integer, default=1)


class Allenatore(Base):
    __tablename__ = "allenatori"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=True)
    cognome = Column(String(100), nullable=False)
    telefono = Column(String(30), nullable=True)
