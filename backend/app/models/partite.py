from sqlalchemy import Column, Integer, String, Date, ForeignKey, DateTime, Text
from sqlalchemy.dialects.postgresql import JSONB
from ..database import Base


class Convocazione(Base):
    __tablename__ = "convocazioni"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    weekend_id = Column(Integer, nullable=True)
    data_inizio = Column(Date, nullable=False)
    data_fine = Column(Date, nullable=True)
    note = Column(String(1000), nullable=True)
    esclusioni = Column(JSONB, nullable=True, default=list)


class ConvocazioneGara(Base):
    __tablename__ = "convocazione_gare"
    id = Column(Integer, primary_key=True)
    convocazione_id = Column(Integer, ForeignKey("convocazioni.id", ondelete="CASCADE"))
    partita_id = Column(Integer, nullable=True)
    numero = Column(Integer, nullable=False)
    gara = Column(String(200), nullable=True)
    data = Column(Date, nullable=True)
    campo = Column(String(200), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    appuntamento = Column(String(50), nullable=True)
    inizio_gara = Column(String(50), nullable=True)
    allenatore = Column(String(200), nullable=True)
    allenatori = Column(JSONB, nullable=True, default=list)
    livello = Column(String(50), nullable=True)


class ConvocazioneGiocatore(Base):
    __tablename__ = "convocazione_giocatori"
    id = Column(Integer, primary_key=True)
    gara_id = Column(Integer, ForeignKey("convocazione_gare.id", ondelete="CASCADE"))
    persona_id = Column(Integer, ForeignKey("persone.id", ondelete="CASCADE"))
    posizione = Column(Integer, nullable=False)
    non_presente = Column(Integer, default=0)


class Torneo(Base):
    """Un torneo a cui la societa' iscrive una categoria (Natale, Pasqua, tornei estivi...).

    Il calendario delle gare sta in TorneoGara. La Lista Tornei con i giocatori convocati non
    e' qui: resta in liste_torneo, collegata da tornei_id, perche' l'export PDF del file da
    consegnare all'organizzatore vive gia' li' e non va duplicato.
    """
    __tablename__ = "tornei"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    # Nessun ON DELETE CASCADE: cancellare una categoria non deve cancellare da sola i tornei
    # gia' iscritti, meglio che il database lo impedisca e lo si faccia consapevolmente
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    nome = Column(String(120), nullable=False)
    data_inizio = Column(Date, nullable=True)
    data_fine = Column(Date, nullable=True)
    luogo = Column(String(200), nullable=True)
    organizzatore = Column(String(120), nullable=True)
    descrizione = Column(Text, nullable=True)
    creato_da = Column(Integer, nullable=True)
    creato_il = Column(DateTime, nullable=True)


class TorneoGara(Base):
    """Una gara (o un girone) del calendario di un torneo.

    Ora e ora di appuntamento sono stringhe e non TIME, come ConvocazioneGara.appuntamento e
    .inizio_gara: arrivano da un <input type="time"> e a volte l'organizzatore le comunica in
    forme diverse ("10:30", "10,30", "ore 10:30"). Forzarle in TIME avrebbe reso impossibile
    registrare il calendario cosi' com'e' stato comunicato.
    """
    __tablename__ = "tornei_gare"
    id = Column(Integer, primary_key=True)
    torneo_id = Column(Integer, ForeignKey("tornei.id", ondelete="CASCADE"), nullable=False)
    numero = Column(Integer, nullable=True)
    avversario = Column(String(120), nullable=True)
    data = Column(Date, nullable=True)
    ora = Column(String(20), nullable=True)
    ora_appuntamento = Column(String(20), nullable=True)
    campo = Column(String(120), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    note = Column(Text, nullable=True)


class ListaTorneo(Base):
    __tablename__ = "liste_torneo"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    creato_il = Column(DateTime, nullable=True)
    # NULL per le liste create a mano (esistono gia' e devono restare valide). Per quelle nate
    # da un torneo e' univoco: un torneo produce una sola lista, che e' il file bloccato da
    # consegnare. SET NULL perche' cancellare il torneo non deve cancellare il lavoro fatto
    # sulla lista da chi ci ha gia' messo i giocatori.
    torneo_id = Column(Integer, ForeignKey("tornei.id", ondelete="SET NULL"), nullable=True)


class ListaTorneoGiocatore(Base):
    __tablename__ = "liste_torneo_giocatori"
    id = Column(Integer, primary_key=True)
    lista_id = Column(Integer, ForeignKey("liste_torneo.id"), nullable=False)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    ordine = Column(Integer, default=0)
