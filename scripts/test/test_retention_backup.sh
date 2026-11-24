#!/bin/bash
# Guard-rail sulla RETENTION dei backup offsite: la selezione di cosa cancellare deve sapere cosa
# conservare.
#
# Perche' esiste. Il cron delle 03:00 di PROD, per circa 60 giorni, ha cancellato ogni notte LA
# RELEASE CHE AVEVA APPENA CREATO. Il log di stanotte, prima della correzione:
#
#     ☁️ Creazione Release 'backup-20261124_030001'... Release creata con ID: 456253387
#     🧹 Verifica retention (conservazione ultimi 14 giorni)...
#        Eliminazione vecchio backup: backup-20261124_030001 (ID: 456253387)...     <-- la stessa
#     🎉 Procedura di Backup Offsite completata con successo!
#
# La causa, misurata su andmor8277/thof-backups il 24/11/2026: la release creata QUEL GIORNO aveva
#     creata=2026-09-25T07:27:04   pubbl=2026-11-24T12:33:20
# e il codice confrontava `created_at` con il cutoff di 14 giorni. `created_at` su quelle release e'
# di settembre, quindi ogni backup risultava "vecchio di 60 giorni" e veniva cancellato. In sei mesi
# la storia offsite e' scesa a UNA release, e i file .enc locali erano zero: l'unica copia del DB era
# il dump di quel pomeriggio. Nessuna asserzione, nessun avviso, nessun rosso.
#
# Perche' NON basta cambiare il campo. `created_at` -> `published_at` e' la meta' del lavoro (e
# infatti qualcuno l'aveva gia' messo a mano su PROD alle 12:35 di oggi, senza committarlo: se
# deployavo senza accorgermene, il `git reset --hard` di deploy.sh lo cancellava e stanotte il cron
# avrebbe cancellato anche l'ultimo backup rimasto). Le guardie sotto sono l'altra meta', e servono
# perche' il modo in cui questo difetto si e' manifestato non era "un errore": era un successo
# dichiarato. Ognuna di queste asserzioni e' la notte in cui il cron non cancella la copia giusta.
#
# Attenzione a cosa NON e' questo test: non e' "non cancellare mai". L'asserzione 2 verifica che
# cancelli ancora le release davvero vecchie, perche' una retention che non cancella mai sembrerebbe
# perfetta e farebbe esplodere il quota di GitHub.
#
# Si lancia da solo: non tocca ne' DEV ne' PROD ne' il DB, e non chiama mai l'API. Gli input sono
# fixture, e la selezione e' chiamata come la chiama lo script.
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$DIR" || { echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL non riesco a entrare nella root"; exit 1; }
LIB=scripts/lib/selezione_retention.py
BACKUP=scripts/backup_offsite_github.sh

for f in "$LIB" "$BACKUP"; do
  if [ ! -f "$f" ]; then
    echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL manca $f"; exit 1
  fi
