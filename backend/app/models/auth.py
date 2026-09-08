from sqlalchemy import Column, Integer, String, Date, ForeignKey, Boolean, DateTime, text
from ..database import Base


class Utente(Base):
    __tablename__ = "utenti"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    username = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(200), nullable=True)
    google_sub = Column(String(255), nullable=True)
    is_admin = Column(Integer, default=0)
    is_super_admin = Column(Integer, default=0)
    nome = Column(String(100), nullable=False)
    cognome = Column(String(100), nullable=False)
    data_nascita = Column(Date, nullable=False)
    codice_fiscale = Column(String(16), nullable=False)
    cellulare = Column(String(50), nullable=False)
    tesserino = Column(String(50), nullable=True)
    ruolo = Column(String(20), nullable=True)


class UtenteCategoria(Base):
    __tablename__ = "utente_categorie"
    id = Column(Integer, primary_key=True)
    utente_id = Column(Integer, ForeignKey("utenti.id", ondelete="CASCADE"))
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    ruolo = Column(String(50), nullable=True)


class Invito(Base):
    __tablename__ = "inviti"
    id = Column(Integer, primary_key=True)
    email = Column(String(200), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    ruolo = Column(String(20), nullable=False)
    token = Column(String(100), unique=True, nullable=False)
    creato_il = Column(DateTime, server_default=text("NOW()"))
    scade = Column(DateTime, nullable=False)
    usato = Column(Boolean, default=False)
