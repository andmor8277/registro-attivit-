#!/bin/bash
# Ruota SECRET_KEY (e per compatibilita' anche DEFAULT_PASSWORD, che pero' dal 2026-11-16 non e'
# piu' usata dall'applicazione: i reset generano una password casuale per il singolo utente).
# Con prova prima/dopo.
#
# Uso: ruota_segreti.sh dev|prod
#
# I valori nuovi vengono generati SUL SERVER e non vengono mai stampati: il test li legge dal
# .env dentro una variabile e li usa per le richieste. Vengono mostrati solo gli sha256, che
# bastano per dimostrare che il valore e' cambiato e che DEV e PROD non coincidono piu'.
#
# Richiede il backup del .env gia' fatto (cp -p .env /root/env_backup_<ts>).
set -u
AMBIENTE="${1:-dev}"
case "$AMBIENTE" in
  dev)  KV=~/.ssh/id_ed25519_dev;  IP=192.168.178.133; D=http://192.168.178.133:3000/api ;;
  prod) KV=~/.ssh/id_ed25519_prod; IP=192.168.178.132; D=https://thof.crickethouse.mywire.org/api ;;
  *) echo "  uso: $0 dev|prod"; exit 2 ;;
esac
SSH="ssh -i $KV -o ConnectTimeout=15 root@$IP"
ENVF=/opt/registro_presenze/.env
BE=registro_presenze-backend-1
# su PROD la configurazione e' la sovrapposizione dei due file: senza il prod.yml si riavvierebbe
# con i settings sbagliati (porte, workers)
if [ "$AMBIENTE" = "prod" ]; then CF="-f docker-compose.yml -f docker-compose.prod.yml"; else CF=""; fi
BACKUP=$(timeout 60 $SSH "ls -1t /root/env_backup_* 2>/dev/null | head -1" | tr -d '\r')
[ -z "$BACKUP" ] && { echo "  MANCA IL BACKUP del .env su $IP: annullato senza toccare nulla"; exit 1; }
echo "  ambiente=$AMBIENTE  backup .env=$BACKUP"

q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }
pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$@"; }
# --data-urlencode perche' le password temporanee generate dal reset contengono &, % e #:
# passarle grezze in un body form fa arrivare al server una password troncata
tok() { curl -s --max-time 25 -X POST "$D/auth/token" \
          --data-urlencode "username=$1" --data-urlencode "password=$2" \
        | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null; }
leggi() { timeout 60 $SSH "sed -n 's/^$1=//p' $2" 2>/dev/null | head -1 | tr -d '\r\n'; }
hashof() { printf '%s' "$1" | sha256sum | cut -c1-16; }

echo "--- preparazione: admin e utente da resettare ---"
AM="testrot_admin@x.local"; VM="testrot_vittima@x.local"
PWAM="Rot-Admin-$(openssl rand -hex 6)"; PWVM="Rot-Vittima-$(openssl rand -hex 6)"
HAM=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PWAM'))\"" 2>/dev/null | tr -d '\r' | tail -1)
HVM=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PWVM'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HAM" ] || [ -z "$HVM" ] && { echo "  impossibile generare gli hash"; exit 1; }
q "DELETE FROM utenti WHERE username IN ('$AM','$VM');
   INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('$AM','$HAM',1,1,0,'admin'), ('$VM','$HVM',1,0,0,'dirigente');" >/dev/null
ck "utenti di prova creati" "$(q "SELECT count(*) FROM utenti WHERE username IN ('$AM','$VM')")" "2"
UID_VM=$(q "SELECT id FROM utenti WHERE username='$VM'")

TOK_OLD=$(tok "$VM" "$PWVM")
ck "login iniziale -> token emesso" "$([ -n "$TOK_OLD" ] && echo si)" "si"
ck "  il token funziona PRIMA della rotazione" "$(cod "$D/auth/me" -H "Authorization: Bearer $TOK_OLD")" "200"
SK_PRIMA=$(hashof "$(leggi SECRET_KEY $ENVF)")
DP_PRIMA=$(hashof "$(leggi DEFAULT_PASSWORD $ENVF)")
DP_VECCHIA=$(leggi DEFAULT_PASSWORD "$BACKUP")
echo "  prima: SECRET_KEY=$SK_PRIMA  DEFAULT_PASSWORD=$DP_PRIMA"