done
python3 -c "import ast,sys; ast.parse(open('$LIB').read())" 2>/dev/null || {
  echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL $LIB non e' python valido"; exit 1; }
bash -n "$BACKUP" 2>/dev/null || {
  echo "  0 passati, 1 falliti (prerequisiti)"; echo "  FAIL $BACKUP non e' bash valido"; exit 1; }

pass=0; fail=0
ck() { # ck <cosa> <avuto> <atteso>  -- due vuoti NON sono un "ok" (lezione gia' pagata in test_tornei.sh)
  if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: non e' un ok, non ha misurato niente"
  elif [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"
  else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi
}
ckn() { # ckn <cosa> <avuto> <atteso-numerico>
  ck "$1" "${2:-NESSUNO}" "${3:-NESSUNO}"
}

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# lancia il selettore: stdout in $TMP/out, stderr in $TMP/err, rc globale RC
lancia() { # lancia <fixture> [argomenti...]
  local fx="$1"; shift
  RC=$(python3 "$LIB" "$@" < "$fx" > "$TMP/out" 2> "$TMP/err"; echo $?)
  OUT=$(cat "$TMP/out")
  ERR=$(cat "$TMP/err")
}
# quante righe NON VUOTE. Non `echo -n "$OUT" | wc -l`: la sostituzione della comando sostituisce
# azzera i newline finali, quindi DUE righe ne risultano UNA -- e questo test ha detto 1 dove ce
# n'erano 2, verde sul nulla. Prima di fidarsi di un conteggio, contarne due noti.
quante() { local t="$1"; if [ -z "${t//[[:space:]]/}" ]; then echo 0; else printf '%s\n' "$t" | grep -c .; fi; }
# il codice senza le righe di commento. Un grep che matcha un commento che SPIEGA il difetto e' il
# falso verde (o il falso rosso) gia' pagato nel negative test delle migrazioni.
codice() { grep -v '^[[:space:]]*#' "$1"; }
# data N giorni fa, nel formato di GitHub
giorni_fa() { date -u -d "-${1} days" +%Y-%m-%dT%H:%M:%SZ; }
CUTOFF=$(giorni_fa 14)

echo "=== prerequisito: il contatore di righe conta davvero ==="
# Due righe note. Senza questa, il bug di `echo -n "$OUT" | wc -l` (che conta i newline, e la
# sostituzione della comando sostituisce ne azzera uno) ha reso VERDE "2 release cancellate" quando
# ne risultava 1. Se il contatore mente, tutto il resto del file non misura niente.
ck "due righe note sono due" "$(quante "$(printf 'a\nb')")" "2"
ck "una riga e' una" "$(quante "una-sola")" "1"
ck "il vuoto e' zero, non uno" "$(quante "")" "0"

echo
echo "=== il caso reale: il campo sbagliato cancellava il backup appena fatto ==="
# la release di PROD, byte per byte com'e' stata misurata
cat > "$TMP/reale.json" <<'JSON'
[{"id":456253387,"tag_name":"backup-20261124_123319",
  "created_at":"2026-09-25T07:27:04Z","published_at":"2026-11-24T12:33:20Z","draft":false}]
JSON
lancia "$TMP/reale.json" --cutoff "$CUTOFF"
ckn  "la release creata oggi NON viene cancellata (era QUELLO il difetto)" "$(quante "$OUT")" 0
ck   "e non viene cancellata nemmeno se il suo created_at e' di settembre" "$RC" "0"
# il rovescio: se qualcuno rimette created_at come campo, questa fixture torna a essere cancellata
ck   "il campo che dice l'eta' e' dichiarato in un punto solo, cosi' il rosso dice subito cosa e' cambiato" \
     "$(grep -c "^CAMPO_ETA = 'published_at'" "$LIB")" "1"

echo
echo "=== ma la retention deve continuare a fare il suo lavoro ==="
cat > "$TMP/miste.json" <<JSON
[{"id":1,"tag_name":"backup-vecchio-A","published_at":"$(giorni_fa 30)"},
 {"id":2,"tag_name":"backup-vecchio-B","published_at":"$(giorni_fa 20)"},
 {"id":3,"tag_name":"backup-fresco","published_at":"$(giorni_fa 0)"}]
JSON
lancia "$TMP/miste.json" --cutoff "$CUTOFF"
ckn  "delle 3 release, 2 sono davvero vecchie e vanno cancellate" "$(quante "$OUT")" 2
ck   "e sono quelle giuste, non altre" "$(cut -f2 <<<"$OUT" | sort | tr '\n' ' ')" "backup-vecchio-A backup-vecchio-B "
ck   "il separatore e' il TAB, non i due punti (un tag con un : non si deve troncare)" \
     "$(cut -f1 <<<"$OUT" | sort | tr '\n' ' ')" "1 2 "
# Serve una release da conservare in mezzo: da sola sarebbe "tutte", e la guardia G4 la proteggerebbe
# tutte -- il tag tronco non verrebbe mai misurato.
cat > "$TMP/doppio-punti.json" <<JSON
[{"id":9,"tag_name":"backup:2026:vecchio","published_at":"$(giorni_fa 40)"},
 {"id":10,"tag_name":"backup-fresco","published_at":"$(giorni_fa 1)"}]
JSON
lancia "$TMP/doppio-punti.json" --cutoff "$CUTOFF"
ck   "un tag che contiene due punti esce intero (il vecchio cut -d: -f2 lo troncava)" \
     "$(cut -f2 <<<"$OUT")" "backup:2026:vecchio"

echo
echo "=== le guardie: quando non capisce, NON cancella ==="
# G2: published_at assente. Il codice vecchio faceva r.get('created_at','') < cutoff, e '' < '2026-'
# e' VERO: una release senza data era cancellata perche' "piu' vecchia di tutte".
cat > "$TMP/senza-data.json" <<JSON
[{"id":11,"tag_name":"backup-senza-data"},
 {"id":12,"tag_name":"backup-pubblicato-null","published_at":null},
 {"id":13,"tag_name":"backup-pubblicato-vuoto","published_at":""}]
JSON
lancia "$TMP/senza-data.json" --cutoff "$CUTOFF"
# RC asserito: senza la guardia, `fromisoformat(None)` va in eccezione, non stampa niente, e
# "non cancella mai" sarebbe rimasto VERDE perche' il programma e' morto. E' il falso verde che
# questo giro ha prodotto alla prima esecuzione del negative test.
ck   "il selettore gira e non va in eccezione su una data assente" "$RC" "0"
ckn  "una release senza published_at NON si cancella mai (il caso che cancellava tutto)" \
     "$(quante "$OUT")" 0
ck   "e lo dice, perche' un conservato-perche'-non-misurabile deve essere visibile" \
     "$(grep -c 'conservate perche' "$TMP/err")" "1"

# G3: la release appena creata non e' cancellabile mai
cat > "$TMP/keep.json" <<JSON
[{"id":77,"tag_name":"backup-di-stanotte","published_at":"$(giorni_fa 90)"},
 {"id":78,"tag_name":"backup-veramente-vecchio","published_at":"$(giorni_fa 90)"}]
JSON
lancia "$TMP/keep.json" --cutoff "$CUTOFF" --keep 77
# Due release, entrambe vecchie: se il --keep si rompe, la guardia G4 non puo' coprirlo -- senza
# --keep sarebbero "tutte da cancellare" e il selettore rifiuterebbe, lasciando l'elenco VUOTO. Un
# "non ha cancellato niente" ottenuto perche' ha rifiutato tutto non e' una prova del --keep: e' il
# falso verde che questo giro ha prodotto alla prima esecuzione.
ck   "il selettore gira davvero (un crash o un rifiuto lascerebbero l'elenco vuoto e sarebbe verde)" "$RC" "0"
ckn  "delle due vecchie, una sola viene cancellata" "$(quante "$OUT")" 1
ck   "e non e' quella di stanotte: il --keep salva QUELLA, non una a caso" \
     "$(cut -f2 <<<"$OUT")" "backup-veramente-vecchio"

# G4: azzerare tutta la storia non e' mai legittimo
cat > "$TMP/tutte-vecchie.json" <<JSON
[{"id":21,"tag_name":"backup-a","published_at":"$(giorni_fa 40)"},
 {"id":22,"tag_name":"backup-b","published_at":"$(giorni_fa 45)"}]
JSON
lancia "$TMP/tutte-vecchie.json" --cutoff "$CUTOFF"
ck   "se la selezione copre TUTTE le release, refuse (rc 3)" "$RC" "3"
ckn  "e in stdout non esce niente, quindi bash non cancella nulla" "$(quante "$OUT")" 0
ck   "il rifiuto e' spiegato nel messaggio" "$(grep -c 'rifiutato' "$TMP/err")" "1"
# e con una release fresca in mezzo, le vecchie si cancellano eccome
cat > "$TMP/non-tutte.json" <<JSON
[{"id":21,"tag_name":"backup-a","published_at":"$(giorni_fa 40)"},
 {"id":23,"tag_name":"backup-fresco","published_at":"$(giorni_fa 1)"}]
JSON
lancia "$TMP/non-tutte.json" --cutoff "$CUTOFF"
ck   "ma con una release da conservare in mezzo, la guardia non scatta e le vecchie vanno" "$RC" "0"
ckn  "e una sola release viene cancellata" "$(quante "$OUT")" 1

echo
echo "=== l'API che risponde male: il modo piu' probabile di perdere i backup ==="
lancia /dev/null --cutoff "$CUTOFF"
ck   "stdin vuoto (curl fallito) -> rc 2" "$RC" "2"
ckn  "e nessun backup cancellato" "$(quante "$OUT")" 0
echo '{"message": "Bad credentials"}' > "$TMP/oggetto.json"
lancia "$TMP/oggetto.json" --cutoff "$CUTOFF"
ck   "l'API che risponde un oggetto (token scaduto) -> rc 2, non 'lista vuota'" "$RC" "2"
ckn  "e nessun backup cancellato" "$(quante "$OUT")" 0
echo 'non-e-json' > "$TMP/rotto.json"
lancia "$TMP/rotto.json" --cutoff "$CUTOFF"
ck   "JSON rotto -> rc 2" "$RC" "2"
lancia "$TMP/reale.json"            # nessun --cutoff
ck   "senza --cutoff non si confronta niente -> rc 2 (il vecchio saltava in silenzio)" "$RC" "2"
lancia "$TMP/reale.json" --cutoff ieri
ck   "--cutoff che non e' una data -> rc 2" "$RC" "2"

echo
echo "=== stdout deve contenere SOLO l'elenco: bash lo itera ==="
lancia "$TMP/miste.json" --cutoff "$CUTOFF"
ck   "il conteggio va su stderr e non sporca l'elenco" \
     "$(grep -c 'release totali' "$TMP/out")" "0"
ck   "il conteggio c'e', ma su stderr (un elenco muto non e' una prova)" \
     "$(grep -c 'release totali' "$TMP/err")" "1"

echo
echo "=== cablaggio: lo script deve davvero usare il selettore ==="
ck   "il selettore e' chiamato con --keep sulla release appena creata" \
     "$(codice "$BACKUP" | grep -c -- '--keep "\${RELEASE_ID}"')" "1"
ck   "il selettore esterno e' invocato, non riscritto a mano dentro lo script" \
     "$(codice "$BACKUP" | grep -c 'lib/selezione_retention.py')" "1"
ck   "lo script non confronta piu' created_at da solo" "$(codice "$BACKUP" | grep -c 'created_at')" "0"
ck   "non esiste piu' nessun secondo ramo jq della stessa regola (jq non c'e' nemmeno su PROD)" \
     "$(codice "$BACKUP" | grep -c 'command -v jq')" "0"
ck   "a fine giro VERIFICA che il backup di stanotte esista ancora su GitHub" \
     "$(grep -c 'NON risulta su GitHub' "$BACKUP")" "1"
ck   "e se non c'e', il cron esce rosso invece di dichiarare successo" \
     "$(grep -A3 'NON risulta su GitHub' "$BACKUP" | grep -c 'exit 1')" "1"
ck   "il DELETE non buttava piu' via la risposta: il codice HTTP e' osservato" \
     "$(grep -c "w '%{http_code}'" "$BACKUP")" "1"

echo "  ------------------------------------------------------------------"
echo "  $pass passati, $fail falliti"
[ "$fail" = "0" ] || exit 1
