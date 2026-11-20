#!/bin/bash
# Verifica post-deploy su PROD del blocco login per username (core/login_guard.py).
#
# Le richieste partono dal server PROD verso l'app nel container, ciascuna con un
# X-Forwarded-For DIVERSO: riproduce l'attaccante che si attribuisce un IP nuovo a ogni
# tentativo, cioe' il caso in cui il limiter per IP di slowapi non serve a nulla.
# Si distingue sempre il `detail`: 429 "Rate limit exceeded" e' slowapi (per IP),
# 429 "Troppi tentativi di accesso per questo utente" e' il blocco per username.
#
# Crea solo utenti di prova (testlock@..., testlibero@..., testmix@...) e righe in
# login_bloccaggi, e rimuove tutto alla fine. NON tocca dati esistenti.
P=https://thof.crickethouse.mywire.org/api
SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132"
BE="registro_presenze-backend-1"
CARTELLA=$(cd "$(dirname "$0")" && pwd)
PROBE=$CARTELLA/login_probe.py
[ -f "$PROBE" ] || { echo "  manca $PROBE"; exit 1; }
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi }

# docker exec NON propaga l'ambiente del container: servono i -e espliciti
login() {
  local u="$1" p="$2"
  $SSH "LK_USER='$u' LK_PASS='$p' LK_XFF=10.77.$((RANDOM%250)).$((RANDOM%250)) \
        docker exec -i -e LK_USER -e LK_PASS -e LK_XFF $BE python -" < "$PROBE" 2>/dev/null | tr -d '\r' | tail -1
}
login_ipfisso() {
  local u="$1" p="$2" ip="$3"
  $SSH "LK_USER='$u' LK_PASS='$p' LK_XFF='$ip' \
        docker exec -i -e LK_USER -e LK_PASS -e LK_XFF $BE python -" < "$PROBE" 2>/dev/null | tr -d '\r' | tail -1
}
login_cod() { login "$1" "$2" | cut -d'|' -f1; }
login_ipfisso_cod() { login_ipfisso "$1" "$2" "$3" | cut -d'|' -f1; }

echo "--- preparazione (solo utenti di prova) ---"
PW="S3greta-$(openssl rand -hex 6)"
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  impossibile generare l'hash"; exit 1; }
U1="testlock@example.com"; U2="testlibero@example.com"; U3="testmix@example.com"
# Baseline catturata ADESSO, non scritta a mano nel file. La versione precedente aveva
# "registro = 2961" fissato al deploy del 16/11: quattro giorni di presenze reali lo hanno
# portato a 3154 e il test era rosso da solo, senza che fosse rotto niente. Un conteggio assoluto
# di un DB in produzione scade appena qualcuno iscrive un ragazzo.
# Ma renderli solo dinamici sarebbe peggio: un deploy che svuota il DB verrebbe "catturato" gia'
# vuoto e il test sarebbe verde per il motivo sbagliato. Quindi qui si misura l'invarianza, e piu'
# sotto ci sono i minimi assoluti che servono a intercettare proprio lo svuotamento.
PRIMA_UTENTI=$(q "SELECT count(*) FROM utenti")
PRIMA_REGISTRO=$(q "SELECT count(*) FROM registro")
PRIMA_PERSONE=$(q "SELECT count(*) FROM persone")
PRIMA_CAT=$(q "SELECT count(*) FROM categorie")
PRIMA_INF=$(q "SELECT count(*) FROM infortuni")
PRIMA_LISTE=$(q "SELECT count(*) FROM liste_torneo")
echo "  baseline di questa esecuzione: utenti=$PRIMA_UTENTI registro=$PRIMA_REGISTRO persone=$PRIMA_PERSONE categorie=$PRIMA_CAT infortuni=$PRIMA_INF liste=$PRIMA_LISTE"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'testlock%' OR chiave LIKE 'testlibero%' OR chiave LIKE 'testmix%' OR chiave LIKE 'vecchio%' OR chiave='x' OR chiave='nonesiste@example.com';
   DELETE FROM utenti WHERE username IN ('$U1','$U2','$U3');" >/dev/null
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('$U1','$HASH',1,0,0,'dirigente'), ('$U2','$HASH',1,0,0,'dirigente'), ('$U3','$HASH',1,0,0,'dirigente');" >/dev/null
ck "utenti di prova creati" "$(q "SELECT count(*) FROM utenti WHERE username IN ('$U1','$U2','$U3')")" "3"
ck "tabella login_bloccaggi presente" "$(q "SELECT count(*) FROM information_schema.tables WHERE table_name='login_bloccaggi'")" "1"

