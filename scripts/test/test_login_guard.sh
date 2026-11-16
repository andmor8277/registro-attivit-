#!/bin/bash
# Verifica il blocco dei tentativi di login per username (core/login_guard.py).
#
# Le richieste partono dal server DEV verso l'app nel container, ciascuna con un
# X-Forwarded-For DIVERSO: riproduce l'attaccante che si attribuisce un IP nuovo a ogni
# tentativo, che e' esattamente il caso in cui il limiter per IP di slowapi non serve a nulla.
# Se il blocco per username funziona, l'attaccante viene fermato comunque.
#
# Si distingue sempre il `detail`: 429 "Rate limit exceeded" e' slowapi (per IP),
# 429 "Troppi tentativi di accesso per questo utente" e' il blocco per username.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
# il probe viaggia accanto a questo script, cosi' il test funziona da qualsiasi cartella
CARTELLA=$(cd "$(dirname "$0")" && pwd)
PROBE=$CARTELLA/login_probe.py
[ -f "$PROBE" ] || { echo "  manca $PROBE: e' il pezzo che esegue il login dentro il container"; exit 1; }
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }

# login "username" "password" -> "CODICE|detail|retry-after", con IP sorgente sempre diverso.
# Nota: -e e' obbligatorio, perche' docker exec NON propaga l'ambiente del client nel container.
login() {
  local u="$1" p="$2"
  $SSH "LK_USER='$u' LK_PASS='$p' LK_XFF=10.77.$((RANDOM%250)).$((RANDOM%250)) \
        docker exec -i -e LK_USER -e LK_PASS -e LK_XFF $BE python -" < "$PROBE" 2>/dev/null | tr -d '\r' | tail -1
}
# come sopra ma con IP fisso (per far scattare, se serve, anche il limiter per IP)
login_ipfisso() {
  local u="$1" p="$2" ip="$3"
  $SSH "LK_USER='$u' LK_PASS='$p' LK_XFF='$ip' \
        docker exec -i -e LK_USER -e LK_PASS -e LK_XFF $BE python -" < "$PROBE" 2>/dev/null | tr -d '\r' | tail -1
}

# come login() ma restituisce solo il codice di stato (il detail e Retry-After non interessano)
login_cod() { login "$1" "$2" | cut -d'|' -f1; }
login_ipfisso_cod() { login_ipfisso "$1" "$2" "$3" | cut -d'|' -f1; }

echo "--- preparazione ---"
PW="S3greta-$(openssl rand -hex 6)"
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }
U1="testlock@example.com"; U2="testlibero@example.com"; U3="testmix@example.com"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'testlock%' OR chiave LIKE 'testlibero%' OR chiave LIKE 'testmix%' OR chiave LIKE 'vecchio%' OR chiave='nonesiste@example.com';
   DELETE FROM utenti WHERE username IN ('$U1','$U2','$U3');" >/dev/null
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('$U1','$HASH',1,0,0,'dirigente'), ('$U2','$HASH',1,0,0,'dirigente'), ('$U3','$HASH',1,0,0,'dirigente');" >/dev/null
ck "utenti di prova creati" "$(q "SELECT count(*) FROM utenti WHERE username IN ('$U1','$U2','$U3')")" "3"

echo "--- 1. il login normale funziona e azzera il contatore ---"
r=$(login "$U1" "$PW"); c="${r%%|*}"
ck "login corretto -> 200" "$c" "200"
ck "  contatore azzerato dopo il successo" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U1'")" "0"

echo "--- 2. dieci tentativi errati DA DIECI IP DIVERSI (il caso che il limiter per IP non ferma) ---"
tutti401=si
for i in $(seq 1 10); do
  r=$(login "$U1" "sbagliata-$i"); c="${r%%|*}"; d="${r#*|}"; d="${d%%|*}"
  if [ "$c" != "401" ]; then tutti401=no; echo "     tentativo $i -> $c / $d"; fi
done
ck "i primi 10 tentativi errati danno 401" "$tutti401" "si"
ck "  nessuno di essi e' il 429 per IP (cambia IP a ogni richiesta)" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U1' AND tentativi=10")" "1"
ck "il contatore in DB e' a 10" "$(q "SELECT tentativi FROM login_bloccaggi WHERE chiave='$U1'")" "10"
ck "l'username e' in blocco" "$(q "SELECT CASE WHEN bloccato_sino IS NULL THEN 'null' ELSE 'attivo' END FROM login_bloccaggi WHERE chiave='$U1'")" "attivo"

echo "--- 3. da bloccato risponde il NOSTRO 429, da qualunque IP ---"
r=$(login "$U1" "$PW"); c="${r%%|*}"; resto="${r#*|}"; d="${resto%%|*}"; ra="${resto##*|}"
ck "dopo la soglia -> 429" "$c" "429"
ck "  il 429 e' del blocco per username, non 'Rate limit exceeded'" "$(echo "$d" | grep -c 'Troppi tentativi')" "1"
r2=$(login "$U1" "$PW"); c2="${r2%%|*}"; resto2="${r2#*|}"; d2="${resto2%%|*}"
ck "  anche con la password GIUSTA resta bloccato" "$c2|$d2" "429|$d"
ck "  c'e' l'header Retry-After" "$([ -n "$ra" ] && echo si || echo no)" "si"
ck "  Retry-After e' un numero di secondi" "$(echo "$ra" | grep -cE '^[0-9]+$')" "1"

