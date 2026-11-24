#!/usr/bin/env bash
# Inserisce i tornei di NATALE 2026/2027 della societa' 1 con le categorie giuste.
#
# Perche' uno script e non quattro INSERT a mano nel container:
#   1. solo il POST crea i fogli `liste_torneo` (uno per categoria) nello stesso transaction del
#      torneo. Un INSERT a mano in `tornei` produce un torneo SENZA il foglio giocatori che va
#      consegnato all'organizzatore -- ed e' esattamente il buco che quel codice esiste per chiudere
#      (in due anni, di liste, ne era stata fatta UNA).
#   2. le date le ho lette dai volantini su WhatsApp: un file che le dichiara una volta e' una cosa
#      rileggibile; quattro INSERT digitati in una sessione ssh non li rivede piu' nessuno.
#   3. e' idempotente: le coppie (torneo, categoria) gia' iscritte vengono saltate, e lo scarto
#      finale viene confrontato con cio' che il piano diceva di fare, non con un numero scritto a
#      mano. Rilancia'lo due volte non duplica niente.
#
# Categorie: i 2016 (id 19) NON si toccano, sono gia' iscritti a tutti i loro tornei (detto dal
# titolare il 23/11/2026). Il `Mister` del torneo NON si tocca: lo mette il titolare.
#
# Scelta sulle date, decisa col titolare il 23/11/2026: il modello ha UNA coppia di date per torneo,
# quindi SANTA RITA (2018 dal 19/12, 2019 dal 21/12, Piccoli Amici solo il 6/01) e' UN torneo solo
# con la finestra piu' ampia, e le date per categoria stanno in `descrizione`, che non finisce nel
# PDF dei tornei (il PDF e' solo il calendario). Un torneo per gruppo di date avrebbe riempito la
# Lista Tornei di carte chiamate tutte "SANTA RITA", cosa che il modello dice esplicitamente di non
# fare. Stessa scelta per TROFEO LODIGIANI, che il volantino non fissa nemmeno un giorno.
#
# Uso:
#   bash scripts/ops/inserisci_tornei_natale.sh            # dry-run: stampa il piano, non scrive
#   bash scripts/ops/inserisci_tornei_natale.sh --applica   # scrive su PROD
set -u

P=https://thof.crickethouse.mywire.org/api
SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132"
BE="registro_presenze-backend-1"
SOC=1
USER_OP="tornei_natale_op"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }
sq() { printf '%s' "$1" | sed "s/'/''/g"; }   # apostrofi nei letterali SQL: "DIDONE'" ne ha uno

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }
abort() { echo "  FAIL $1"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }

APPLICA=0
[ "${1:-}" = "--applica" ] && APPLICA=1

# ───────────────────────────── LE CATEGORIE ATTESE ─────────────────────────────
# Id, nome e anno scritti qui perche' su PROD ci sono TRE "Esordienti" (2014, 2015 e una archiviata)
# e DUE "Pulcini": prendere l'id "a occhio" dalla schermata e' il modo in cui si iscrive la squadra
# sbagliata a un torneo che poi parte lo stesso. Se una riga non coincide, il volantino non parla
# della squadra che crediamo: meglio fermarsi senza scrivere.
attese() {
  printf '%s\n' "25|Esordienti|2014" "26|Esordienti|2015" "20|Pulcini|2017" \
                "27|Primi Calci|2018" "28|Primi Calci|2019" "32|Piccoli Amici|2020"
}