echo "--- 1. il login normale funziona e azzera il contatore ---"
ck "login corretto -> 200" "$(login_cod "$U1" "$PW")" "200"
ck "  contatore azzerato dopo il successo" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U1'")" "0"

echo "--- 2. dieci tentativi errati DA DIECI IP DIVERSI ---"
tutti401=si
for i in $(seq 1 10); do
  r=$(login "$U1" "sbagliata-$i"); c="${r%%|*}"; resto="${r#*|}"; d="${resto%%|*}"
  if [ "$c" != "401" ]; then tutti401=no; echo "     tentativo $i -> $c / $d"; fi
done
ck "i primi 10 tentativi errati danno 401" "$tutti401" "si"
ck "  nessuno e' il 429 per IP (IP diverso a ogni richiesta)" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U1' AND tentativi=10")" "1"
ck "il contatore in DB e' a 10" "$(q "SELECT tentativi FROM login_bloccaggi WHERE chiave='$U1'")" "10"
ck "l'username e' in blocco" "$(q "SELECT CASE WHEN bloccato_sino IS NULL THEN 'null' ELSE 'attivo' END FROM login_bloccaggi WHERE chiave='$U1'")" "attivo"

echo "--- 3. da bloccato risponde il NOSTRO 429 ---"
r=$(login "$U1" "$PW"); c="${r%%|*}"; resto="${r#*|}"; d="${resto%%|*}"; ra="${resto##*|}"
ck "dopo la soglia -> 429" "$c" "429"
ck "  il 429 e' del blocco per username, non 'Rate limit exceeded'" "$(echo "$d" | grep -c 'Troppi tentativi')" "1"
r2=$(login "$U1" "$PW"); c2="${r2%%|*}"; resto2="${r2#*|}"; d2="${resto2%%|*}"
ck "  anche con la password GIUSTA resta bloccato" "$c2|$d2" "429|$d"
ck "  c'e' l'header Retry-After" "$([ -n "$ra" ] && echo si || echo no)" "si"
ck "  Retry-After e' un numero di secondi" "$(echo "$ra" | grep -cE '^[0-9]+$')" "1"

echo "--- 4. il blocco e' per username, non globale ne' per IP ---"
IPUNO="10.99.1.1"
ck "altro utente, stesso IP degli attacchi -> entra" "$(login_ipfisso_cod "$U2" "$PW" "$IPUNO")" "200"
ck "  un terzo utente dalla stessa postazione entra" "$(login_ipfisso_cod "$U3" "$PW" "$IPUNO")" "200"

echo "--- 5. maiuscole e spazi non ingannano il contatore ---"
login "TESTMIX@EXAMPLE.COM" "x" >/dev/null
login "TestMix@Example.com" "x" >/dev/null
login "  testmix@example.com  " "x" >/dev/null
ck "tre scritture dello stesso username = un solo contatore" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U3'")" "1"
ck "  il conteggio e' 3" "$(q "SELECT tentativi FROM login_bloccaggi WHERE chiave='$U3'")" "3"
ck "  nessuna chiave salvata in maiuscolo" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave <> lower(chiave)")" "0"

echo "--- 6. il blocco scade e si pulisce da solo ---"
q "UPDATE login_bloccaggi SET bloccato_sino = now() - interval '1 minute' WHERE chiave='$U1';" >/dev/null
ck "dopo la scadenza il login torna possibile" "$(login_cod "$U1" "$PW")" "200"
ck "  la riga scaduta e' stata rimossa" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='$U1'")" "0"

echo "--- 7. username inesistente conteggiato allo stesso modo ---"
login "nonesiste@example.com" "x" >/dev/null
ck "  non rivela se l'username esiste" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='nonesiste@example.com'")" "1"

echo "--- 8. le righe vecchie non si accumulano ---"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'vecchio%';" >/dev/null
q "INSERT INTO login_bloccaggi (chiave, tentativi, primo_tentativo, ultimo_tentativo, bloccato_sino)
   VALUES ('vecchio1@x.local', 3, now() - interval '2 hours', now() - interval '2 hours', NULL),
          ('vecchio2@x.local', 7, now() - interval '3 hours', now() - interval '2 hours', NULL),
          ('vecchio3@x.local', 10, now() - interval '3 hours', now() - interval '2 hours', now() + interval '10 minutes');" >/dev/null
