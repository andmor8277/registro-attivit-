from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
import os
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://registro_user:Redtigers_greta2009@127.0.0.1:5432/registro")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
