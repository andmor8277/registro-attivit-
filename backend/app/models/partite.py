from sqlalchemy import Column, Integer, String, Date, ForeignKey, DateTime, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from ..database import Base


class Convocazione(Base):
    __tablename__ = "convocazioni"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id", ondelete="CASCADE"))
    weekend_id = Column(Integer, nullable=True)
    # Il foglio di convocazione di UNA gara di torneo. E' il discriminatore: o il foglio e' del weekend
    # (weekend_id valorizzato) o e' di una gara di torneo (tornei_gara_id valorizzato), mai tutti e due
    # — lo impedisce il check ck_convocazioni_uno_dei_due, non la buona volonta' del router.
    #
    # Sta qui e non su convocazione_gare perche' per il torneo il foglio COINCIDE con la gara: un foglio
    # per ogni gara in programma. Con ON DELETE CASCADE, cancellare la gara dal calendario si porta via
    # la sua convocazione; metterlo sul figlio avrebbe lasciato un foglio senza gare.
    #
    # Non si finge un weekend per il torneo: `crea` esige un weekend programmato, e inventarlo per una
    # gara di torneo avrebbe significato farla comparire anche nella pagina Convocazioni del campionato.
    tornei_gara_id = Column(Integer, ForeignKey("tornei_gare.id", ondelete="CASCADE"), nullable=True)
    data_inizio = Column(Date, nullable=False)
    data_fine = Column(Date, nullable=True)
    note = Column(String(1000), nullable=True)
    esclusioni = Column(JSONB, nullable=True, default=list)


class ConvocazioneGara(Base):
    __tablename__ = "convocazione_gare"
    id = Column(Integer, primary_key=True)
    convocazione_id = Column(Integer, ForeignKey("convocazioni.id", ondelete="CASCADE"))
    partita_id = Column(Integer, nullable=True)
    numero = Column(Integer, nullable=False)
    gara = Column(String(200), nullable=True)
    data = Column(Date, nullable=True)
    campo = Column(String(200), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    appuntamento = Column(String(50), nullable=True)
    inizio_gara = Column(String(50), nullable=True)
    allenatore = Column(String(200), nullable=True)
    allenatori = Column(JSONB, nullable=True, default=list)
    livello = Column(String(50), nullable=True)


class ConvocazioneGiocatore(Base):
    __tablename__ = "convocazione_giocatori"
    id = Column(Integer, primary_key=True)
    gara_id = Column(Integer, ForeignKey("convocazione_gare.id", ondelete="CASCADE"))
    persona_id = Column(Integer, ForeignKey("persone.id", ondelete="CASCADE"))
    posizione = Column(Integer, nullable=False)
    non_presente = Column(Integer, default=0)


class Torneo(Base):
    """Un torneo a cui la societa' iscrive una o piu' categorie (Natale, Pasqua, tornei estivi...).

    Il calendario delle gare sta in TorneoGara. La Lista Tornei con i giocatori convocati non
    e' qui: resta in liste_torneo, collegata da tornei_id, perche' l'export PDF del file da
    consegnare all'organizzatore vive gia' li' e non va duplicato.

    Le categorie ISCRITTE stanno in TorneoCategoria, una riga ciascuna: e' li' la verita', perche'
    un torneo di stagione a cui partecipano i Pulcini 2016 e gli Esordienti 2015 e' UN torneo, non
    due da creare a mano con lo stesso nome. Questa tabella non ha una categoria.
    """
    __tablename__ = "tornei"
    id = Column(Integer, primary_key=True)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    # Nessun ON DELETE CASCADE: cancellare una categoria non deve cancellare da sola i tornei
    # gia' iscritti, meglio che il database lo impedisca e lo si faccia consapevolmente
    #
    # Nullable dal 2026-11-20 e tenuto allineato alla PRIMA categoria iscritta. Non e' la fonte di
    # verita' (quella e' tornei_categorie) ma rimuoverla avrebbe rotto chi la usa perche' costa
    # poco: il badge della card, il filtro di GET / e l'ingresso da Scelta.vue. E' la stessa
    # categoria che porta il primo foglio giocatori, quindi per un torneo mono-categoria -- il
    # caso di gran lunga piu' frequente -- le due fonti coincidono per costruzione.
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=True)
    nome = Column(String(120), nullable=False)
    data_inizio = Column(Date, nullable=True)
    data_fine = Column(Date, nullable=True)
    luogo = Column(String(200), nullable=True)
    organizzatore = Column(String(120), nullable=True)
    descrizione = Column(Text, nullable=True)
    # Il referente del torneo: UNA persona per il torneo intero, non una per categoria. Non e' la
    # stessa cosa del mister della singola partita (partite.mister_id, che nel weekend c'e' gia'):
    # li' serve sapere chi dirige quella gara, qui serve il nome che l'organizzatore chiama la
    # mattina, quando le gare sono su due categorie e due mister diversi.
    #
    # mister_id non ha FK, come partite.mister_id: il riferimento e' a un utente che pu' essere
    # cancellato, e un vincolo qui renderebbe la cancellazione di un utente un errore, o peggio
    # cancellerebbe il torneo per cascata. Senza vincolo l'id resta orfano e la pagina dice
    # "da assegnare", che e' la verita' invece di un numero stampato nel PDF
    mister_id = Column(Integer, nullable=True)
    # Per l'accompagnatore che non ha un account: il weekend ha la stessa opzione, e un torneo
    # ospitato da un'altra societa' porta spesso un mister che qui non e' censito
    mister_manuale = Column(String(100), nullable=True)
    creato_da = Column(Integer, nullable=True)
    creato_il = Column(DateTime, nullable=True)


