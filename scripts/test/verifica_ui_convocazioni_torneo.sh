#!/bin/bash
# Verifica VISIVA della convocazione di una gara di torneo e del calendario scritto dai mister, con
# Chrome headless su DEV (http://192.168.178.133:3000/tornei/19).
#
# Perche' esiste, accanto a test_convocazioni_torneo.sh (che e' nella suite e ferma il backend):
# quel file prova le regole, questo prova che la superficie ci sia. Il grep sul chunk servito dimostra
# che il testo e' distribuito, non che il pulsante sia dipinto, e questa pagina vive proprio li':
#   - il gate del calendario gare (mister + admin) e' DIVERSO da solaLettura (solo admin): se qualcuno
#     li fondesse per "fare prima", il mister si ritroverebbe Modifica/Elimina sul torneo;
#   - il modal della convocazione deve dire per quale gara, torneo e categoria si sta scrivendo, e deve
#     mostrare appuntamento e inizio gara senza scambiarli;
#   - un identificatore del template non esposto da <script setup> e' pagina bianca, e il build non lo dice.
#
# NON e' nella suite di run_suite_dev.sh (che scopre i test_*.sh): vuole Google Chrome e crea dati di
# prova con nome e categorie vere. Si lancia a mano:
#   bash scripts/test/verifica_ui_convocazioni_torneo.sh
# Esce 0 se tutto e' verde e la console della pagina e' pulita. Le schermate in /tmp/opencode/ui-conv/.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="${CHROME:-/usr/bin/google-chrome-stable}"
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" 2>&1 | tr -d '\r'; }

if [ ! -x "$CHROME" ]; then echo "serve Google Chrome ($CHROME). Sovrascrivibile con CHROME=/percorso/chrome"; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "serve node"; exit 1; fi

# Due secondi che ne risparmiano mezz'ora: se il template usa un identificatore che <script setup> non
# espone, la pagina e' BIANCA e il test sotto non troverebbe niente, sembrando un difetto dell'app
echo "--- controllo statico del template ---"
(cd "$DIR/../../frontend" && node "$DIR/controllo_template.cjs" src/features/partite/Tornei.vue)
if [ $? -ne 0 ]; then
  echo "  il template usa identificatori che <script setup> non espone: la pagina sarebbe bianca"
  echo "  0 passati, 1 falliti (controllo template)"
  exit 1
fi

echo "--- preparo i dati di prova su DEV ---"
PREP=$(bash "$DIR/prepara_demo_tornei.sh" 2>&1)
echo "$PREP" | sed 's/^/  /'
PW=$(printf '%s' "$PREP" | sed -n 's/.*password_admin_demo=\(.*\)/\1/p' | tail -1)
TID=$(printf '%s' "$PREP" | sed -n 's/.*torneo_id=\([0-9]*\).*/\1/p' | tail -1)
if [ -z "$PW" ] || [ -z "$TID" ]; then
  echo "  i dati di prova non sono stati creati: mi fermo, perche' senza pagina le asserzioni non misurano niente"
  bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
  echo "  0 passati, 1 falliti (prerequisiti)"
  exit 1
fi

echo
echo "--- apro la pagina con Chrome headless ---"
node "$DIR/ui_convocazioni_torneo.cjs" "$PW"
RC=$?

# La verita' dietro i verdi a schermo: il browser dice che il foglio mostra due convocati, il DB dice
# se quel foglio esiste davvero, e' di torneo, e non si e' agganciato a una partita di campionato.
# Si fa PRIMA della ripulitura: dopo non c'e' piu' niente da guardare.
echo
echo "--- cosa dice il database di cio' che ho visto a schermo ---"
# Stessi helper degli altri test: due valori vuoti NON sono un "ok", perche' una query che sbaglia
# restituisce stringa vuota e il confronto '' = '' sarebbe verde senza misurare niente
ck() { if [ -z "$2" ] && [ -z "$3" ]; then echo "  FAIL $1 -> entrambi vuoti: non ha misurato nulla"; RC=1; return; fi
       if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 -> '$2' (atteso '$3')"; RC=1; fi; }
ckmin() { if [ -n "$2" ] && [ "$2" -ge "$3" ] 2>/dev/null; then echo "  ok   $1 ($2 >= $3)"; else echo "  FAIL $1 -> '$2' (atteso >= $3)"; RC=1; fi; }
DB_FOGLI=$(q "SELECT count(*) FROM convocazioni c JOIN tornei_gare g ON g.id = c.tornei_gara_id
              WHERE g.torneo_id = $TID")
ckmin "il torneo ha un foglio di convocazione" "$DB_FOGLI" 1
ckmin "il foglio ha i convocati dentro" \
  "$(q "SELECT count(*) FROM convocazione_giocatori WHERE gara_id IN (SELECT cg.id FROM convocazione_gare cg JOIN convocazioni c ON c.id=cg.convocazione_id JOIN tornei_gare g ON g.id=c.tornei_gara_id WHERE g.torneo_id=$TID)")" 2
ck "il foglio non ha un weekend inventato" \
  "$(q "SELECT coalesce(weekend_id::text,'NULL') FROM convocazioni c JOIN tornei_gare g ON g.id=c.tornei_gara_id WHERE g.torneo_id=$TID LIMIT 1")" "NULL"
ck "il foglio non e' agganciato a una partita di campionato" \
  "$(q "SELECT coalesce(cg.partita_id::text,'NULL') FROM convocazione_gare cg JOIN convocazioni c ON c.id=cg.convocazione_id JOIN tornei_gare g ON g.id=c.tornei_gara_id WHERE g.torneo_id=$TID LIMIT 1")" "NULL"
ckmin "la gara aggiunta dal mister e' nel calendario" \
  "$(q "SELECT count(*) FROM tornei_gare WHERE torneo_id=$TID AND avversario='Gara messa dal mister'")" 1

echo
echo "--- ripulisco i dati di prova ---"
bash "$DIR/prepara_demo_tornei.sh" --pulisci >/dev/null
echo "  fatto"

exit $RC
