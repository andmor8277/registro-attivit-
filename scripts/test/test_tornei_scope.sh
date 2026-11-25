#!/bin/bash
# Chi vede quali tornei, e perche'.
#
# Perche' esiste. Il 2026-11-25 il titolare ha chiesto l'opposto di cio' che era stato deciso il
# 2026-11-16: «in Convocazioni Tornei i Mister devono vedere solo i tornei della propria categoria,
# non di tutte», con l'eccezione aggiunta subito dopo «anche il profilo segreteria puo' vedere come
# l'admin». La regola sta in `GET /tornei/` (`tornei.py::lista_tornei`) perche' deve essere un
# **permesso**: filtrare solo la pagina lascia l'API intatta, e li' dentro ci sono i calendari di
# tutte le altre squadre. Questo file e' cio' che impedisce a una meta' della regola di essere disfatta
# dall'altra senza che nessuno se ne accorga.
#
# Le cinque cose provate, ciascuna con il suo rosso:
#  1. un mister riceve **solo** i tornei iscritti alle sue categorie, e gli altri no;
#  2. `scope=tutte_categorie` **non** e' un permesso: per un mister da' la stessa lista filtrata
#     (altrimenti l'interruttore "tutte le categorie" della pagina dell'admin sarebbe una scorciatoia
#     utilizzabile da chiunque conosca l'URL);
#  3. `segreteria` e l'admin **senza** categorie assegnate vedono tutti i tornei -- e' la richiesta del
#     titolare, ed e' anche il caso che senza eccezione avrebbe lasciato la segreteria con la pagina
#     vuota (misurato su PROD: `stefaniafiorini8@gmail.com` ha zero righe in utente_categorie);
#  4. un **mister** senza categorie riceve la lista vuota (non un 403, non "tutti"): la pagina glielo
#     deve poter dire, e per dirlo deve avere in mano una risposta DIVERSA da quella dell'admin;
#  5. `scope` sconosciuto da' **400** col dettaglio che nomina i valori ammessi, e la risposta resta
#     una **lista nuda** con i suoi campi: decine di asserzioni fra test_tornei.sh,
#     test_tornei_categorie.sh, test_tornei_sezioni.sh e ui_tornei.cjs la leggono come lista;
#  6. **chi scrive il calendario gare e' lo stesso insieme di chi lo legge** (`get_gestore_gare_torneo`,
#     sezione 8): un mister puo' aggiungere/modificare/eliminare le gare solo dei tornei a cui e' iscritta
#     una categoria che segue. Fino al 25/11/2026 quel gate guardava solo il ruolo, e dopo il filtro sulla
#     lettura lasciava un mister a scrivere su un torneo che non vedeva piu'.
#
# I dati di prova sono creati via API dove la API c'e' (POST /tornei/ crea anche la Lista Tornei
# collegata, quindi il fixture passa dallo stesso percorso dell'app) e via SQL dove serve un conto
# esatto. Tutto marcato __test_scope__ / testscope e rimosso alla fine, trap incluso: un fallimento a
# meta' file non deve lasciare tornei di prova in DEV.
D=http://192.168.178.133:3000/api
SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133"
BE="registro_presenze-backend-1"
q() { $SSH "docker exec -i \$(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -" <<< "$1" | tr -d '\r'; }

