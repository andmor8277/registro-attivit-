from sqlalchemy import Column, Integer, String, Date, ForeignKey
from ..database import Base


class CodicePresenza(Base):
    __tablename__ = "codici"
    codice = Column(String(5), primary_key=True)
    descrizione = Column(String(100))
    tipo = Column(String(20))


class Registro(Base):
    __tablename__ = "registro"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    data = Column(Date, nullable=False)
    codice = Column(String(5), ForeignKey("codici.codice"), nullable=True)
    categoria_id = Column(Integer, ForeignKey("categorie.id"))


class PresenzaAllenatore(Base):
    __tablename__ = "presenze_allenatori"
    id = Column(Integer, primary_key=True)
    utente_id = Column(Integer, ForeignKey("utenti.id"), nullable=False)
    data = Column(Date, nullable=False)
    codice = Column(String(5), ForeignKey("codici.codice"), nullable=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
