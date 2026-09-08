from .anagrafica import PersonaCreate, PersonaOut
from .presenze import CodiceOut, RegistroEntry, RegistroOut
from .partite import (
    PartitaCreate,
    PartitaUpdate,
    WeekendCreate,
    WeekendUpdate,
    SpogliatoioCreate,
    SpogliatoioUpdate,
    SpogliatoioAssegnazioneCreate,
    SpogliatoioAssegnazioneUpdate,
    CampoCreate,
    CampoUpdate,
    CampoAssegnazioneCreate,
    CampoAssegnazioneUpdate,
)
from .segreteria import OpendayCreate, OpendayUpdate

__all__ = [
    "PersonaCreate",
    "PersonaOut",
    "CodiceOut",
    "RegistroEntry",
    "RegistroOut",
    "PartitaCreate",
    "PartitaUpdate",
    "WeekendCreate",
    "WeekendUpdate",
    "SpogliatoioCreate",
    "SpogliatoioUpdate",
    "SpogliatoioAssegnazioneCreate",
    "SpogliatoioAssegnazioneUpdate",
    "CampoCreate",
    "CampoUpdate",
    "CampoAssegnazioneCreate",
    "CampoAssegnazioneUpdate",
    "OpendayCreate",
    "OpendayUpdate",
]
