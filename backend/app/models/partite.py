from sqlalchemy import Column, Integer, String, Date, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import JSONB
from ..database import Base


class Convocazione(Base):
    __tablename__ = "convocazioni"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    data_inizio = Column(Date, nullable=False)
    data_fine = Column(Date, nullable=True)
    note = Column(String(1000), nullable=True)
    esclusioni = Column(JSONB, nullable=True, default=list)


class ConvocazioneGara(Base):
    __tablename__ = "convocazione_gare"
    id = Column(Integer, primary_key=True)
    convocazione_id = Column(Integer, ForeignKey("convocazioni.id", ondelete="CASCADE"))
    numero = Column(Integer, nullable=False)
    gara = Column(String(200), nullable=True)
    data = Column(Date, nullable=True)
    campo = Column(String(200), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    appuntamento = Column(String(50), nullable=True)
    inizio_gara = Column(String(50), nullable=True)
    allenatore = Column(String(200), nullable=True)


class ConvocazioneGiocatore(Base):
    __tablename__ = "convocazione_giocatori"
    id = Column(Integer, primary_key=True)
    gara_id = Column(Integer, ForeignKey("convocazione_gare.id", ondelete="CASCADE"))
    persona_id = Column(Integer, ForeignKey("persone.id", ondelete="CASCADE"))
    posizione = Column(Integer, nullable=False)
    non_presente = Column(Integer, default=0)


class ListaTorneo(Base):
    __tablename__ = "liste_torneo"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    creato_il = Column(DateTime, nullable=True)


class ListaTorneoGiocatore(Base):
    __tablename__ = "liste_torneo_giocatori"
    id = Column(Integer, primary_key=True)
    lista_id = Column(Integer, ForeignKey("liste_torneo.id"), nullable=False)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    ordine = Column(Integer, default=0)
