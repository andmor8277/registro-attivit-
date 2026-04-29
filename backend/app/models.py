from sqlalchemy import Column, Integer, String, Date, ForeignKey, Boolean, Float, Text, DateTime, JSON
from sqlalchemy.dialects.postgresql import JSONB
from .database import Base

class Societa(Base):
    __tablename__ = "societa"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    nome_breve = Column(String(50), nullable=True)  # es. "RedTigers"
    logo = Column(String(200), nullable=True)  # path/logo filename
    logosponsor = Column(String(200), nullable=True)  # path/logosponsor filename
    colore_primario = Column(String(7), default="#dc2626")  # hex color
    colore_secondario = Column(String(7), default="#1f2937")  # hex color
    is_attiva = Column(Integer, default=1)

class Categoria(Base):
    __tablename__ = "categorie"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)
    anno = Column(Integer, nullable=True)  # anno di nascita (es. 2014)
    stagione = Column(Integer, nullable=True)  # anno inizio stagione (es. 2025 per 2025/2026)
    giorni = Column(String(20), nullable=True)  # es. "1,3,5" = Lun,Mer,Ven
    is_portieri = Column(Integer, default=0)  # 1 = portieri (cross-year)
    is_archiviata = Column(Integer, default=0)  # 1 = categoria archiviata
    data_inizio_stagione = Column(Date, nullable=True)
    data_fine_stagione = Column(Date, nullable=True)

class Gruppo(Base):
    __tablename__ = "gruppi"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"))

class Persona(Base):
    __tablename__ = "persone"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    gruppo_id = Column(Integer, ForeignKey("gruppi.id"))
    categoria_id = Column(Integer, ForeignKey("categorie.id"))
    data_nascita = Column(Date, nullable=True)
    codice_fiscale = Column(String(16), nullable=True)
    telefono = Column(String(20), nullable=True)
    matricola = Column(String(50), nullable=True)
    numero_maglia = Column(Integer, nullable=True)
    scadenza_certificato = Column(Date, nullable=True)
    residenza = Column(String(100), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    cittadinanza = Column(String(50), nullable=True)
    tel_papa = Column(String(20), nullable=True)
    tel_mamma = Column(String(20), nullable=True)
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

class Utente(Base):
    __tablename__ = "utenti"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    username = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(200), nullable=False)
    is_admin = Column(Integer, default=0)
    is_super_admin = Column(Integer, default=0)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    data_nascita = Column(Date, nullable=False)
    codice_fiscale = Column(String(16), nullable=False)
    cellulare = Column(String(50), nullable=False)
    tesserino = Column(String(50), nullable=True)
    ruolo = Column(String(20), nullable=True)  # admin, mister, dirigente

class UtenteCategoria(Base):
    __tablename__ = "utente_categorie"
    id = Column(Integer, primary_key=True)
    utente_id = Column(Integer, ForeignKey("utenti.id", ondelete="CASCADE"))
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    ruolo = Column(String(50), nullable=True)  # es. 'mister'

class Convocazione(Base):
    __tablename__ = "convocazioni"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    data_inizio = Column(Date, nullable=False)
    data_fine = Column(Date, nullable=True)
    note = Column(String(1000), nullable=True)

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

class Allenatore(Base):
    __tablename__ = "allenatori"
    id = Column(Integer, primary_key=True)
    cognome = Column(String(100), nullable=False)
    telefono = Column(String(30), nullable=True)

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
    campo_con_righe = Column(Boolean, default=True)
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

class CatalogoEsercizio(Base):
    __tablename__ = "catalogo_esercizi"
    id = Column(Integer, primary_key=True)
    titolo = Column(String(200), nullable=False, unique=True)
    focus = Column(String(50), nullable=True)
    spazio = Column(String(50), nullable=True)
    tempo = Column(String(50), nullable=True)
    descrizione = Column(Text, nullable=True)
    campo_con_righe = Column(Boolean, default=True)
    elementi = Column(JSONB, default=[])
    creato_da = Column(Integer, nullable=True)
    creato_il = Column(DateTime, nullable=True)
    aggiornato_il = Column(DateTime, nullable=True)
