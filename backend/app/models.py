from sqlalchemy import Column, Integer, String, Date, ForeignKey
from .database import Base

class Categoria(Base):
    __tablename__ = "categorie"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    anno = Column(Integer, nullable=True)  # anno di nascita (es. 2014)
    stagione = Column(Integer, nullable=True)  # anno inizio stagione (es. 2025 per 2025/2026)
    giorni = Column(String(20), nullable=True)  # es. "1,3,5" = Lun,Mer,Ven
    is_portieri = Column(Integer, default=0)  # 1 = portieri (cross-year)
    is_archiviata = Column(Integer, default=0)  # 1 = categoria archiviata
    drive_folder_id = Column(String(100), nullable=True)  # Google Drive folder ID

class Gruppo(Base):
    __tablename__ = "gruppi"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), unique=True, nullable=False)

class Persona(Base):
    __tablename__ = "persone"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    gruppo_id = Column(Integer, ForeignKey("gruppi.id"))
    categoria_id = Column(Integer, ForeignKey("categorie.id"))
    data_nascita = Column(Date, nullable=True)
    codice_fiscale = Column(String(16), nullable=True)
    telefono = Column(String(20), nullable=True)
    matricola = Column(String(50), nullable=True)

class CodicePresenza(Base):
    __tablename__ = "codici"
    codice = Column(String(5), primary_key=True)
    descrizione = Column(String(100))
    tipo = Column(String(20))

class Registro(Base):
    __tablename__ = "registro"
    id = Column(Integer, primary_key=True)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    data = Column(Date, nullable=False)
    codice = Column(String(5), ForeignKey("codici.codice"), nullable=True)
    categoria_id = Column(Integer, ForeignKey("categorie.id"))

class Utente(Base):
    __tablename__ = "utenti"
    id = Column(Integer, primary_key=True)
    username = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(200), nullable=False)
    is_admin = Column(Integer, default=0)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    data_nascita = Column(Date, nullable=False)
    codice_fiscale = Column(String(16), nullable=False)
    cellulare = Column(String(20), nullable=False)
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
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    data_inizio = Column(Date, nullable=False)
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
