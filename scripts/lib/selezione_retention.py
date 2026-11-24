#!/usr/bin/env python3
"""Seleziona le release di backup da cancellare. UNA SOLA implementazione della regola.

Perche' un file a se'. La selezione stava dentro scripts/backup_offsite_github.sh in DUE rami
diversi (jq e python3) con la stessa regola scritta due volte. Su PROD `jq` **non e' installato**
(verificato il 24/11/2026: `command -v jq` vuoto, /usr/bin/python3 presente), quindi il ramo jq non
e' mai stato eseguito da nessuno su nessuna macchina: la copia mai provata di una regola che
cancella dati. E' la stessa classe di divergenza che questo progetto registra gia' per i PDF e per
i ruoli. Un file solo, provato.

Perche' la regola ha bisogno di guardie, e non solo del campo giusto. Il cron delle 03:00 di PROD
per ~60 giorni ha cancellato **ogni notte la release che aveva appena creato**, e il log chiudeva
con "🎉 Procedura di Backup Offsite completata con successo". La prova, misurata il 24/11/2026:

    backup-20261124_123319   creata=2026-09-25T07:27:04   pubbl=2026-11-24T12:33:20

La release creata **quel giorno alle 12:33** aveva `created_at` di settembre. Il codice confrontava
`created_at` con il cutoff di 14 giorni: "vecchio di 60 giorni" -> cancellata. Il campo che dice
l'eta' reale di un backup e' `published_at`. Ma il campo sbagliato era solo la meta' del problema,
e le guardie sotto sono la ragione per cui questo file non si limita a rinominarlo:

  G2  `published_at` assente/null/vuoto -> **mai** cancellare. Il codice vecchio faceva
      `r.get('created_at','') < cutoff`, e `'' < '2026-...'` e' VERO: una release senza data veniva
      cancellata perche' "piu' vecchia di tutte". Un selettore che, quando non capisce, cancella, e'
      un selettore che cancella tutto la notte in cui l'API risponde male.
  G4  se la selezione copre TUTTE le release -> refuse (exit 3). Un giro di retention che vuole
      cancellare l'intera storia offsite non e' mai legittimo: e' un orologio, un cutoff o un campo
      sbagliato. Meglio un backup in piu' che nessun backup.
  G3  la release appena creata (--keep) non e' mai cancellabile, a prescindere dalle sue date.
  G5/G6  JSON rotto o cutoff mancante -> exit 2 e nessuna riga in stdout: il chiamante non cancella
      niente. Il modo di fallire di questo script e' sempre "non cancellare".

Uscita: righe `id<TAB>tag_name` su stdout. TAB e non due punti perche' `cut -d: -f2` troncava un tag
che contenesse un due punti.
"""
import json
import sys
from datetime import datetime, timezone

CAMPO_ETA = 'published_at'   # NON created_at: vedi il docstring


def _errore(msg, codice=2):
    """Non stampa nulla su stdout: nessun output = nessun backup cancellato."""
    print(f'ERRORE: {msg}', file=sys.stderr)
    sys.exit(codice)


def main(argv):
    cutoff, tieni = None, None
    i = 0
    while i < len(argv):
        if argv[i] == '--cutoff':
            i += 1
            cutoff = argv[i] if i < len(argv) else None
        elif argv[i] == '--keep':
            i += 1
            tieni = argv[i] if i < len(argv) else None
        else:
            _errore(f'argomento sconosciuto: {argv[i]!r}')
        i += 1

    # G6: senza un cutoff valido non si confronta niente. Il codice vecchio saltava il blocco in
    # silenzio quando `date` non rispondeva; qui e' un rosso che si vede.
    if not cutoff:
        _errore('manca --cutoff: senza un termine di confronto non si cancella nulla')
    try:
        # accetta sia l'ISO di GitHub sia il 'YYYY-MM-DD HH:MM:SS UTC' di verifica_deploy.sh
        tagli = datetime.fromisoformat(cutoff.strip().replace('Z', '+00:00').replace(' UTC', '+00:00'))
        if tagli.tzinfo is None:
            tagli = tagli.replace(tzinfo=timezone.utc)
    except ValueError:
        _errore(f'--cutoff non e\' una data interpretabile: {cutoff!r}')

    grezzo = sys.stdin.read()
    if not grezzo.strip():
        _errore('stdin vuoto: la lista delle release non e\' arrivata (curl ha fallito?)')
    try:
        release = json.loads(grezzo)
    except json.JSONDecodeError as e:
        # qui finisce anche il caso reale piu' probabile: GitHub che risponde
        # {"message": "Bad credentials"} invece di una lista
        _errore(f'JSON non valido ({e}): la risposta dell\'API non e\' una lista di release')
    if isinstance(release, dict):
        _errore(f'l\'API ha risposto un oggetto, non una lista: {release.get("message", release)!r}')
    if not isinstance(release, list):
        _errore(f'attesa una lista, arrivata {type(release).__name__}')

    # G3: la release appena creata non e' cancellabile. Confrontata come stringa perche' l'id arriva
    # dall'ambiente di bash.
    tieni = str(tieni) if tieni not in (None, '') else None

    selezionate, conservate, senza_data = [], [], 0
    for r in release:
        if not isinstance(r, dict):
            continue
        rid, tag = r.get('id'), r.get('tag_name')
        # senza id o senza nome non si puo' cancellare NEANCHE volendo: il DELETE dell'id e quello
        # del tag sono due chiamate diverse e una meta' sola lascerebbe un tag orfano
        if rid is None or not tag:
            continue
        if tieni is not None and str(rid) == tieni:
            conservate.append(tag)
            continue
        data = r.get(CAMPO_ETA)
        # G2: nessuna data = nessuna prova che sia vecchia. Si conserva.
        if not data or not isinstance(data, str):
            senza_data += 1
            conservate.append(tag)
            continue
        try:
            nata = datetime.fromisoformat(data.replace('Z', '+00:00'))
            if nata.tzinfo is None:
                nata = nata.replace(tzinfo=timezone.utc)
        except ValueError:
            senza_data += 1
            conservate.append(tag)
            continue
        if nata < tagli:
            selezionate.append((rid, tag))
        else:
            conservate.append(tag)

    # G4: azzerare tutta la storia offsite in un giro solo non e' mai il comportamento giusto.
    totali = len(selezionate) + len(conservate)
    if totali and not conservate:
        _errore(f'la retention vuole cancellare TUTTE le {totali} release: rifiutato. '
                'Tenere tutti i backup e\' sempre meglio che non averne piu\'.', 3)

    for rid, tag in selezionate:
        print(f'{rid}\t{tag}')
    # il conteggio va su stderr: stdout e\' l'elenco che bash itera, sporcandolo si cancellerebbe
    # una riga inventata
    print(f'release totali {totali}  da cancellare {len(selezionate)}  da conservare {len(conservate)}'
          + (f'  senza {CAMPO_ETA} (conservate perche\' non misurabili) {senza_data}' if senza_data else ''),
          file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