pass=0; fail=0
# Due valori vuoti non sono "uguali": sono un test che non ha misurato niente. Con i token vuoti le
# asserzioni sotto confrontavano '' con '' e dicevano ok.
ck() { if [ -z "$2" ] && [ -z "$3" ]; then fail=$((fail+1)); echo "  FAIL $1 -> entrambi vuoti: il test non ha misurato nulla"; return; fi
       if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1 -> '$2' (atteso '$3')"; fi; }

# /auth/token ha @limiter.limit("10/minute") per worker: sette login senza retry diventano rossi per il
# rate limiter e non per la regola che si vuole provare
tok() {
  local out code i
  for i in 1 2 3 4 5; do
    out=$(curl -s -w '\n%{http_code}' --max-time 25 -X POST "$D/auth/token" \
             --data-urlencode "username=$1" --data-urlencode "password=$2")
    code="${out##*$'\n'}"
    if [ "$code" = "429" ]; then sleep 8; continue; fi
    printf '%s' "${out%$'\n'*}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null
    return 0
  done
  echo ""
}
cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$@"; }
det() { curl -s --max-time 25 "$@" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('detail',''))
except Exception: print('')" 2>/dev/null; }
post() { curl -s --max-time 25 -X POST "$D$1" -H "Authorization: Bearer $2" \
          -H 'Content-Type: application/json' -d "$3"; }
# "quali fixture vedo?" -- l'insieme dei nomi dei tornei di prova presenti nella risposta, ordinato e
# separato da virgole. E' l'asserzione giusta qui: "il mister vede 2 tornei" sarebbe vero anche con
# due tornei sbagliati, e "vede solo i suoi" e' esattamente cio' che stiamo provando. I tornei veri di
# DEV entrano nella risposta ma non hanno il prefisso, quindi non contano
fiss() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
if not isinstance(d,list): print('NON-LISTA'); raise SystemExit
print(','.join(sorted(t.get('nome','') for t in d if isinstance(t,dict) and str(t.get('nome','')).startswith('$P'))))" 2>/dev/null; }
# La stessa cosa contata, per i casi in cui l'atteso e' ZERO: `ck` rifiuta il confronto fra due stringhe
# vuote perche' non avrebbe misurato niente, e qui l'atteso vuoto e' legittimo -- serve un modo di
# dirlo che non aggiri quel guard, che e' li' per un motivo giusto
nfix() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
print('' if not isinstance(d,list) else sum(1 for t in d if isinstance(t,dict) and str(t.get('nome','')).startswith('$P')))" 2>/dev/null; }
# la risposta e' una lista nuda? Serve un'asserzione propria perche' il modo piu' naturale di
# "arricchire" questa endpoint -- restituire {tornei: [...], meta: {...}} -- romperebbe tutta la suite
e_lista() { curl -s --max-time 25 "$1" -H "Authorization: Bearer $2" | python3 -c "import sys,json
try: print('si' if isinstance(json.load(sys.stdin),list) else 'no')
except Exception: print('')" 2>/dev/null; }
# gli id di /categorie/mie come insieme ordinato, per confrontarli con gli id dei fixture
mie() { curl -s --max-time 25 "$D/categorie/mie" -H "Authorization: Bearer $1" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
print(','.join(str(x) for x in sorted(d)) if isinstance(d,list) else 'NON-LISTA')" 2>/dev/null; }
# quante categorie riceve GET /categorie/: il CONFRONTO con /mie e' il punto di questa endpoint
n_cat_all() { curl -s --max-time 25 "$D/categorie/" -H "Authorization: Bearer $1" | python3 -c "import sys,json
try: print(len(json.load(sys.stdin)))
except Exception: print('')" 2>/dev/null; }
# e quante ne riceve da /categorie/mie: le due cifre vanno confrontate, non lette da sole
nmie() { curl -s --max-time 25 "$D/categorie/mie" -H "Authorization: Bearer $1" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    print(len(d) if isinstance(d,list) else '')
except Exception: print('')" 2>/dev/null; }

P=__test_scope__
U=testscope

echo "--- preparazione (solo oggetti di prova) ---"
PW=$(openssl rand -hex 12)
HASH=$($SSH "docker exec $BE python -c \"from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('$PW'))\"" 2>/dev/null | tr -d '\r' | tail -1)
[ -z "$HASH" ] && { echo "  FAIL impossibile generare l'hash nel container: senza utenti di prova non"
                     echo "       parte nessuna asserzione"; echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }

pulizia() {
  q "DELETE FROM tornei_gare WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
     DELETE FROM tornei_categorie WHERE torneo_id IN (SELECT id FROM tornei WHERE nome LIKE '$P%');
     DELETE FROM liste_torneo_giocatori WHERE lista_id IN (SELECT id FROM liste_torneo WHERE nome LIKE '$P%');
     DELETE FROM liste_torneo WHERE nome LIKE '$P%';
     DELETE FROM tornei WHERE nome LIKE '$P%';
     DELETE FROM utente_categorie WHERE categoria_id IN (SELECT id FROM categorie WHERE nome LIKE '$P%');
     DELETE FROM categorie WHERE nome LIKE '$P%';
     DELETE FROM utenti WHERE username LIKE '$U%';" >/dev/null
}
pulizia
trap pulizia EXIT

BASE_TORNEI=$(q "SELECT count(*) FROM tornei")
BASE_UC=$(q "SELECT count(*) FROM utente_categorie")
echo "  baseline: tornei=$BASE_TORNEI utente_categorie=$BASE_UC"

# Tre categorie, anni diversi. La terza non viene assegnata a nessuno: serve a provare che una
# categoria che non e' "mia" non apre nessuna sezione, e che un torneo iscritto solo a lei e'
# invisibile a tutti i fixture
q "INSERT INTO categorie (societa_id,nome,anno,is_archiviata) VALUES
     (1,'$P-a',1901,0),(1,'$P-b',1902,0),(1,'$P-c',1903,0);" >/dev/null
CA=$(q "SELECT id FROM categorie WHERE nome='$P-a'")
CB=$(q "SELECT id FROM categorie WHERE nome='$P-b'")
CC=$(q "SELECT id FROM categorie WHERE nome='$P-c'")
echo "  categorie: a=$CA b=$CB c=$CC"

# Sette account, stessa password casuale. Le assegnazioni si fanno qui, in SQL, perche' PUT
# /categorie/{id}/utenti vuole un admin e soprattutto perche' il caso "nessuna categoria" deve essere
# **l'assenza** di righe, non una riga rimossa: scriverlo in SQL rende impossibile il "forse gliene
# e' rimasta una dal test di prima"
q "INSERT INTO utenti (username,password_hash,societa_id,is_admin,is_super_admin,ruolo)
   VALUES ('${U}_adm','$HASH',1,1,0,NULL),
          ('${U}_mia','$HASH',1,0,0,'mister'),
          ('${U}_mib','$HASH',1,0,0,'mister'),
          ('${U}_mzero','$HASH',1,0,0,'mister'),
          ('${U}_segr','$HASH',1,0,0,'segreteria'),
          ('${U}_dir','$HASH',1,0,0,'dirigente'),
          ('${U}_adm2','$HASH',2,1,0,NULL);" >/dev/null
q "INSERT INTO utente_categorie (utente_id,categoria_id)
   SELECT id, $CA FROM utenti WHERE username='${U}_mia'
   UNION ALL SELECT id, $CB FROM utenti WHERE username='${U}_mib'
   UNION ALL SELECT id, $CA FROM utenti WHERE username='${U}_dir';" >/dev/null

TADM=$(tok "${U}_adm" "$PW"); TMIA=$(tok "${U}_mia" "$PW"); TMIB=$(tok "${U}_mib" "$PW")
TMZE=$(tok "${U}_mzero" "$PW"); TSEGR=$(tok "${U}_segr" "$PW"); TDIR=$(tok "${U}_dir" "$PW")
TADM2=$(tok "${U}_adm2" "$PW")
for pair in "admin:$TADM" "mister-a:$TMIA" "mister-b:$TMIB" "mister-zero:$TMZE" \
            "segreteria:$TSEGR" "dirigente:$TDIR" "admin-soc2:$TADM2"; do
  if [ -z "${pair##*:}" ]; then
    echo "  FAIL login ${pair%%:*} fallito: i 7 login sono il prerequisito di tutto il resto, mi fermo"
    echo "       (proseguire con un token vuoto vuol dire confrontare stringhe vuote fra loro e dire ok)"
    echo "  0 passati, 1 falliti (prerequisiti)"; exit 1
  fi
done
for pair in "admin:$TADM" "mister-a:$TMIA" "mister-b:$TMIB" "mister-zero:$TMZE" \
            "segreteria:$TSEGR" "dirigente:$TDIR" "admin-soc2:$TADM2"; do
  ck "login ${pair%%:*}" "$([ -n "${pair##*:}" ] && echo si)" "si"
done
# L'assegnazione deve esserci per davvero: se l'INSERT sopra non ha colpito (username sbagliato,
# vincolo mancante) ogni asserzione sul filtro sarebbe verde per il motivo sbagliato -- un mister-a
# senza categorie vedrebbe "tutti", perche' il ramo 'nessuna categoria' e' proprio quello non filtrato
ck "mister-a ha la categoria a" "$(q "SELECT count(*) FROM utente_categorie uc JOIN utenti u ON u.id=uc.utente_id WHERE u.username='${U}_mia' AND uc.categoria_id=$CA")" "1"
ck "mister-b ha la categoria b" "$(q "SELECT count(*) FROM utente_categorie uc JOIN utenti u ON u.id=uc.utente_id WHERE u.username='${U}_mib' AND uc.categoria_id=$CB")" "1"
ck "dirigente ha la categoria a" "$(q "SELECT count(*) FROM utente_categorie uc JOIN utenti u ON u.id=uc.utente_id WHERE u.username='${U}_dir' AND uc.categoria_id=$CA")" "1"
ck "mister-zero non ha categorie" "$(q "SELECT count(*) FROM utente_categorie uc JOIN utenti u ON u.id=uc.utente_id WHERE u.username='${U}_mzero'")" "0"
ck "segreteria non ha categorie (e' il caso del titolare)" "$(q "SELECT count(*) FROM utente_categorie uc JOIN utenti u ON u.id=uc.utente_id WHERE u.username='${U}_segr'")" "0"
ck "admin non ha categorie" "$(q "SELECT count(*) FROM utente_categorie uc JOIN utenti u ON u.id=uc.utente_id WHERE u.username='${U}_adm'")" "0"

# I quattro tornei si fanno via API: POST /tornei/ crea anche la Lista Tornei collegata, quindi il
# fixture passa dallo stesso percorso dell'applicazione invece che da un'ipotesi di SQL
post /tornei/ "$TADM" "{\"nome\":\"$P-solo-a\",\"categorie_id\":[$CA],\"data_inizio\":\"2026-12-20\",\"data_fine\":\"2026-12-22\"}" >/dev/null
post /tornei/ "$TADM" "{\"nome\":\"$P-solo-b\",\"categorie_id\":[$CB],\"data_inizio\":\"2026-12-21\",\"data_fine\":\"2026-12-23\"}" >/dev/null
post /tornei/ "$TADM" "{\"nome\":\"$P-a-e-b\",\"categorie_id\":[$CA,$CB],\"data_inizio\":\"2026-12-22\",\"data_fine\":\"2026-12-24\"}" >/dev/null
# Il quarto -- il torneo SENZA categorie iscritte -- non puo' nascere dall'API: `POST /tornei/` passa da
# `_valida`, che risponde 400 "Seleziona almeno una categoria" (e non e' dato per scontato, c'e'
# l'asserzione qui sotto). Va quindi scritto in SQL.
#
# Nota di data: fino al 25/11/2026 l'INSERT diretto **non bastava**, perche' `tornei.categoria_id` aveva
# il NOT NULL su DEV e su PROD anche se il modello dichiarava `nullable=True` -- la migrazione promessa
# dal commento "Nullable dal 2026-11-20" non esisteva. Ora esiste (`DROP NOT NULL` in
# backend/app/migrations/run.py, misurato su `information_schema.columns.is_nullable`), quindi il blocco
# che resta e' solo quello dell'API.
#
# La colonna legacy qui viene comunque lasciata **popolata** (sulla categoria di mister-b), perche' e'
# cosi' che questo fixture diventa tagliente: il filtro legge `tornei_categorie`, e un torneo che la
# colonna dice "tuo" mentre le iscrizioni dicono "nessuno" e' l'unico caso che distingue le due fonti.
# Se qualcuno riportasse il filtro sulla colonna -- costa meno, e il modello la dice nullable -- mister-b
# si ritroverebbe un torneo a cui la sua squadra non e' iscritta
q "INSERT INTO tornei (societa_id,categoria_id,nome,data_inizio,data_fine)
   VALUES (1,$CB,'$P-senza-cat','2026-12-23','2026-12-25');" >/dev/null
ORFANO_DB=$(q "SELECT count(*) FROM tornei WHERE nome='$P-senza-cat'")
[ "$ORFANO_DB" = "1" ] || echo "  ATTENZIONE: l'insert diretto dell'orfano non ha colpito (conta=$ORFANO_DB): le asserzioni sotto sono rosse per questo, non per il filtro"
SOLA="$P-solo-a"; SOLOB="$P-solo-b"; AEB="$P-a-e-b"; SENZ="$P-senza-cat"
# Gli insiemi attesi sono gia' ordinati come `fiss` li restituisce (sorted): "solo-a,a-e-b" sarebbe
# rosso per l'ordine delle stringhe e non per la regola, che e' il modo peggiore di leggere un fallimento
MIA="$P-a-e-b,$SOLA"; MIB="$P-a-e-b,$SOLOB"; TUTTI="$P-a-e-b,$SENZ,$SOLA,$SOLOB"
ck "i quattro tornei di prova esistono" "$(q "SELECT count(*) FROM tornei WHERE nome LIKE '$P%'")" "4"
ck "le iscrizioni tornei_categorie sono 4 (1+1+2+0)" "$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id WHERE t.nome LIKE '$P%'")" "4"
ck "il torneo senza categorie non ha iscrizioni" "$(q "SELECT count(*) FROM tornei_categorie tc JOIN tornei t ON t.id=tc.torneo_id WHERE t.nome='$P-senza-cat'")" "0"
ck "POST /tornei/ senza categorie -> 400 (un orfano non nasce dall'app, e non nasce nemmeno per errore)" \
   "$(cod "$D/tornei/" -X POST -H "Authorization: Bearer $TADM" -H 'Content-Type: application/json' \
        -d "{\"nome\":\"$P-orfano\",\"categorie_id\":[]}")" "400"

echo
echo "--- 1. un mister vede SOLO i tornei delle sue categorie ---"
ck "mister-a vede i suoi due tornei, e nessun altro" "$(fiss "$D/tornei/" "$TMIA")" "$MIA"
ck "mister-b vede i suoi due tornei, e nessun altro" "$(fiss "$D/tornei/" "$TMIB")" "$MIB"
ck "nessun mister vede il torneo senza categorie (2+2, non 3)" \
   "$(nfix "$D/tornei/" "$TMIA"),$(nfix "$D/tornei/" "$TMIB")" "2,2"
# L'asserzione piu' tagliente del file, e quella che vale di piu' fra sei mesi. L'orfano ha la colonna
# legacy `tornei.categoria_id` puntata sulla categoria **di mister-b**: se qualcuno, "semplificando",
# riportasse il filtro su quella colonna -- costa meno, e il modello la dice addirittura nullable --
# mister-b si ritroverebbe un torneo a cui la sua squadra non e' iscritta. Che qui sia fuori e' cio'
# che tiene ferma la fonte di verita' su `tornei_categorie`
ck "e l'orfano ha la colonna legacy sulla categoria di mister-b (senza questo, l'asserzione sotto non prova niente)" \
   "$(q "SELECT categoria_id FROM tornei WHERE nome='$P-senza-cat'")" "$CB"
ck "l'orfano non lo vede nemmeno mister-b: il filtro legge tornei_categorie, non tornei.categoria_id" \
   "$(fiss "$D/tornei/" "$TMIB")" "$MIB"
ck "i due mister non vedono la stessa lista (il filtro non e' un no-op)" \
   "$([ "$(fiss "$D/tornei/" "$TMIA")" != "$(fiss "$D/tornei/" "$TMIB")" ] && echo si)" "si"
ck "scope=mie_categorie esplicito da' lo stesso risultato del default" \
   "$(fiss "$D/tornei/?scope=mie_categorie" "$TMIA")" "$(fiss "$D/tornei/" "$TMIA")"
ck "scope tollerante a maiuscole e spazi (' MIE_CATEGORIE ')" \
   "$(fiss "$D/tornei/?scope=%20MIE_CATEGORIE%20" "$TMIA")" "$MIA"
ck "scope vuoto trattato come default, non come errore" \
   "$(cod "$D/tornei/?scope=" -H "Authorization: Bearer $TMIA")" "200"

echo
echo "--- 2. scope=tutte_categorie NON e' un permesso ---"
# E' l'asserzione che tiene chiusa la porta: l'interruttore a schermo esiste solo per chi puo'
# vederli tutti, ma il parametro viaggia nell'URL e chiunque puo' scriverlo
ck "mister-a con scope=tutte_categorie vede comunque solo i suoi" \
   "$(fiss "$D/tornei/?scope=tutte_categorie" "$TMIA")" "$MIA"
ck "e il torneo dell'altra categoria resta fuori (2, non 4)" \
   "$(nfix "$D/tornei/?scope=tutte_categorie" "$TMIA")" "2"
ck "dirigente con la categoria a: filtrato come un mister (il filtro non e' solo per i mister)" \
   "$(fiss "$D/tornei/" "$TDIR")" "$MIA"
ck "dirigente con scope=tutte_categorie: ancora filtrato" \
   "$(fiss "$D/tornei/?scope=tutte_categorie" "$TDIR")" "$MIA"
ck "scope sconosciuto -> 400" "$(cod "$D/tornei/?scope=tutte" -H "Authorization: Bearer $TMIA")" "400"
ck "il 400 nomina 'mie_categorie'" \
   "$(det "$D/tornei/?scope=tutte" -H "Authorization: Bearer $TMIA" | grep -c mie_categorie)" "1"
ck "il 400 nomina 'tutte_categorie'" \
   "$(det "$D/tornei/?scope=tutte" -H "Authorization: Bearer $TMIA" | grep -c tutte_categorie)" "1"
ck "scope sconosciuto -> 400 anche per l'admin (e' la forma del parametro, non il ruolo)" \
   "$(cod "$D/tornei/?scope=xxx" -H "Authorization: Bearer $TADM")" "400"

echo
echo "--- 3. segreteria vede come l'admin (la richiesta del titolare) ---"
ck "admin senza categorie vede tutti e quattro i tornei" "$(fiss "$D/tornei/" "$TADM")" "$TUTTI"
ck "SEGRETARIA senza categorie vede tutti e quattro i tornei" "$(fiss "$D/tornei/" "$TSEGR")" "$TUTTI"
ck "admin e segreteria vedono la stessa lista" \
   "$(fiss "$D/tornei/" "$TSEGR")" "$(fiss "$D/tornei/" "$TADM")"
ck "segreteria con scope=tutte_categorie: stessa lista, nessun errore" \
   "$(fiss "$D/tornei/?scope=tutte_categorie" "$TSEGR")" "$TUTTI"
ck "admin con scope=tutte_categorie: stessa lista, nessun errore" \
   "$(fiss "$D/tornei/?scope=tutte_categorie" "$TADM")" "$TUTTI"
# "vedere come l'admin" e' LETTURA. Se qualcuno fonde i due gate -- l'errore che ui_convocazioni_torneo
# esiste per beccare dall'altra parte -- questo e' il rosso che lo dice qui
ck "segreteria NON puo' creare un torneo (leggere come l'admin non e' scrivere come l'admin)" \
   "$(cod "$D/tornei/" -X POST -H "Authorization: Bearer $TSEGR" -H 'Content-Type: application/json' \
        -d "{\"nome\":\"$P-abuso\",\"categorie_id\":[$CA]}")" "403"
ck "e il torneo di abuso non e' stato creato" "$(q "SELECT count(*) FROM tornei WHERE nome='$P-abuso'")" "0"

echo
echo "--- 4. un mister senza categorie: lista vuota, non 403 e non 'tutti' ---"
ck "mister-zero -> 200 (non 403: non ha fatto niente di proibito)" \
   "$(cod "$D/tornei/" -H "Authorization: Bearer $TMZE")" "200"
ck "mister-zero -> zero tornei" "$(nfix "$D/tornei/" "$TMZE")" "0"
ck "e il corpo della risposta e' proprio [] (non un oggetto)" \
   "$(curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $TMZE")" "[]"
ck "mister-zero con scope=tutte_categorie: sempre vuoto (non e' la sua scorciatoia)" \
   "$(nfix "$D/tornei/?scope=tutte_categorie" "$TMZE")" "0"
ck "la lista del mister e DIVERSA da quella dell'admin (la pagina puo' distinguerli)" \
   "$(nfix "$D/tornei/" "$TMZE"),$(nfix "$D/tornei/" "$TADM")" "0,4"

echo
echo "--- 5. il filtro per categoria si SOMMA agli altri filtri, non li sostituisce ---"
# Se il ramo nuovo sostituisse la query invece di filtrarla, i filtri data e societa' smetterebbero di
# valere solo per chi e' filtrato: il tipo di regressione che a schermo non si vede
ck "mister-a nel periodo dei tornei: li vede" \
   "$(fiss "$D/tornei/?da=2026-12-01&a=2026-12-31" "$TMIA")" "$MIA"
ck "mister-a fuori periodo: nessuno" "$(nfix "$D/tornei/?da=2027-06-01&a=2027-06-30" "$TMIA")" "0"
ck "admin fuori periodo: nessuno (il periodo vale anche per chi vede tutti)" \
   "$(nfix "$D/tornei/?da=2027-06-01&a=2027-06-30" "$TADM")" "0"
ck "admin con scope=tutte_categorie fuori periodo: comunque nessuno" \
   "$(nfix "$D/tornei/?scope=tutte_categorie&da=2027-06-01&a=2027-06-30" "$TADM")" "0"
ck "admin della societa' 2 non vede i tornei della societa' 1" "$(nfix "$D/tornei/" "$TADM2")" "0"

echo
echo "--- 6. GET /categorie/mie: le categorie di CHI GUARDA, senza eccezioni di ruolo ---"
# Esiste perche' GET /categorie/ ha un'eccezione di ruolo (admin e segreteria ricevono TUTTE le
# categorie della societa'). Se qualcuno "semplifica" la pagina facendola tornare a getCategorie, la
# whitelist delle sezioni per l'admin diventa 'tutte' e un torneo iscritto a piu' categorie ricompare
# dove non deve: queste due asserzioni sono l'unica cosa che lo nota
ck "mister-a: solo la categoria a" "$(mie "$TMIA")" "$CA"
ck "mister-b: solo la categoria b" "$(mie "$TMIB")" "$CB"
ck "mister-zero: nessuna" "$(curl -s --max-time 25 "$D/categorie/mie" -H "Authorization: Bearer $TMZE")" "[]"
ck "admin senza categorie: nessuna in /mie" "$(curl -s --max-time 25 "$D/categorie/mie" -H "Authorization: Bearer $TADM")" "[]"
ck "segreteria senza categorie: nessuna in /mie" "$(curl -s --max-time 25 "$D/categorie/mie" -H "Authorization: Bearer $TSEGR")" "[]"
ck "admin: GET /categorie/ gli da' PIU' categorie di quante ne abbia sue (per questo /mie esiste)" \
   "$(awk -v a="$(n_cat_all "$TADM")" -v b="$(nmie "$TADM")" 'BEGIN{ if (a==""||b=="") print ""; else print (a+0>b+0)?"si":"no" }')" "si"
ck "segreteria: GET /categorie/ le da' PIU' categorie di quante ne abbia sue" \
   "$(awk -v a="$(n_cat_all "$TSEGR")" -v b="$(nmie "$TSEGR")" 'BEGIN{ if (a==""||b=="") print ""; else print (a+0>b+0)?"si":"no" }')" "si"
ck "la categoria c (non assegnata a nessuno) non esce a nessun fixture" \
   "$(mie "$TMIA")$(mie "$TMIB")$(mie "$TADM")$(mie "$TSEGR")" "$CA$CB"
ck "GET /categorie/mie senza token -> 401" "$(cod "$D/categorie/mie")" "401"
ck "GET /categorie/mie restituisce una lista di interi" \
   "$(curl -s --max-time 25 "$D/categorie/mie" -H "Authorization: Bearer $TMIA" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    print('si' if isinstance(d,list) and all(isinstance(x,int) for x in d) else 'no')
except Exception: print('')")" "si"

echo
echo "--- 7. la forma della risposta non cambia (la leggono in decine) ---"
ck "GET /tornei/ e' una lista nuda, non {tornei, meta}" "$(e_lista "$D/tornei/" "$TMIA")" "si"
ck "GET /tornei/?scope=tutte_categorie e' una lista nuda" "$(e_lista "$D/tornei/?scope=tutte_categorie" "$TADM")" "si"
ck "un elemento porta ancora id e nome" \
   "$(curl -s --max-time 25 "$D/tornei/" -H "Authorization: Bearer $TMIA" | python3 -c "import sys,json
d=json.load(sys.stdin)
t=d[0] if d else {}
print('si' if 'id' in t and 'nome' in t else 'no')")" "si"
ck "il dettaglio di un torneo resta raggiungibile al mister che lo vede" \
   "$(cod "$D/tornei/$(q "SELECT id FROM tornei WHERE nome='$P-solo-a'")" -H "Authorization: Bearer $TMIA")" "200"

echo
echo "--- 8. chi SCRIVE il calendario gare: lo STESSO criterio della lettura ---"
# Perche' questa sezione sta qui e non in test_tornei.sh: il permesso di scrivere e' stato stretto il
# 25/11/2025 con lo stesso criterio di `GET /tornei/`, e le due meta' devono essere provate con le stesse
# fixture. Fino a quel giorno `get_gestore_gare_torneo` guardava solo il ruolo: un mister poteva
# aggiungere, riscrivere o cancellare le gare di un torneo che, dopo il filtro sulla lettura, non vedeva
# piu'. Un permesso di scrivere piu' largo del permesso di leggere e' la stessa classe di buco chiuso il
# 23/11 sulle convocazioni del weekend.
#
# Le fixture sono quelle sopra: mister-a segue la categoria a, mister-b la b, il torneo `$P-a-e-b` le ha
# entrambe, l'orfano `$P-senza-cat` non ne ha nessuna ma ha la colonna legacy sulla b.
TSOLA=$(q "SELECT id FROM tornei WHERE nome='$SOLA'")
TSOLOB=$(q "SELECT id FROM tornei WHERE nome='$SOLOB'")
TAEB=$(q "SELECT id FROM tornei WHERE nome='$AEB'")
TORF=$(q "SELECT id FROM tornei WHERE nome='$SENZ'")
for pair in "solo-a:$TSOLA" "solo-b:$TSOLOB" "a-e-b:$TAEB" "senza-cat:$TORF"; do
  [ -z "${pair##*:}" ] && { echo "  FAIL prerequisito: torneo ${pair%%:*} non trovato (\$$pair)"; \
                            echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
done
# Un torneo dell'ALTRA societa', creato via SQL perche' l'API di adm2 non avrebbe una categoria sua da
# iscrivere. Serve per distinguere i due 403: quello di tenant e quello di categoria sono due risposte
# diverse, e se il gate le confondesse il messaggio lo dice. **Nasce qui e non in `preparazione`** di
# proposito: `nfix` conta i tornei di prova per prefisso, e se questo esistesse gia' a sezione 5
# l'asserzione "admin della societa' 2 non vede i tornei della societa' 1" direbbe 1 invece di 0 -- un
# rosso che accusa il filtro di societa' per colpa di un fixture
q "INSERT INTO tornei (societa_id,categoria_id,nome,data_inizio,data_fine)
   VALUES (2,$CA,'$P-altra-soc','2026-12-26','2026-12-28');" >/dev/null
TALT=$(q "SELECT id FROM tornei WHERE nome='$P-altra-soc'")
[ -n "$TALT" ] || { echo "  FAIL prerequisito: il torneo dell'altra societa' non e' stato creato"; \
                    echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
GARE_PRIMA=$(q "SELECT count(*) FROM tornei_gare tg JOIN tornei t ON t.id=tg.torneo_id WHERE t.nome LIKE '$P%'")

gara_cod() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST "$D/tornei/$1/gare" \
               -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
gara_put() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X PUT "$D/tornei/$1/gare/$4" \
               -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
# L'id della gara e' il TERZO argomento, non il quarto come in gara_put (che ha il json in mezzo): un
# `$4` vuoto qui mandava `.../gare/` e FastAPI rispondeva 307, che non e' nessun verdetto sul gate
gara_del() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X DELETE "$D/tornei/$1/gare/$3" \
               -H "Authorization: Bearer $2"; }
gara_det() { curl -s --max-time 25 -X POST "$D/tornei/$1/gare" \
               -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3" \
             | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('detail',''))
except Exception: print('')" 2>/dev/null; }
# Quante gare di prova con un certo avversario esistono in un torneo. Non basta il codice HTTP: un 403
# che pero' scrive la riga e' il difetto, e il codice da solo non lo vede
gare_con() { q "SELECT count(*) FROM tornei_gare tg JOIN tornei t ON t.id=tg.torneo_id
                WHERE t.id=$1 AND tg.avversario='$2'"; }

echo "   (il proprio torneo: si puo')"
ck "mister-a aggiunge una gara al torneo della sua categoria -> 200" \
   "$(gara_cod $TSOLA "$TMIA" "{\"avversario\":\"${P}GaraDiA\",\"data\":\"2026-12-20\",\"ora\":\"15:00\"}")" "200"
ck "  e la riga esiste davvero nel DB" "$(gare_con $TSOLA "${P}GaraDiA")" "1"
ck "mister-b aggiunge una gara al torneo della sua categoria -> 200" \
   "$(gara_cod $TSOLOB "$TMIB" "{\"avversario\":\"${P}GaraDiB\",\"data\":\"2026-12-21\",\"ora\":\"15:00\"}")" "200"
ck "  e la riga esiste davvero nel DB" "$(gare_con $TSOLOB "${P}GaraDiB")" "1"
# "almeno una delle iscritte", non "tutte": chi segue una delle due categorie di un torneo condiviso quel
# torneo lo vede e lo cura. Stringere a "tutte" lascerebbe senza calendario i tornei a piu' categorie
ck "mister-a aggiunge una gara al torneo condiviso (seguendone UNA categoria su due) -> 200" \
   "$(gara_cod $TAEB "$TMIA" "{\"avversario\":\"${P}GaraAEB\",\"categoria_id\":$CA,\"data\":\"2026-12-22\"}")" "200"
ck "mister-b puo' farlo sullo stesso torneo -> 200" \
   "$(gara_cod $TAEB "$TMIB" "{\"avversario\":\"${P}GaraAEBb\",\"categoria_id\":$CB,\"data\":\"2026-12-23\"}")" "200"

echo "   (il torneo di un'altra categoria: no)"
ck "mister-a aggiunge una gara al torneo di mister-b -> 403" \
   "$(gara_cod $TSOLOB "$TMIA" "{\"avversario\":\"${P}Abusiva\",\"data\":\"2026-12-21\"}")" "403"
ck "  e la gara abusiva NON e' nata (un 403 che scrive comunque e' il difetto)" \
   "$(gare_con $TSOLOB "${P}Abusiva")" "0"
ck "  e il 403 nomina il motivo (nessuna delle TUE categorie e' iscritta)" \
   "$(gara_det $TSOLOB "$TMIA" "{\"avversario\":\"${P}Abusiva2\"}" | grep -ci 'non ha nessuna delle tue categorie')" "1"
ck "mister-b non puo' scrivere sul torneo di mister-a -> 403" \
   "$(gara_cod $TSOLA "$TMIB" "{\"avversario\":\"${P}AbusivaB\",\"data\":\"2026-12-20\"}")" "403"
# Modifica ed eliminazione seguono lo stesso gate: sono le due che cancellano il lavoro di un altro
GARA_B=$(q "SELECT tg.id FROM tornei_gare tg JOIN tornei t ON t.id=tg.torneo_id WHERE t.id=$TSOLOB AND tg.avversario='${P}GaraDiB'")
[ -z "$GARA_B" ] && { echo "  FAIL prerequisito: la gara di mister-b non c'e' (id vuoto), i due casi sotto non misurerebbero niente"
                      echo "  0 passati, 1 falliti (prerequisiti)"; exit 1; }
ck "mister-a non puo' MODIFICARE la gara di mister-b -> 403" \
   "$(gara_put $TSOLOB "$TMIA" "{\"avversario\":\"${P}Manomessa\",\"data\":\"2026-12-21\"}" $GARA_B)" "403"
ck "  e l'avversario della gara e' rimasto quello di prima" \
   "$(q "SELECT avversario FROM tornei_gare WHERE id=$GARA_B")" "${P}GaraDiB"
ck "mister-a non puo' ELIMINARE la gara di mister-b -> 403" \
   "$(gara_del $TSOLOB "$TMIA" $GARA_B)" "403"
ck "  e la gara e' ancora li'" "$(q "SELECT count(*) FROM tornei_gare WHERE id=$GARA_B")" "1"

echo "   (la fonte di verita' sono le iscrizioni, non la colonna legacy)"
# Gemella, lato scrittura, dell'asserzione sull'orfano di sezione 1. L'orfano ha tornei.categoria_id = b:
# se il gate leggesse quella colonna, mister-b riuscirebbe a scrivere su un torneo a cui la sua squadra
# non e' iscritta
ck "mister-b non puo' scrivere sull'orfano, anche se la colonna legacy dice 'b' -> 403" \
   "$(gara_cod $TORF "$TMIB" "{\"avversario\":\"${P}Orfana\",\"data\":\"2026-12-24\"}")" "403"
# E il contrario, che e' meta' della prova: qui la colonna legacy dice 'b' ma l'iscrizione dice 'a'. Senza
# questo secondo verso, un gate che leggesse la colonna sarebbe verde su meta' dei casi
q "UPDATE tornei SET categoria_id=$CB WHERE id=$TSOLA;" >/dev/null
ck "  (precondizione: ora la colonna legacy di solo-a dice 'b', l'iscrizione dice 'a')" \
   "$(q "SELECT categoria_id FROM tornei WHERE id=$TSOLA")" "$CB"
ck "mister-a puo' ancora scrivere su solo-a: il gate legge tornei_categorie -> 200" \
   "$(gara_cod $TSOLA "$TMIA" "{\"avversario\":\"${P}GaraDiA2\",\"data\":\"2026-12-20\",\"ora\":\"16:00\"}")" "200"
ck "mister-b NO, anche se la colonna legacy ora e' la sua -> 403" \
   "$(gara_cod $TSOLA "$TMIB" "{\"avversario\":\"${P}AbusivaB2\",\"data\":\"2026-12-20\"}")" "403"

echo "   (i ruoli che non guidano le squadre restano fuori, e i verdetti hanno un ordine)"
ck "mister-zero (nessuna categoria) -> 403" \
   "$(gara_cod $TSOLA "$TMZE" "{\"avversario\":\"${P}Zero\",\"data\":\"2026-12-20\"}")" "403"
# `-i` perche' il testo inizia con la maiuscola ("Non sei assegnato..."): un grep case-sensitive su una
# frase che inizia minuscola dice 0 e sembra che il messaggio non nomini il motivo, quando e' il grep
ck "  e il messaggio nomina LE CATEGORIE MANCANTI a lui, non il torneo" \
   "$(gara_det $TSOLA "$TMZE" "{\"avversario\":\"${P}Zero2\"}" | grep -ci 'non sei assegnato a nessuna categoria')" "1"
# Le due risposte devono essere DIVERSE, perche' a schermo si somigliano e la seconda ha una soluzione
# diversa (farsi iscrivere al torneo) dalla prima (farsi assegnare una categoria). Se il gate tornasse un
# solo messaggio generico, questa e' l'asserzione che lo nota
ck "  e NON e' lo stesso messaggio di mister-a (due verdetti diversi, non uno generico)" \
   "$(gara_det $TSOLA "$TMZE" "{\"avversario\":\"${P}Zero3\"}" | grep -ci 'non ha nessuna delle tue categorie')" "0"
ck "  e nessuna gara di mister-zero e' nata" \
   "$(gare_con $TSOLA "${P}Zero")" "0"
ck "dirigente CON la categoria a -> 403 (legge i tornei della sua categoria, non li scrive)" \
   "$(gara_cod $TSOLA "$TDIR" "{\"avversario\":\"${P}Dir\",\"data\":\"2026-12-20\"}")" "403"
ck "segreteria -> 403: RUOLI_VEDONO_TUTTI_I_TORNEI e' un elenco di LETTURA" \
   "$(gara_cod $TSOLA "$TSEGR" "{\"avversario\":\"${P}Segr\",\"data\":\"2026-12-20\"}")" "403"
ck "  e nessuna gara di dirigente o segreteria e' nata" \
   "$(gare_con $TSOLA "${P}Dir"),$(gare_con $TSOLA "${P}Segr")" "0,0"
ck "admin puo' scrivere su entrambi i tornei -> 200,200" \
   "$(gara_cod $TSOLA "$TADM" "{\"avversario\":\"${P}GaraAdm\",\"data\":\"2026-12-20\"}"),$(gara_cod $TSOLOB "$TADM" "{\"avversario\":\"${P}GaraAdm2\",\"data\":\"2026-12-21\"}")" \
   "200,200"
ck "admin della societa' 2 -> 403 (il tenant copre anche la scrittura)" \
   "$(gara_cod $TSOLA "$TADM2" "{\"avversario\":\"${P}Intrusa\",\"data\":\"2026-12-20\"}")" "403"
# L'ordine dei verdetti: `get_gestore_gare_torneo` chiama `_get_torneo` PRIMA di guardare le categorie.
# Se non lo facesse, un mister che indovina un id inesistente riceverebbe un 403 "non e' una delle tue
# categorie" -- una frase che descrive un torneo che non esiste, e che nasconde il 404 che e' la risposta
# vera. E' il controllo che rende onesta la docstring del gate
ck "torneo inesistente come mister -> 404, non 403" \
   "$(gara_cod 999999 "$TMIA" "{\"avversario\":\"${P}Fantasma\"}")" "404"
ck "torneo dell'altra societa' come mister -> 403" \
   "$(gara_cod $TALT "$TMIA" "{\"avversario\":\"${P}Altrove\",\"data\":\"2026-12-27\"}")" "403"
ck "  e il 403 e' QUELLO DEL TENANT, non quello delle categorie" \
   "$(gara_det $TALT "$TMIA" "{\"avversario\":\"${P}Altrove2\"}" | grep -ci 'Non autorizzato su questo torneo')" "1"
ck "  e nessuna gara e' nata sul torneo dell'altra societa'" \
   "$(gare_con $TALT "${P}Altrove")" "0"
# Il confine di cio' che e' stato approvato il 25/11: il criterio e' sul TORNEO, non sulla singola gara.
# Un mister puo' quindi aggiungere una gara all'altra categoria di un torneo condiviso. Non e' una
# svista da correggere di straforo, e' una scelta non presa -- e questa asserzione esiste perche', se un
# giorno qualcuno la cambia senza parlarne, il rosso si veda
ck "apertura nota e voluta: mister-a puo' aggiungere una gara alla categoria B del torneo condiviso -> 200" \
   "$(gara_cod $TAEB "$TMIA" "{\"avversario\":\"${P}GaraAinB\",\"categoria_id\":$CB,\"data\":\"2026-12-24\"}")" "200"
GARE_DOPO=$(q "SELECT count(*) FROM tornei_gare tg JOIN tornei t ON t.id=tg.torneo_id WHERE t.nome LIKE '$P%'")
ck "in tutto le gare di prova sono 8, e sono solo quelle lecite (nessun 403 ha scritto righe)" \
   "$GARE_DOPO" "$((GARE_PRIMA + 8))"

echo
echo "--- 9. niente residui, niente effetti collaterali ---"
ck "i tornei in DB sono baseline + i 5 di prova (4 + quello dell'altra societa')" "$(q "SELECT count(*) FROM tornei")" "$((BASE_TORNEI + 5))"
ck "utente_categorie e' cresciuto solo delle 3 assegnazioni dei fixture" \
   "$(q "SELECT count(*) FROM utente_categorie")" "$((BASE_UC + 3))"
pulizia
ck "dopo la pulizia non resta nessun oggetto di prova" \
   "$(q "SELECT (SELECT count(*) FROM tornei WHERE nome LIKE '$P%') + (SELECT count(*) FROM categorie WHERE nome LIKE '$P%') + (SELECT count(*) FROM utenti WHERE username LIKE '$U%')")" "0"
ck "e i tornei di DEV sono tornati alla baseline" "$(q "SELECT count(*) FROM tornei")" "$BASE_TORNEI"

echo
echo "$pass passati, $fail falliti"
[ "$fail" -eq 0 ] || exit 1