# ───────────────────────────── IL PIANO ─────────────────────────────
# AZIONE|NOME|INIZIO|FINE|LUOGO|ORGANIZZATORE|CATEGORIE|DESCRIZIONE
#   nuovo    -> POST /tornei/                (torneo + un foglio liste_torneo per categoria)
#   aggiungi -> POST /tornei/{id}/categorie   (iscrive e crea il foglio; il torneo NON viene toccato)
# Categorie in ordine di anno crescente: la prima diventa `tornei.categoria_id`, quella del badge
# della card e dell'ingresso da Scelta.vue.
piano() {
cat <<'PIANO'
nuovo|SANTA RITA|2026-12-19|2027-01-06|Via degli Acquaroni, 71 - Roma|SANTA RITA|27,28,32|Natale sotto le Torri. Date per categoria (dal volantino): 2018 Primi Calci dal 19/12/2026 al 6/01/2027; 2019 Primi Calci dal 21/12/2026 al 6/01/2027; Piccoli Amici 2020-21-22 solo il 6/01/2027.
nuovo|VIESSE CUP|2027-01-02|2027-01-03|Via dei Ruderi di Torrenova, 2 - Roma (Giardinetti)|GIARDINETTI|20,27|Torneo del 2-3 gennaio 2027, campo dei Giardinetti.
nuovo|DIDONE'|2026-12-21|2027-01-04|Via Pazzano, 1 - Morena (Roma)|ATLETICO MORENA|25|Date: 21-22-23-28-29-30 dicembre 2026 e 4 gennaio 2027.
nuovo|TROFEO LODIGIANI|2026-12-19|2027-01-02|Via della Capanna Murata, 120 - Roma|LODIGIANI|20|La giornata esatta la comunica l'organizzatore: una tra il 19-20-23-27-28-29 dicembre 2026. Le migliori 9 si qualificano alle fasi finali del 30/12/2026, le migliori 3 passano al 2 gennaio 2027.
nuovo|TORNEO FRANZELLITTI|2026-12-27|2027-01-06|Via F. Domiziano, 10 - Roma|GRIFONE CALCIO|26|Triangolare il 27/12/2026, finali il 6/01/2027.
aggiungi|FM 10|||||25,26,20,27,28|
aggiungi|RADIO ROCK CHRISTMAS CUP|||||26,20,27,28|
PIANO
}