class TorneoCategoria(Base):
    """L'iscrizione di una categoria a un torneo: chi partecipa a quel torneo.

    E' la tabella che mancava quando il torneo aveva una sola categoria addosso: senza di essa,
    iscrivere due categorie alla stessa Winter Cup significava creare due tornei omonimi, con due
    calendari separati e due fogli da consegnare quando l'organizzatore ne aspetta uno per torneo.

    Da questa riga nasce la Lista Tornei di quella categoria: un foglio giocatori per categoria,
    che e' quello che l'organizzatore riceve. Per questo l'iscrizione e la lista si creano insieme
    nello stesso transaction, come gia' avveniva per il torneo -- se dipendesse da un passaggio
    manuale del mister resterebbe senza (in liste_torneo c'era UNA lista in tutto).
    """
    __tablename__ = "tornei_categorie"
    id = Column(Integer, primary_key=True)
    torneo_id = Column(Integer, ForeignKey("tornei.id", ondelete="CASCADE"), nullable=False)
    # Nessun CASCADE, stessa scelta di Torneo.categoria_id: una categoria con delle gare gia'
    # giocate dietro non deve sparire da sola insieme all'iscrizione
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)

    __table_args__ = (
        # Iscrivere due volte la stessa categoria allo stesso torneo non e' un'ipotesi: e' cio'
        # che fa un doppio click sul pulsante. E ogni iscrizione duplicata porterebbe con se' un
        # secondo foglio giocatori per la stessa categoria.
        UniqueConstraint("torneo_id", "categoria_id", name="uq_tornei_categorie"),
    )


class TorneoGara(Base):
    """Una gara (o un girone) del calendario di un torneo.

    Ora e ora di appuntamento sono stringhe e non TIME, come ConvocazioneGara.appuntamento e
    .inizio_gara: arrivano da un <input type="time"> e a volte l'organizzatore le comunica in
    forme diverse ("10:30", "10,30", "ore 10:30"). Forzarle in TIME avrebbe reso impossibile
    registrare il calendario cosi' com'e' stato comunicato.

    La categoria sta qui e non sul torneo, esattamente come partite.categoria_id sta sulla partita
    e non sul weekend: e' cio' che permette al calendario di un torneo di essere suddiviso per
    categorie come quello del weekend.
    """
    __tablename__ = "tornei_gare"
    id = Column(Integer, primary_key=True)
    torneo_id = Column(Integer, ForeignKey("tornei.id", ondelete="CASCADE"), nullable=False)
    # Nullable per non obbligare chi ha un torneo di una sola categoria a sceglierla ogni volta:
    # il router la deduce dall'unica iscritta, e la esige quando le iscritte sono piu' d'una
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=True)
    numero = Column(Integer, nullable=True)
    avversario = Column(String(120), nullable=True)
    data = Column(Date, nullable=True)
    ora = Column(String(20), nullable=True)
    ora_appuntamento = Column(String(20), nullable=True)
    campo = Column(String(120), nullable=True)
    indirizzo = Column(String(200), nullable=True)
    note = Column(Text, nullable=True)


class ListaTorneo(Base):
    __tablename__ = "liste_torneo"
    id = Column(Integer, primary_key=True)
    nome = Column(String(100), nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorie.id"), nullable=False)
    societa_id = Column(Integer, ForeignKey("societa.id"), nullable=False)
    creato_il = Column(DateTime, nullable=True)
    # NULL per le liste create a mano (esistono gia' e devono restare valide). Per quelle nate
    # da un torneo e' univoco: un torneo produce una sola lista, che e' il file bloccato da
    # consegnare. SET NULL perche' cancellare il torneo non deve cancellare il lavoro fatto
    # sulla lista da chi ci ha gia' messo i giocatori.
    torneo_id = Column(Integer, ForeignKey("tornei.id", ondelete="SET NULL"), nullable=True)


class ListaTorneoGiocatore(Base):
    __tablename__ = "liste_torneo_giocatori"
    id = Column(Integer, primary_key=True)
    lista_id = Column(Integer, ForeignKey("liste_torneo.id"), nullable=False)
    persona_id = Column(Integer, ForeignKey("persone.id"), nullable=False)
    ordine = Column(Integer, default=0)