echo "--- rotazione (SECRET_KEY generata sul server; DEFAULT_PASSWORD da stdin se fornita) ---"
# La passphrase arriva da stdin, non dalla riga di comando: i parametri dei processi sono
# leggibili da chiunque sia root sul server, l'input standard no.
#
# Attenzione a NON decidere con [ -s /dev/stdin ]: con ssh lo stdin e' una pipe, che per test -s
# ha dimensione zero, quindi il ramo "vero" non viene mai preso e si scivola sul valore casuale
# senza che nessuno se ne accorga. La scelta la fa QUI, localmente, e la passa come flag.
if [ -n "${PASSFILE:-}" ]; then
  [ -r "$PASSFILE" ] || { echo "  non riesco a leggere $PASSFILE"; exit 1; }
  [ -s "$PASSFILE" ] || { echo "  $PASSFILE e' vuoto"; exit 1; }
  stdin_src="$PASSFILE"; USA_STDIN=1
else
  stdin_src=/dev/null; USA_STDIN=0
fi
# La passphrase vieni portata sul server con una chiamata dedicata che la riceve su stdin e la
# scrive in un file 600 dal nome imprevedibile. Evitiamo sia la riga di comando (visibile nei
# processi a chiunque sia root) sia il doppio uso dello stdin, che e' cio' che ha reso il codice
# precedente illeggibile e rotto.
ND_TMP=""
if [ "$USA_STDIN" = 1 ]; then
  ND_TMP="/root/.nd.$(date +%s).$$"
  $SSH "umask 077; cat > $ND_TMP" < "$PASSFILE" >/dev/null 2>&1
  [ -n "$($SSH "test -s $ND_TMP && echo ok")" ] || { echo "  passphrase non arrivata sul server"; exit 1; }
