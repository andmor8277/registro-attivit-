from ..database import Base
from .auth import Utente, UtenteCategoria, Invito
from .societa import Societa, Allenatore
from .anagrafica import Categoria, Gruppo, Persona
from .presenze import CodicePresenza, Registro, PresenzaAllenatore
from .allenamenti import (
    Allenamento,
    AllenamentoMese,
    AllenamentoSettimana,
    AllenamentoGiorno,
    AllenamentoEsercizio,
    AllenamentoElemento,
    CatalogoEsercizio,
    SchedaAllenamento,
)
from .partite import (
    Convocazione,
    ConvocazioneGara,
    ConvocazioneGiocatore,
    ListaTorneo,
    ListaTorneoGiocatore,
)
from .segreteria import Openday, Valutazione
from .infermeria import Infortunio, PlanningEvento

__all__ = [
    "Base",
    "Utente",
    "UtenteCategoria",
    "Invito",
    "Societa",
    "Allenatore",
    "Categoria",
    "Gruppo",
    "Persona",
    "CodicePresenza",
    "Registro",
    "PresenzaAllenatore",
    "Allenamento",
    "AllenamentoMese",
    "AllenamentoSettimana",
    "AllenamentoGiorno",
    "AllenamentoEsercizio",
    "AllenamentoElemento",
    "CatalogoEsercizio",
    "SchedaAllenamento",
    "Convocazione",
    "ConvocazioneGara",
    "ConvocazioneGiocatore",
    "ListaTorneo",
    "ListaTorneoGiocatore",
    "Openday",
    "Valutazione",
    "Infortunio",
    "PlanningEvento",
]
