from sqlalchemy import Column, Integer, String, Date, ForeignKey, Text, DateTime
from ..database import Base


class Infortunio(Base):
    __tablename__ = "infortuni"
    id = Column(Integer, primary_key=True)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    data_inizio = Column(Date, nullable=False)
    giorni_assenza = Column(Integer, nullable=False, default=0)
    data_fine = Column(Date, nullable=True)
    tipo_infortunio = Column(String(100), nullable=True)
    note = Column(Text, nullable=True)
    creato_il = Column(DateTime, nullable=True)


class PlanningEvento(Base):
    __tablename__ = "planning_eventi"
    id = Column(Integer, primary_key=True)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    data = Column(Date, nullable=False)
    tipo = Column(String(20), nullable=False)
    titolo = Column(String(200), nullable=True)
    note = Column(Text, nullable=True)
    creato_il = Column(DateTime, nullable=True)
