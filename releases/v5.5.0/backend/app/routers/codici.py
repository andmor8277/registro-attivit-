from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from .. import models, schemas
from ..database import get_db
router = APIRouter(prefix="/codici", tags=["codici"])
@router.get("/", response_model=list[schemas.CodiceOut])
def get_codici(db: Session = Depends(get_db)):
    return db.query(models.CodicePresenza).all()