ck "tre righe vecchie inserite" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'vecchio%'")" "3"
login_cod "$U1" "sbagliata-pulizia" >/dev/null
ck "  le due non in blocco sono state rimosse" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'vecchio%' AND bloccato_sino IS NULL")" "0"
ck "  quella in blocco NON viene mai pulita" "$(q "SELECT count(*) FROM login_bloccaggi WHERE chiave='vecchio3@x.local'")" "1"
ck "  e riceve il 429" "$(login_cod 'vecchio3@x.local' 'qualunque')" "429"

echo "--- invarianze: sito, docs, utenti esistenti non toccati ---"
for ep in "/" "/login" "/form-iscrizione"; do
  ck "GET $ep" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://thof.crickethouse.mywire.org$ep")" "200"
done
for ep in "/api/docs" "/api/openapi.json" "/api/redoc"; do
  ck "GET $ep bloccato" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://thof.crickethouse.mywire.org$ep")" "404"
done
ck "liste-torneo senza token -> 401" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$P/liste-torneo/3/giocatori")" "401"
ck "gli utenti reali non hanno contatori aperti" "$(q "SELECT count(*) FROM login_bloccaggi lb JOIN utenti u ON u.username = lb.chiave WHERE u.username NOT LIKE 'test%'")" "0"

echo "--- conteggi: il test non deve aver spostato niente ---"
# invarianza rispetto all'inizio di QUESTA esecuzione: prova che il test non ha toccato i dati
ck "registro invariato ($PRIMA_REGISTRO)"   "$(q "SELECT count(*) FROM registro")"   "$PRIMA_REGISTRO"
ck "persone invariate ($PRIMA_PERSONE)"     "$(q "SELECT count(*) FROM persone")"     "$PRIMA_PERSONE"
ck "categorie invariate ($PRIMA_CAT)"       "$(q "SELECT count(*) FROM categorie")"   "$PRIMA_CAT"
ck "infortuni invariati ($PRIMA_INF)"       "$(q "SELECT count(*) FROM infortuni")"   "$PRIMA_INF"
ck "liste torneo invariate ($PRIMA_LISTE)"  "$(q "SELECT count(*) FROM liste_torneo")" "$PRIMA_LISTE"
ck "utenti = baseline + 3 di prova" "$(q "SELECT count(*) FROM utenti")" "$((PRIMA_UTENTI + 3))"
echo "--- minimi assoluti: questi si' che accorgono di un DB svuotato dal deploy ---"
# Sono soglie basse e volutamente sporche: non devono seguire la crescita del DB (altrimenti
# scadono come scadiva il 2961 di prima), devono solo essere molto sopra zero. Un ripristino da
# un dump vuoto, o un deploy che ricrea lo schema, li fa scattare; l'uso normale no.
ckmin() { local n; n=$(q "SELECT count(*) FROM $2"); if [ -n "$n" ] && [ "$n" -ge "$3" ]; then pass=$((pass+1)); echo "  ok   $1 (>= $3, ora $n)"; else fail=$((fail+1)); echo "  FAIL $1 -> $n, sotto la soglia $3"; fi; }
ckmin "registro popolato"        registro     1000
ckmin "persone popolato"         persone      50
ckmin "categorie popolato"       categorie    10
ckmin "utenti presente"          utenti       10
ckmin "almeno una lista torneo"  liste_torneo 1

echo "--- pulizia ---"
q "DELETE FROM login_bloccaggi WHERE chiave LIKE 'testlock%' OR chiave LIKE 'testlibero%' OR chiave LIKE 'testmix%' OR chiave LIKE 'vecchio%' OR chiave='x' OR chiave='nonesiste@example.com';
   DELETE FROM utenti WHERE username IN ('$U1','$U2','$U3');" >/dev/null
ck "nessun residuo di prova" "$(q "SELECT (SELECT count(*) FROM utenti WHERE username LIKE 'testlock%' OR username LIKE 'testlibero%' OR username LIKE 'testmix%')+(SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'test%' OR chiave LIKE 'vecchio%' OR chiave='x' OR chiave='nonesiste@example.com')")" "0"
ck "tutto tornato alla baseline" "$(q "SELECT (SELECT count(*) FROM utenti)||'/'||(SELECT count(*) FROM persone)||'/'||(SELECT count(*) FROM registro)||'/'||(SELECT count(*) FROM login_bloccaggi)")" "$PRIMA_UTENTI/$PRIMA_PERSONE/$PRIMA_REGISTRO/0"

echo
echo "  $pass passati, $fail falliti"
[ $fail -eq 0 ]
