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
#     test_tornei_categorie.sh, test_tornei_sezioni.sh e ui_tornei.cjs la leggono come lista.
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
# Il quarto -- il torneo SENZA categorie iscritte -- non si puo' fare ne' via API ne' a mani nude:
#  - l'API lo rifiuta: `POST /tornei/` passa da `_valida`, che risponde 400 "Seleziona almeno una
#    categoria" (e non e' dato per scontato, c'e' l'asserzione qui sotto);
#  - il DB pure: `tornei.categoria_id` ha ancora il NOT NULL, su DEV **e** su PROD misurati il
#    25/11/2026, anche se il modello dichiara `nullable=True` e il commento dice "Nullable dal
#    2026-11-20" -- la migrazione non esiste (cerca `DROP NOT NULL` in backend/app/migrations/run.py:
#    c'e' solo per utenti.password_hash). E' un modello che descrive uno schema che il DB non ha, e
#    oggi non esplode perche' `crea_torneo` scrive sempre `categorie_ids[0]`, mai NULL.
# Quindi l'orfano reale ha la colonna legacy POPOLATA e zero righe in tornei_categorie: ed e'
# esattamente il caso che il filtro deve reggere, perche' la fonte di verita' dichiarata sono le
# iscrizioni, non quella colonna ("Non e' la fonte di verita' (quella e' tornei_categorie)")
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
echo "--- 8. niente residui, niente effetti collaterali ---"
ck "i tornei in DB sono baseline + i 4 di prova" "$(q "SELECT count(*) FROM tornei")" "$((BASE_TORNEI + 4))"
ck "utente_categorie e' cresciuto solo delle 3 assegnazioni dei fixture" \
   "$(q "SELECT count(*) FROM utente_categorie")" "$((BASE_UC + 3))"
pulizia
ck "dopo la pulizia non resta nessun oggetto di prova" \
   "$(q "SELECT (SELECT count(*) FROM tornei WHERE nome LIKE '$P%') + (SELECT count(*) FROM categorie WHERE nome LIKE '$P%') + (SELECT count(*) FROM utenti WHERE username LIKE '$U%')")" "0"
ck "e i tornei di DEV sono tornati alla baseline" "$(q "SELECT count(*) FROM tornei")" "$BASE_TORNEI"

echo
echo "$pass passati, $fail falliti"
[ "$fail" -eq 0 ] || exit 1
