from sqlalchemy import Column, Integer, String, Date, ForeignKey, Float, Text, DateTime, text
from sqlalchemy.dialects.postgresql import JSONB
from ..database import Base


class Allenamento(Base):
    __tablename__ = "allenamenti"
    id = Column(Integer, primary_key=True)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=True)
    data = Column(Date, nullable=False)
    esercizi = Column(JSONB, default=[])
    created_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, nullable=True)


class AllenamentoMese(Base):
    __tablename__ = "allenamenti_mese"
    id = Column(Integer, primary_key=True)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    nome_mese = Column(String(20), nullable=False)
    created_at = Column(Date, nullable=True)


class AllenamentoSettimana(Base):
    __tablename__ = "allenamenti_settimana"
    id = Column(Integer, primary_key=True)
    mese_id = Column(Integer, ForeignKey("allenamenti_mese.id"), nullable=False)
    numero_settimana = Column(Integer, nullable=False)
    data_inizio = Column(Date, nullable=False)
    created_at = Column(Date, nullable=True)


class AllenamentoGiorno(Base):
    __tablename__ = "allenamenti_giorno"
    id = Column(Integer, primary_key=True)
    settimana_id = Column(Integer, ForeignKey("allenamenti_settimana.id"), nullable=False)
    data = Column(Date, nullable=False)
    note = Column(Text, nullable=True)
    created_at = Column(Date, nullable=True)


class AllenamentoEsercizio(Base):
    __tablename__ = "allenamenti_esercizio"
    id = Column(Integer, primary_key=True)
    giorno_id = Column(Integer, ForeignKey("allenamenti_giorno.id"), nullable=False)
    ordine = Column(Integer, nullable=False)
    titolo = Column(String(200), nullable=True)
    descrizione = Column(Text, nullable=True)
    campo_con_righe = Column(String(10), default='full')
    created_at = Column(Date, nullable=True)


class AllenamentoElemento(Base):
    __tablename__ = "allenamenti_elemento"
    id = Column(Integer, primary_key=True)
    esercizio_id = Column(Integer, ForeignKey("allenamenti_esercizio.id"), nullable=False)
    tipo = Column(String(50), nullable=False)
    x = Column(Float, nullable=False)
    y = Column(Float, nullable=False)
    rotazione = Column(Float, default=0)
    colore = Column(String(20), nullable=True)
    numero = Column(Integer, nullable=True)
    size = Column(Float, nullable=True)


class CatalogoEsercizio(Base):
    __tablename__ = "catalogo_esercizi"
    id = Column(Integer, primary_key=True)
    titolo = Column(String(200), nullable=False, unique=True)
    focus = Column(String(50), nullable=True)
    spazio = Column(String(50), nullable=True)
    tempo = Column(String(50), nullable=True)
    descrizione = Column(Text, nullable=True)
    campo_con_righe = Column(String(10), default='full')
    elementi = Column(JSONB, default=[])
    creato_da = Column(Integer, nullable=True)
    creato_il = Column(DateTime, nullable=True)
    aggiornato_il = Column(DateTime, nullable=True)
    visibilita = Column(String(20), nullable=False, server_default=text("'pubblico'"))
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=True)


class SchedaAllenamento(Base):
    __tablename__ = "schede_allenamento"
    id = Column(Integer, primary_key=True)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    data = Column(Date, nullable=False)
    distanza_totale = Column(Float, nullable=True)
    distanza_alta_velocita = Column(Float, nullable=True)
    distanza_sprint = Column(Float, nullable=True)
    velocita_massima = Column(Float, nullable=True)
    accelerazioni = Column(Integer, nullable=True)
    decelerazioni = Column(Integer, nullable=True)
    metabolic_power = Column(Float, nullable=True)
    player_load = Column(Float, nullable=True)
    calorie = Column(Float, nullable=True)
    tempo_lavoro = Column(Integer, nullable=True)
    rpe = Column(Integer, nullable=True)
    note = Column(Text, nullable=True)
    creato_il = Column(DateTime, nullable=True)
