from sqlalchemy import Column, Integer, String, Date, Text, DateTime, ForeignKey
from ..database import Base


class ScoutingSegnalazione(Base):
    __tablename__ = "scouting_segnalazioni"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"), nullable=False)
    convocazione_id = Column(Integer, ForeignKey("convocazioni.id", ondelete="SET NULL"), nullable=True)
    gara_id = Column(Integer, ForeignKey("convocazione_gare.id", ondelete="SET NULL"), nullable=True)
    autore_id = Column(Integer, ForeignKey("utenti.id"), nullable=True)
    titolo = Column(String(200), nullable=True)
    data_osservazione = Column(Date, nullable=True)
    squadra_avversaria = Column(String(100), nullable=True)
    note = Column(Text, nullable=True)
    stato = Column(String(20), default="inviata")
    creato_il = Column(DateTime, nullable=True)
    aggiornato_il = Column(DateTime, nullable=True)


class ScoutingGiocatore(Base):
    __tablename__ = "scouting_giocatori"
    id = Column(Integer, primary_key=True)
    segnalazione_id = Column(Integer, ForeignKey("scouting_segnalazioni.id", ondelete="CASCADE"), nullable=False)
    nome = Column(String(100), nullable=True)
    cognome = Column(String(100), nullable=True)
    squadra = Column(String(100), nullable=True)
    ruolo = Column(String(50), nullable=True)
    numero_maglia = Column(Integer, nullable=True)
    ordine = Column(Integer, default=0)
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
    valutato_il = Column(DateTime, nullable=True)