echo "=== 1. prerequisiti: le categorie del volantino sono quelle che crediamo ==="
while IFS='|' read -r cid cnome canno; do
  [ -z "$cid" ] && continue
  reale=$(q "SELECT coalesce(nome,'-')||'|'||coalesce(anno::text,'-')||'|'||coalesce(societa_id::text,'-')||'|'||coalesce(is_archiviata::text,'-')
               FROM categorie WHERE id=$cid;")
  ck "categoria $cid e' '$cnome $canno' (societa' $SOC, non archiviata)" "$reale" "$cnome|$canno|$SOC|0"
done < <(attese)
if [ $fail -ne 0 ]; then
  echo "  BLOCCATO: una categoria non coincide. Il volantino potrebbe riferirsi a un'altra squadra,"
  echo "  o l'id e' cambiato nel frattempo. Nessuna scrittura."
  echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1
fi

echo
echo "=== 2. il piano, contro quello che c'e' gia' su PROD ==="
# Le coppie (torneo, categoria) gia' iscritte si scartano QUI, non dopo: solo cosi' il conto finale
# si puo' confrontare con le intenzioni invece che con un numero scritto a mano.
declare -A META          # nome -> "inizio|fine|luogo|organizzatore|descrizione"
DA_FARE=(); N_TORNEI_NUOVI=0
while IFS='|' read -r azione nome inizio fine luogo org cats descr; do
  [ -z "$azione" ] && continue
  META["$nome"]="$inizio|$fine|$luogo|$org|$descr"
  tid=$(q "SELECT id FROM tornei WHERE societa_id=$SOC AND lower(trim(nome))=lower('$(sq "$nome")') ORDER BY id LIMIT 1;")
  if [ "$azione" = "aggiungi" ] && [ -z "$tid" ]; then
    # FM 10 e RADIO ROCK DEVONO essere gia' lì. Se non ci sono, il nome sul volantino non coincide
    # con quello che il titolare ha inserito: lasciar correre significherebbe creare un torneo nuovo
    # SENZA date (i campi del piano, per gli `aggiungi`, sono vuoti di proposito).
    echo "  FAIL '$nome' dovrebbe esistere gia' e non l'ho trovato: fermi tutti"
    echo "  $pass passati, $((fail+1)) falliti (prerequisiti)"; exit 1
  fi
  da_oggi=""
  for c in ${cats//,/ }; do
    if [ "$azione" = "nuovo" ] && [ -z "$tid" ]; then
      DA_FARE+=("$nome|$c"); da_oggi="$da_oggi $c"
    else
      n=$(q "SELECT count(*) FROM tornei_categorie WHERE torneo_id=$tid AND categoria_id=$c;")
      if [ "$n" = "0" ]; then DA_FARE+=("$nome|$c"); da_oggi="$da_oggi $c"
      else echo "  -    $nome: la categoria $c c'e' gia', la lascio stare"; fi
    fi
  done
  if [ "$azione" = "nuovo" ] && [ -n "$tid" ]; then
    echo "  -    ATTENZIONE: '$nome' esiste gia' (id $tid): non ne creo un secondo, aggiungo solo le categorie mancanti"
  fi
  [ "$azione" = "nuovo" ] && [ -z "$tid" ] && N_TORNEI_NUOVI=$((N_TORNEI_NUOVI+1))
  echo "  *    $azione '$nome'${tid:+ (id $tid)} -> categorie:${da_oggi:- nessuna}"
done < <(piano)
echo "  da scrivere: ${#DA_FARE[@]} iscrizioni, di cui $N_TORNEI_NUOVI tornei nuovi"

if [ $APPLICA -ne 1 ]; then
  echo
  echo "  DRY-RUN: non ho scritto niente. Riesci con --applica per farlo davvero."
  echo "  $pass passati, $fail falliti"; exit 0
fi
[ ${#DA_FARE[@]} -eq 0 ] && { echo "  niente da fare, il piano e' gia' soddisfatto."; echo "  $pass passati, $fail falliti"; exit 0; }

echo
echo "=== 3. admin temporaneo + API ==="
# Serve un utente perche' POST /tornei chiede get_responsabile_tornei (admin/super_admin). Si cancella
# alla fine, trap su EXIT: un admin con password nota lasciato su PROD e' un danno ben piu' grande di
# un `creato_da` orfano (quella colonna non ha FK, il numero sopravvive all'utente).
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r')
[ -z "$HASH" ] && abort "impossibile generare l'hash nel container backend"

pulisci_utente() {
  $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -c \"DELETE FROM utente_categorie WHERE utente_id IN (SELECT id FROM utenti WHERE username='$USER_OP'); DELETE FROM utenti WHERE username='$USER_OP';\"" >/dev/null 2>&1
}
trap 'pulisci_utente; echo "  admin temporaneo rimosso"' EXIT
pulisci_utente   # nessun residuo di un run precedente, prima di catturare la baseline

PRIMA_T=$(q "SELECT count(*) FROM tornei WHERE societa_id=$SOC")
PRIMA_TC=$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id WHERE t.societa_id=$SOC")
PRIMA_LT=$(q "SELECT count(*) FROM liste_torneo l JOIN tornei t ON t.id=l.torneo_id WHERE t.societa_id=$SOC")
# I 2016 si misurano PRIMA e si riconfronta DOPO: non un 5 scritto a mano, che sarebbe il conteggio
# di una sera e diventerebbe rosso da solo il giorno che il titolare iscrive i Pulcini a un altro torneo
PRIMA_2016=$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id WHERE t.societa_id=$SOC AND tc.categoria_id=19;")
echo "  baseline: tornei=$PRIMA_T iscrizioni=$PRIMA_TC fogli=$PRIMA_LT iscrizioni-2016=$PRIMA_2016"

q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
     VALUES ('$USER_OP','$HASH',$SOC,1,0,'admin');" >/dev/null
TOK=$(curl -s --max-time 25 -X POST "$P/auth/token" -d "username=$USER_OP&password=$PW" \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
[ -z "$TOK" ] && abort "login dell'admin temporaneo fallito: nessun token, non scrivo niente"
echo "  admin temporaneo connesso"

# Un solo POST per torneo nuovo: torneo + TUTTE le sue categorie + i suoi fogli, in un transaction.
# Creare un torneo a pezzi lascerebbe una finestra con il torneo senza il foglio da consegnare.
FERMATI=""
for riga in "${DA_FARE[@]}"; do
  nome="${riga%%|*}"; cat="${riga##*|}"
  case "$FERMATI" in *"|$nome|"*) continue;; esac
  IFS='|' read -r inizio fine luogo org descr <<< "${META[$nome]}"
  if ! q "SELECT 1 FROM tornei WHERE societa_id=$SOC AND lower(trim(nome))=lower('$(sq "$nome")');" | grep -q '^1$'; then
    FERMATI="$FERMATI|$nome"
    cats=$(while IFS='|' read -r a n i2 f2 l2 o2 c2 d2; do [ "$n" = "$nome" ] && printf '%s' "$c2"; done < <(piano))
    json=$(nome="$nome" inizio="$inizio" fine="$fine" luogo="$luogo" org="$org" cats="$cats" descr="$descr" python3 - <<'PY'
import json, os
print(json.dumps({
    "nome": os.environ["nome"],
    "categorie_id": [int(c) for c in os.environ["cats"].split(",") if c],
    "data_inizio": os.environ["inizio"] or None,
    "data_fine": os.environ["fine"] or None,
    "luogo": os.environ["luogo"] or None,
    "organizzatore": os.environ["org"] or None,
    "descrizione": os.environ["descr"] or None,
}, ensure_ascii=False))
PY
)
    attese_n=$(printf '%s' "$cats" | tr ',' '\n' | grep -c .)
    ris=$(printf '%s' "$json" | curl -s --max-time 30 -X POST "$P/tornei/" -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOK" --data-binary @-)
    id=$(printf '%s' "$ris" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    nfog=$(printf '%s' "$ris" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('liste') or []))" 2>/dev/null)
    ck "creato '$nome': l'API restituisce un id" "$([ -n "$id" ] && echo si)" "si"
    ck "creato '$nome': $attese_n fogli giocatori creati insieme a lui" "${nfog:-0}" "$attese_n"
    [ -z "$id" ] && echo "       risposta: $(printf '%s' "$ris" | head -c 300)"
  else
    tid=$(q "SELECT id FROM tornei WHERE societa_id=$SOC AND lower(trim(nome))=lower('$(sq "$nome")') ORDER BY id LIMIT 1;")
    cod=$(curl -s -o /tmp/opencode/.tn_ris -w '%{http_code}' --max-time 30 -X POST "$P/tornei/$tid/categorie" \
            -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" \
            --data "{\"categoria_id\": $cat}")
    ck "'$nome' (id $tid): iscritta la categoria $cat" "$cod" "200"
    [ "$cod" != "200" ] && echo "       risposta: $(head -c 200 /tmp/opencode/.tn_ris 2>/dev/null)"
  fi
done

echo
echo "=== 4. cosa dice il DATABASE (la risposta HTTP non e' una prova) ==="
T=$(q "SELECT count(*) FROM tornei WHERE societa_id=$SOC")
TC=$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id WHERE t.societa_id=$SOC")
LT=$(q "SELECT count(*) FROM liste_torneo l JOIN tornei t ON t.id=l.torneo_id WHERE t.societa_id=$SOC")
ck "i tornei sono cresciuti di $N_TORNEI_NUOVI" "$T" "$((PRIMA_T + N_TORNEI_NUOVI))"
ck "le iscrizioni sono cresciute di ${#DA_FARE[@]}" "$TC" "$((PRIMA_TC + ${#DA_FARE[@]}))"
ck "ogni iscrizione ha il SUO foglio giocatori (liste_torneo)" "$LT" "$((PRIMA_LT + ${#DA_FARE[@]}))"
ck "i 2016 (cat 19) sono rimasti come erano" "$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id WHERE t.societa_id=$SOC AND tc.categoria_id=19;")" "$PRIMA_2016"

for riga in "${DA_FARE[@]}"; do
  nome="${riga%%|*}"; cat="${riga##*|}"
  n=$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id
          WHERE t.societa_id=$SOC AND lower(trim(t.nome))=lower('$(sq "$nome")') AND tc.categoria_id=$cat;")
  ck "'$nome' ha la categoria $cat" "$n" "1"
  f=$(q "SELECT count(*) FROM liste_torneo l JOIN tornei t ON t.id=l.torneo_id
          WHERE t.societa_id=$SOC AND lower(trim(t.nome))=lower('$(sq "$nome")') AND l.categoria_id=$cat;")
  ck "'$nome'/$cat ha il foglio giocatori" "$f" "1"
  dup=$(q "SELECT count(*) FROM tornei WHERE societa_id=$SOC AND lower(trim(nome))=lower('$(sq "$nome")');")
  ck "'$nome' esiste UNA sola volta (nessun doppio inserimento)" "$dup" "1"
done

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ] || exit 1
