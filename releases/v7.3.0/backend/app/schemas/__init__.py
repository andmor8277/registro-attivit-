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
    SpogliatoioAssegnazioneSettimanaSave,
    CampoCreate,
    CampoUpdate,
    CampoAssegnazioneCreate,
    CampoAssegnazioneUpdate,
    CampoAssegnazioneSettimanaSave,
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
    "SpogliatoioAssegnazioneSettimanaSave",
    "CampoCreate",
    "CampoUpdate",
    "CampoAssegnazioneCreate",
    "CampoAssegnazioneUpdate",
    "CampoAssegnazioneSettimanaSave",
    "OpendayCreate",
    "OpendayUpdate",
]