fi
$SSH "umask 077
  NS=\$(openssl rand -hex 32)
  if [ $USA_STDIN = 1 ]; then
    ND=\$(head -1 $ND_TMP | tr -d '\\r\\n')
    rm -f $ND_TMP
  else
    ND=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
  fi
  if [ \${#ND} -lt 12 ]; then echo '  ERRORE: DEFAULT_PASSWORD troppo corta, annullato'; exit 1; fi
  cp -p $ENVF ${BACKUP}.pre-rotazione
  sed -i \"s|^SECRET_KEY=.*|SECRET_KEY=\$NS|\" $ENVF
  sed -i \"s|^DEFAULT_PASSWORD=.*|DEFAULT_PASSWORD=\$ND|\" $ENVF
  chmod 600 $ENVF
  # Un valore vuoto fa morire il backend all'avvio (RuntimeError in security.py):
  # si verifica QUI, prima di riavviare, per non restare senza sistema.
  if [ -z \"\$(sed -n 's/^SECRET_KEY=//p' $ENVF | head -1)\" ]; then
    cp -p ${BACKUP}.pre-rotazione $ENVF; echo '  ERRORE: SECRET_KEY vuoto, ripristinato'; exit 1
  fi
  if [ -z \"\$(sed -n 's/^DEFAULT_PASSWORD=//p' $ENVF | head -1)\" ]; then
    cp -p ${BACKUP}.pre-rotazione $ENVF; echo '  ERRORE: DEFAULT_PASSWORD vuoto, ripristinato'; exit 1
  fi
  echo '  .env aggiornato e validato'" </dev/null 2>&1 | grep -v Warning | sed 's/^/  /'
[ -n "$ND_TMP" ] && $SSH "rm -f $ND_TMP" >/dev/null 2>&1
[ "${PIPESTATUS[0]}" != "0" ] && { echo "  rotazione fallita, .env ripristinato dal backup"; exit 1; }

SK_DOPO=$(hashof "$(leggi SECRET_KEY $ENVF)")
DP_DOPO=$(hashof "$(leggi DEFAULT_PASSWORD $ENVF)")
ck "SECRET_KEY cambiato"    "$([ "$SK_PRIMA" != "$SK_DOPO" ] && echo si)" "si"
ck "DEFAULT_PASSWORD cambiato" "$([ "$DP_PRIMA" != "$DP_DOPO" ] && echo si)" "si"
# Senza questa asserzione il test passa invano: le prove sotto leggono la default dal .env, quindi
# confrontano il .env con se stesso. Se il valore installato non fosse quello che abbiamo fornito
# (e' esattamente cio' che succedeva col bug di [ -s /dev/stdin ]) nulla lo verrebbe a sapere.
if [ "$USA_STDIN" = 1 ]; then
  VOLUTO=$(head -1 "$PASSFILE" | tr -d '\r\n')
  INSTALLATA=$(leggi DEFAULT_PASSWORD $ENVF)
  ck "la DEFAULT_PASSWORD installata E' quella fornita" \
     "$( [ -n "$VOLUTO" ] && [ "$VOLUTO" = "$INSTALLATA" ] && echo si )" "si"
  ck "  e non e' il ripiego casuale da 20 caratteri" \
     "$([ "${#INSTALLATA}" != 20 ] && echo si)" "si"
fi
echo "  dopo:  SECRET_KEY=$SK_DOPO  DEFAULT_PASSWORD=$DP_DOPO"

echo "--- ricreazione backend (compose legge .env alla CREAZIONE del container) ---"
$SSH "cd /opt/registro_presenze && docker compose $CF up -d >/dev/null 2>&1
  for i in \$(seq 1 60); do
    c=\$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 -X POST http://localhost:8000/auth/token -d 'username=probe@x&password=x' 2>/dev/null)
    [ \"\$c\" = \"401\" ] || [ \"\$c\" = \"429\" ] && { echo \"  backend pronto (\$c) dopo \${i}s\"; exit 0; }
    sleep 1
  done
  echo '  backend non pronto entro 60s'; exit 1" 2>&1 | grep -v Warning | sed 's/^/  /'

ck "backend risponde (401 senza credenziali)" "$(cod "$D/auth/me")" "401"
ck "  nessun 'environment variable is required' nei log" \
   "$($SSH "cd /opt/registro_presenze && docker compose logs --since 2m backend 2>&1 | grep -c 'environment variable is required'" 2>/dev/null | tr -d '\r' | tail -1)" "0"

echo "--- prova che la rotazione abbia avuto effetto ---"
ck "il token coniato PRIMA della rotazione ora e' RIFIUTATO (401)" \
   "$(cod "$D/auth/me" -H "Authorization: Bearer $TOK_OLD")" "401"
TOK_NEW=$(tok "$VM" "$PWVM")
ck "  la password dell'utente funziona ancora (hash in DB intatto)" "$([ -n "$TOK_NEW" ] && echo si)" "si"
ck "  e il token nuovo funziona" "$(cod "$D/auth/me" -H "Authorization: Bearer $TOK_NEW")" "200"

echo "--- il reset NON usa piu' la password condivisa ---"
# Questa era la prova "il reset usa la NUOVA DEFAULT_PASSWORD". Dal 2026-11-16 il reset non usa
# piu' la DEFAULT_PASSWORD: genera una password casuale per quel singolo utente, con cambio
# obbligatorio al primo accesso. Le asserzioni sotto sono il guardaregia contro il ritorno di
# quella scorciatoia, che era il buco per cui chiunque conoscesse la default entrava in qualunque
# account appena resettato.
TOK_ADM=$(tok "$AM" "$PWAM")
ck "login admin -> token" "$([ -n "$TOK_ADM" ] && echo si)" "si"
RESP=$(curl -s -w '\n%{http_code}' --max-time 25 -X PUT "$D/auth/utenti/$UID_VM/reset-password" -H "Authorization: Bearer $TOK_ADM")
CODICE=${RESP##*$'\n'}
R=${RESP%$'\n'*}
ck "reset password utente -> 200" "$CODICE" "200"
TMP=$(echo "$R" | python3 -c "import sys,json;print(json.load(sys.stdin).get('password_temporanea',''))" 2>/dev/null)
ND=$(leggi DEFAULT_PASSWORD $ENVF)
ck "  il reset restituisce una password temporanea propria" "$([ -n "$TMP" ] && echo si)" "si"
ck "  e NON e' la DEFAULT_PASSWORD di questo ambiente" "$([ -n "$ND" ] && [ "$TMP" != "$ND" ] && echo si)" "si"
ck "  e NON e' la vecchia default condivisa" "$([ -n "$DP_VECCHIA" ] && [ "$TMP" != "$DP_VECCHIA" ] && echo si)" "si"
ck "l'utente entra con la temporanea" "$([ -n "$(tok "$VM" "$TMP")" ] && echo si)" "si"
ck "  e NON entra con la DEFAULT_PASSWORD dell'ambiente" "$([ -z "$(tok "$VM" "$ND")" ] && echo si)" "si"
ck "  e NON entra con la vecchia default condivisa" "$([ -z "$(tok "$VM" "$DP_VECCHIA")" ] && echo si)" "si"

echo "--- pulizia ---"
# Si cancellano ANCHE le righe in login_bloccaggi lasciate dai login falliti di questi utenti
# (il confronto con la vecchia default ne genera uno): se restano, il test del blocco login
# le scambia per residui propri e fallisce l'asserzione di pulizia.
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'testrot%';
   DELETE FROM utenti WHERE username IN ('$AM','$VM');" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM utenti WHERE username LIKE 'testrot%')+(SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'testrot%')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