echo "--- 4. il blocco e' per username: non colpisce gli altri utenti ne' chi usa lo stesso IP ---"
IPUNO="10.99.1.1"
ck "altro utente, stesso IP gia' usato per gli attacchi -> entra" "$(login_ipfisso_cod "$U2" "$PW" "$IPUNO")" "200"
ck "  l'attaccante non ha bloccato mezza azienda" "$(login_ipfisso_cod "$U3" "$PW" "$IPUNO")" "200"

echo "--- 5. le maiuscole e gli spazi non ingannano il contatore ---"
login "TESTMIX@EXAMPLE.COM" "x" >/dev/null
login "TestMix@Example.com" "x" >/dev/null
login "  testmix@example.com  " "x" >/dev/null
ck "tre scritture diverse dello stesso username = un solo contatore" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U3'")" "1"
ck "  il conteggio e' 3" "$(q "SELECT tentativi FROM login_bloccaggi WHERE chiave='$U3'")" "3"
ck "  nessuna chiave salvata in maiuscolo" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave <> lower(chiave)")" "0"

echo "--- 6. il blocco scade e si pulisce da solo ---"
q "UPDATE login_bloccaggi SET bloccato_sino = now() - interval '1 minute' WHERE chiave='$U1';" >/dev/null
ck "dopo la scadenza il login torna possibile" "$(login_cod "$U1" "$PW")" "200"
ck "  la riga scaduta e' stata rimossa" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U1'")" "0"

echo "--- 7. un username inesistente viene conteggiato allo stesso modo ---"
login "nonesiste@example.com" "x" >/dev/null
ck "  non rivela se l'username esiste" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='nonesiste@example.com'")" "1"

echo "--- 8. se la tabella manca il login NON si rompe (fail-open) ---"
# Senza fail-open ogni accesso risponde 500: verificato. Si rinomina e si RIPRISTINA sempre,
# anche se il test va in errore, altrimenti si lascia il sistema senza login.
$SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -c \
      'ALTER TABLE login_bloccaggi RENAME TO login_bloccaggi_nascosta'" >/dev/null 2>&1
r=$(login "$U2" "$PW"); c="${r%%|*}"
$SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -c \
      'ALTER TABLE login_bloccaggi_nascosta RENAME TO login_bloccaggi'" >/dev/null 2>&1
ck "tabella assente: il login funziona comunque (200, non 500)" "$c" "200"
ck "  la tabella e' stata ripristinata" \
   "$(q "SELECT count(*) FROM information_schema.tables WHERE table_name='login_bloccaggi'")" "1"
n_log=$($SSH "cd /opt/registro_presenze && docker compose logs --since 3m backend 2>&1 | grep -c 'AVVISO login_guard'" 2>/dev/null | tr -d '\r' | tail -1)
ck "  l'avviso e' finito nei log (almeno uno)" "$([ "${n_log:-0}" -ge 1 ] && echo si || echo no)" "si"

echo "--- 9. le righe vecchie non si accumulano all'infinito ---"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'vecchio%';" >/dev/null
q "INSERT INTO login_bloccaggi (chiave, tentativi, primo_tentativo, ultimo_tentativo, bloccato_sino)
   VALUES ('vecchio1@x.local', 3, now() - interval '2 hours', now() - interval '2 hours', NULL),
          ('vecchio2@x.local', 7, now() - interval '3 hours', now() - interval '2 hours', NULL);" >/dev/null
ck "due righe vecchie inserite" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'vecchio%'")" "2"
login_cod "$U1" "sbagliata-pulizia" >/dev/null
ck "  un nuovo tentativo errato le rimuove" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'vecchio%'")" "0"
# un blocco attivo non deve mai essere cancellato dalla pulizia
q "INSERT INTO login_bloccaggi (chiave, tentativi, primo_tentativo, ultimo_tentativo, bloccato_sino)
   VALUES ('vecchio3@x.local', 10, now() - interval '3 hours', now() - interval '2 hours',
           now() + interval '10 minutes');" >/dev/null
login_cod "$U1" "sbagliata-pulizia-2" >/dev/null
ck "  un blocco attivo NON viene mai pulito" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='vecchio3@x.local'")" "1"
ck "  e chi e' in blocco riceve comunque il 429" "$(login_cod 'vecchio3@x.local' 'qualunque')" "429"

echo "--- pulizia ---"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'testlock%' OR chiave LIKE 'testlibero%' OR chiave LIKE 'testmix%' OR chiave LIKE 'vecchio%' OR chiave='nonesiste@example.com';
   DELETE FROM utenti WHERE username IN ('$U1','$U2','$U3');" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM utenti WHERE username LIKE 'testlock%' OR username LIKE 'testlibero%' OR username LIKE 'testmix%')+(SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'test%' OR chiave LIKE 'vecchio%' OR chiave='nonesiste@example.com')")" "0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
