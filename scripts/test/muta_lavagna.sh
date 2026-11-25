#!/bin/bash
# Arnese per i NEGATIVE TEST del guard-rail della lavagna (scripts/test/ui_lavagna.cjs).
#
# Perche' esiste un file dedicato: due incidenti reali con i backup durante i negative test. Un
# `[ -f backup ] || cp` riuso' un pristino stantio e il "ripristino" sovrascrisse il lavoro; poi un
# backup rifatto da un file gia' mutato lo contamino'. Qui: il backup si fa SEMPRE da zero (mai `||`)
# e viene verificato in ENTRAMBI i versi prima di essere usato -- deve essere byte-a-byte uguale
# all'originale, deve contenere le funzioni che la mutazione tocca, e non deve contenere mutazioni.
#
# Due superfici, perche' il test ha due meta' che si sfidano in modo diverso:
#   PARTE A      legge il SORGENTE LOCALE  -> basta mutare il file qui, nessun deploy
#   PARTI B/C/D  girano contro DEV          -> la mutazione va dentro il container (docker cp del
#                                              file statico, NESSUN rebuild) e tolta dopo
#
# Uso:
#   bash scripts/test/muta_lavagna.sh stato
#   bash scripts/test/muta_lavagna.sh mutare loadelement ring          # solo Parte A
#   bash scripts/test/muta_lavagna.sh mutare loadelement ring --dev    # anche B/C/D
#   bash scripts/test/muta_lavagna.sh ripristino
set -u
# REPO derivato dalla posizione dello script: un arnese dei negative test che solo una postazione
# puo' lanciare e' un arnese che nessuno rilancera'
REPO="${THOF_REPO:-$(cd "$(dirname "$0")/../.." && pwd)}"
F="$REPO/frontend/public/lavagna-20250702.html"
A="$REPO/frontend/src/features/allenamenti/Allenamenti.vue"
BK=/tmp/opencode/lavagna.pristino
BKA=/tmp/opencode/Allenamenti.pristino
KV="$HOME/.ssh/id_ed25519_dev"; DEVI=192.168.178.133
SSH="ssh -i $KV -o ConnectTimeout=15 root@$DEVI"
DST=/usr/share/nginx/html/lavagna-20250702.html
BKC=/tmp/opencode/Allenamenti-chunk.pristino.js
h() { sha256sum "$1" | cut -c1-16; }
cont() { $SSH 'docker ps -qf name=frontend' 2>/dev/null | tr -d '\r'; }
hash_container() { local c; c=$(cont); [ -n "$c" ] && $SSH "docker exec $c sha256sum $DST" 2>/dev/null | cut -c1-16 | sed 's|.*/||'; }
# Il chunk COMPILATO di Allenamenti.vue. Serve perche' Allenamenti.vue e' un SFC: mutare il sorgente
# locale cambia cio' che legge la PARTE A (che quel file lo apre da disco) ma NON cio' che esegue il
# browser, che scarica il bundle da /usr/share/nginx/html/assets/. E' il motivo per cui il caso
# `whitelist` era verde: la mutazione non arrivava mai al browser. Il nome del file porta l'hash dei
# contenuti, quindi va SCOPERTO a ogni uso e mai scritto a mano (un rebuild lo cambia).
trova_chunk() {
  local c; c=$(cont); [ -n "$c" ] || return 1
  $SSH "docker exec $c sh -c \"grep -l 'wavy:' /usr/share/nginx/html/assets/*.js 2>/dev/null\"" 2>/dev/null | tr -d '\r' | head -1
}
chunk_hash() { local c; c=$(cont); [ -n "$c" ] && [ -n "${1:-}" ] && $SSH "docker exec $c sha256sum '$1'" 2>/dev/null | cut -c1-16 | sed 's|.*/||'; }

# ── backup SEMPRE da zero, verificato prima di toccare che cosa ──
fa_backup() {
  mkdir -p /tmp/opencode
  cp "$F" "$BK"; cp "$A" "$BKA"
  cmp -s "$F"  "$BK"  || { echo "  BLOCCATO: il backup della lavagna non coincide col sorgente"; exit 1; }
  cmp -s "$A"  "$BKA" || { echo "  BLOCCATO: il backup di Allenamenti.vue non coincide"; exit 1; }
  grep -q "function loadElement("  "$BK" || { echo "  BLOCCATO: il backup non contiene loadElement: non e' un pristino valido"; exit 1; }
  grep -q "function getElements("  "$BK" || { echo "  BLOCCATO: il backup non contiene getElements"; exit 1; }
  grep -q "var toolSections=\["    "$BK" || { echo "  BLOCCATO: il backup non contiene la palette"; exit 1; }
  grep -q "function drawElementsCanvas(" "$BKA" || { echo "  BLOCCATO: il backup di Allenamenti.vue non contiene drawElementsCanvas"; exit 1; }
  if grep -q "__MUTATO__" "$BK" "$BKA"; then echo "  BLOCCATO: il backup contiene una mutazione: non usarlo per ripristinare"; exit 1; fi
  # il chunk si backuppa DENTRO->FUORI e la coincidenza si verifica DENTRO: se il backup non fosse
  # byte-a-byte il file che c'e' nel container, il "ripristino" scriverebbe li' un file diverso da
  # quello che ho mutato, e la cosa non si vedrebbe piu'
  CH=$(trova_chunk || true)
  if [ -n "$CH" ]; then
    local c; c=$(cont)
    $SSH "docker exec $c cat '$CH'" > "$BKC" || { echo "  BLOCCATO: non riesco a leggere il chunk dal container"; exit 1; }
    [ -s "$BKC" ] || { echo "  BLOCCATO: il backup del chunk e' vuoto"; exit 1; }
    grep -q "__MUTATO__" "$BKC" && { echo "  BLOCCATO: il chunk contiene gia' una mutazione: non e' un pristino"; exit 1; }
    local cd; cd=$(chunk_hash "$CH")
    [ "$cd" = "$(h "$BKC")" ] || { echo "  BLOCCATO: il chunk backuppato ($(h "$BKC")) non coincide con quello nel container ($cd)"; exit 1; }
    echo "  chunk   : $CH  $(h "$BKC")  (verificato dentro il container)"
  else
    echo "  chunk   : nessuno trovato (i casi che colpiscono il bundle si bloccheranno da soli)"
  fi
  echo "  backup verificato: lavagna $(h "$BK")  allenamenti $(h "$BKA")"
}

ripristina() {
  [ -f "$BK" ] || { echo "  nessun backup: non ripristino niente"; exit 1; }
  grep -q "__MUTATO__" "$BK" && { echo "  BLOCCATO: il backup e' contaminato"; exit 1; }
  cp "$BK" "$F"
  [ "$(h "$F")" = "$(h "$BK")" ] || { echo "  BLOCCATO: sorgente non ripristinato (hash diversi)"; exit 1; }
  if [ -f "$BKA" ]; then
    cp "$BKA" "$A"
    [ "$(h "$A")" = "$(h "$BKA")" ] || { echo "  BLOCCATO: Allenamenti.vue non ripristinato"; exit 1; }
  fi
  echo "  sorgente locale : $(h "$F")  ripristinato"
  local c; c=$(cont)
  if [ -n "$c" ]; then
    # si rispedisce il PRISTINO nel container e si rilegge l'hash DA DENTRO: fidarsi del cp sarebbe
    # lo stesso errore di chi dichiara un deploy riuscito senza guardare l'immagine
    cat "$BK" | $SSH "cat > /tmp/_lavagna_pristino.html"
    $SSH "docker cp /tmp/_lavagna_pristino.html $c:$DST"
    local dentro; dentro=$(hash_container)
    if [ "$dentro" = "$(h "$BK")" ]; then echo "  nel container   : $dentro  = pristino"
    else echo "  BLOCCATO: nel container c'e' $dentro, il pristino e' $(h "$BK")"; exit 1; fi
    # il chunk va rimesso solo se era stato backuppato (c'era) e se ora DENTRO non e' piu' il pristino:
    # riscriverlo quando e' gia' a posto cancellerebbe l'effetto di un eventuale build nel frattempo
    if [ -f "$BKC" ]; then
      local ch2; ch2=$(trova_chunk || true)
      if [ -n "$ch2" ]; then
        local d2; d2=$(chunk_hash "$ch2")
        if [ "$d2" = "$(h "$BKC")" ]; then
          echo "  chunk           : $d2  gia' pristino, non lo tocco"
        else
          cat "$BKC" | $SSH "cat > /tmp/_Allenamenti_pristino.js"
          $SSH "docker cp /tmp/_Allenamenti_pristino.js $c:$ch2"
          local d3; d3=$(chunk_hash "$ch2")
          if [ "$d3" = "$(h "$BKC")" ]; then echo "  chunk           : $d3  ripristinato (era $d2)"
          else echo "  BLOCCATO: chunk non ripristinato (dentro $d3, pristino $(h "$BKC"))"; exit 1; fi
        fi
      fi
    fi
  fi
}

case "${1:-stato}" in
  stato)
    echo "  sorgente locale : $(h "$F")"
    echo "  Allenamenti.vue : $(h "$A")"
    echo "  backup lavagna  : $([ -f "$BK" ] && h "$BK" || echo 'nessuno')"
    echo "  nel container   : $(hash_container || echo 'n/d')"
    ;;
  ripristino) ripristina ;;

  mutare)
    MODO="${2:-}"; TIPO="${3:-ring}"; DEV="${4:-}"
    # I tre modi sul vetro (jolly-vuoto, rombo, jolly-numero) non hanno un TIPO da colpire. Senza questo
    # spostamento, `mutare rombo --dev` metteva `--dev` in TIPO e lasciava DEV **vuoto**: la mutazione
    # restava sul disco, il browser eseguiva il pristino e tutti e tre i giri hanno detto "MANCATO ROSSO"
    # (misurato 25/11/2026). Il contratto degli altri e' `mutare <modo> <tipo> [--dev]`
    if [ "${TIPO#--}" != "$TIPO" ]; then DEV="$TIPO"; TIPO="ring"; fi
    case "$MODO" in loadelement|getelements|pdf|etichetta|whitelist|jolly-vuoto|rombo|jolly-numero|legacy-identita|legacy-forma) ;; *) echo "modi: loadelement|getelements|pdf|etichetta|whitelist|jolly-vuoto|rombo|jolly-numero|legacy-identita|legacy-forma"; exit 2 ;; esac
    fa_backup
    ORIG=$(h "$F"); ORIG_A=$(h "$A")
    MODO="$MODO" TIPO="$TIPO" F="$F" A="$A" python3 <<'PY'
import os, re, sys
modo, tipo = os.environ['MODO'], os.environ['TIPO']
f, a = os.environ['F'], os.environ['A']

def scrivi(path, s):
    open(path, 'w', encoding='utf-8').write(s)

if modo == 'loadelement':
    # si toglie il RAMO, non la funzione: e' il difetto reale (tipo nella palette, dimenticato in
    # loadElement -> l'elemento sparisce alla riapertura IN SILENZIO, perche' doLoadElements fa
    # `if(newEl) add(newEl)` e il console.error scatta solo sulle eccezioni)
    s = open(f, encoding='utf-8').read()
    m = re.search(r"else if\(el\.tipo==='" + tipo + r"'\)\{.*?\n    \}", s, re.S)
    if not m: print(f"  BLOCCATO: nessun ramo loadElement per '{tipo}': la mutazione non partirebbe"); sys.exit(3)
    scrivi(f, s[:m.start()] + "/*__MUTATO__: ramo loadElement di " + tipo + " rimosso__*/" + s[m.end():])
    print(f"  mutato loadElement: ramo di '{tipo}' tolto")

elif modo == 'getelements':
    # ATTESO: `else if(tipo==='cone'){` compare DUE volte anche dentro il solo getElements, e non e'
    # un doppione: la prima catena (righe ~365-390) decide COME LEGGERE IL COLORE dal nodo Konva, la
    # seconda (~394 in poi) decide la GEOMETRIA (size/w/h/x1..y2). Sono le due catene che "si rompono
    # a ogni modifica": se ne aggiorna una e non l'altra l'oggetto nasce senza colore o senza misura.
    # Si opera SOLO dentro il corpo di getElements (fuori, `else if(tipo==='ring'){` compare altre
    # volte) e si rinominano TUTTI i rami del tipo: chiedere "esattamente 1" bloccava il caso.
    # DA SAPERE, perche' cambia cosa puo' dimostrare questo caso: rinominare questi rami NON cambia il
    # `tipo` serializzato, che alla riga 393 viene preso da child.getAttr('dataElement'). Quindi
    # l'asserzione "nessun tipo si perde nel salvataggio" NON puo' diventare rossa qui, e il negative
    # test infatti la mette fra quelle che DEVONO restare verdi. Per il tipo che sparisce c'e' il caso
    # `whitelist`, che colpisce la lista bianca del payload.
    s = open(f, encoding='utf-8').read()
    i0 = s.index('function getElements(')
    i1 = s.index('\n  function ', i0 + 10)
    corpo = s[i0:i1]
    vecchio = "else if(tipo==='" + tipo + "'){"
    n = corpo.count(vecchio)
    if n < 1: print(f"  BLOCCATO: nessun ramo getElements per '{tipo}': la mutazione non partirebbe"); sys.exit(3)
    scrivi(f, s[:i0] + corpo.replace(vecchio, "else if(tipo==='__MUTATO_" + tipo + "__'){") + s[i1:])
    print(f"  mutato getElements: {n} rami (colore e/o geometria) di '{tipo}' non piu' riconosciuti")

elif modo == 'pdf':
    s = open(a, encoding='utf-8').read()
    n = len(re.findall(r"tipo === '" + tipo + "'", s))
    if n == 0: print(f"  BLOCCATO: drawElementsCanvas non tratta '{tipo}'"); sys.exit(3)
    scrivi(a, re.sub(r"tipo === '" + tipo + "'", "tipo === '__MUTATO_" + tipo + "__'", s))
    print(f"  mutato pdf: {n} rami di '{tipo}' rinominati in drawElementsCanvas")

elif modo == 'whitelist':
    # LA LISTA BIANCA DEL PAYLOAD (Allenamenti.vue, dentro saveDataToServer): `elementi` e' costruita
    # elencando a mano 19 nomi di campo. Un nome rinominato o dimenticato non da' nessun errore --
    # l'elemento parte e quel campo non c'e', e il CONTEGGIO degli elementi resta giusto, quindi le
    # asserzioni "nessun tipo si perde" non lo vedono. E' il difetto che AGENTS.md chiama "un campo
    # nuovo viene perso in silenzio". Qui `tipo` e' il NOMEDICAMPO da far sparire (es. size).
    # Si opera SOLO dentro il corpo di saveDataToServer: `size: el.size ?? null,` esiste identico
    # anche in loadEsercizi, selezionaDaCatalogo e confirmSaveSelectedToCatalogo, e mutare uno di
    # quelli sarebbe un'altra mutazione con un altro nome.
    s = open(a, encoding='utf-8').read()
    i0 = s.index('function saveDataToServer(')
    mm = re.search(r"\n(?:async )?function ", s[i0 + 10:])
    if not mm: print("  BLOCCATO: non trovo la fine di saveDataToServer"); sys.exit(3)
    i1 = i0 + 10 + mm.start()
    corpo = s[i0:i1]
    pat = r"(\n\s*)" + tipo + r":(\s*el\." + tipo + r"\s*\?\?)"
    n = len(re.findall(pat, corpo))
    if n != 1: print(f"  BLOCCATO: {n} occorrenze di '{tipo}:' nel payload di salvataggio (atteso 1)"); sys.exit(3)
    nuovo = re.sub(pat, lambda m: m.group(1) + "__MUTATO_" + tipo + ":" + m.group(2), corpo, count=1)
    if nuovo == corpo: print("  BLOCCATO: la sostituzione non e' avvenuta"); sys.exit(3)
    scrivi(a, s[:i0] + nuovo + s[i1:])
    print(f"  mutata lista bianca: il campo '{tipo}' non viene piu' messo nel payload di salvataggio")

elif modo == 'etichetta':
    s = open(f, encoding='utf-8').read()
    vecchio = "{type:'" + tipo + "',label:'"
    if s.count(vecchio) != 1: print(f"  BLOCCATO: pattern etichetta per '{tipo}' non univoco"); sys.exit(3)
    scrivi(f, s.replace(vecchio, "{type:'" + tipo + "',label:'XX"))
    print(f"  mutata etichetta: '{tipo}' ora ha un titolo che a schermo non esiste")

elif modo == 'jolly-vuoto':
    # IL DIFETTO SEGNALATO DAL TITOLARE (25/11/2026): «deve avere il colore anche all'interno, adesso e'
    # vuoto». Riporta Jolly e Portiere a NON essere riempiti -- lo stato di prima. Se le asserzioni nuove
    # della PARTE C2 non diventano rosse QUI, non stavano misurando niente
    s = open(f, encoding='utf-8').read()
    vecchio = "isFilled=type==='player-bib'||type==='player-jolly'||type==='gk'"
    if s.count(vecchio) != 1: print(f"  BLOCCATO: {s.count(vecchio)} occorrenze del criterio di riempimento (atteso 1)"); sys.exit(3)
    nuovo = "isFilled=type==='player-bib'||type==='__MUTATO_player-jolly__'||type==='__MUTATO_gk__'"
    if nuovo == s: print("  BLOCCATO: la sostituzione non e' avvenuta"); sys.exit(3)
    scrivi(f, s.replace(vecchio, nuovo))
    print("  mutato riempimento: Jolly e Portiere tornano VUOTI dentro (come stavano prima)")

elif modo == 'rombo':
    # il Jolly torna QUADRATO: `rotation:45` su un RegularPolygon a 4 lati, che in Konva ha gia' un
    # vertice in alto. E' il caso in cui campo e miniatura raccontano due oggetti diversi (l'icona della
    # palette e la miniatura lo disegnano a rombo)
    s = open(f, encoding='utf-8').read()
    vecchio = "if(isDiamond){g.add(new Konva.RegularPolygon({sides:4,radius:r,stroke:currentColor"
    if s.count(vecchio) != 1: print(f"  BLOCCATO: {s.count(vecchio)} occorrenze del rombo (atteso 1)"); sys.exit(3)
    scrivi(f, s.replace(vecchio, vecchio.replace("radius:r,stroke", "radius:r,rotation:45,stroke")))
    print("  mutata forma: il Jolly torna un quadrato (rotation:45 rimesso)")

elif modo == 'jolly-numero':
    # il Jolly torna a mostrare il NUMERO progressivo invece della lettera J: e' quello che il titolare
    # non vuole («invece dei numeri solo la scritta J, uguale per tutti i Jolly che metto»)
    s = open(f, encoding='utf-8').read()
    vecchio = "text:isGK?'P':'J'"
    if s.count(vecchio) != 1: print(f"  BLOCCATO: {s.count(vecchio)} occorrenze della lettera (atteso 1)"); sys.exit(3)
    scrivi(f, s.replace(vecchio, "text:isGK?'P':String(num)"))
    print("  mutata lettera: il Jolly ridipinge il numero progressivo al posto della J")

elif modo == 'legacy-identita':
    # la mappa legacy resta intatta (quindi la misura STATICA continua a dire 0 buchi) ma la funzione che
    # la consulta diventa l'identita': i 132 elementi tornano invisibili IN SILENZIO. E' il giro che
    # dimostra che le asserzioni 3b del browser vedono una cosa che nessun controllo sul sorgente vede
    s = open(f, encoding='utf-8').read()
    vecchio = "function tipoDisegno(t){return Object.prototype.hasOwnProperty.call(legacyTipi,t)?legacyTipi[t]:t}"
    if s.count(vecchio) != 1: print(f"  BLOCCATO: {s.count(vecchio)} occorrenze di tipoDisegno (atteso 1)"); sys.exit(3)
    scrivi(f, s.replace(vecchio, "function tipoDisegno(t){return t}"))
    print("  mutata normalizzazione: tipoDisegno e' l'identita', i tipi legacy non trovano piu' nessun ramo")

elif modo == 'legacy-forma':
    # la mappa c'e' e l'elemento si dipinge, ma come un OGGETTO DIVERSO (player-red diventa un pallone):
    # "non spariscono" resta verde, rossa solo l'asserzione sulla forma. E' il discriminatorio che serve
    # a non accettare un verde dato dal semplice conteggio
    s = open(f, encoding='utf-8').read()
    vecchio = "'player-red':'player'"
    if s.count(vecchio) != 1: print(f"  BLOCCATO: {s.count(vecchio)} occorrenze della mappa (atteso 1)"); sys.exit(3)
    scrivi(f, s.replace(vecchio, "'player-red':'ball'"))
    print("  mutata la mappa: player-red viene disegnato come un pallone invece che come un giocatore")
PY
    [ $? -ne 0 ] && exit 3
    [ "$(h "$F")" != "$ORIG" ] || [ "$(h "$A")" != "$ORIG_A" ] || {
      echo "  BLOCCATO: nessun file e' cambiato: la mutazione non e' partita. Un eventuale verde sarebbe un falso verde"; exit 1; }
    echo "  lavagna   : $ORIG -> $(h "$F")"
    echo "  allenam.  : $ORIG_A -> $(h "$A")"
    if [ "$DEV" = "--dev" ]; then
      local_c=$(cont); [ -n "$local_c" ] || { echo "  BLOCCATO: nessun container frontend su DEV"; exit 1; }
      cat "$F" | $SSH "cat > /tmp/_lavagna_mutato.html"
      $SSH "docker cp /tmp/_lavagna_mutato.html $local_c:$DST"
      # Non basta stamparla, la coincidenza: va ASSERTA. Il 25/11/2026 i tre giri sul vetro sono rimasti
      # verdi 162/0 perche' la mutazione non era mai arrivata nel container -- e questo riga la stampava e
      # basta, dicendo "deve essere il nuovo X" senza confrontare. Un verde del browser su un file che il
      # browser non ha mai eseguito non e' un verdetto
      NUOVA=$(h "$F"); DENTRO=$(hash_container)
      [ "$DENTRO" = "$NUOVA" ] || { echo "  BLOCCATO: la mutazione non e' nel file SERVITO (container=$DENTRO, file=$NUOVA): il browser eseguirebbe il pristino"; exit 3; }
      echo "  container   : $DENTRO  = il nuovo $NUOVA  (verificato nei byte del container)"
      if [ "$MODO" = "whitelist" ]; then
        # Qui sta la ragione di tutto il ramo: mutare Allenamenti.vue sul disco cambia cio' che legge
        # la PARTE A (quel file la' lo apre da disco) ma NON cio' che esegue il browser, che scarica
        # il bundle compilato. Senza questo passo il caso `whitelist` era VERDE PER MOTIVO SBAGLIATO:
        # il browser salvava tutti i campi perche' stava eseguendo il codice pristino.
        [ -n "${CH:-}" ] || CH=$(trova_chunk || true)
        [ -n "$CH" ] || { echo "  BLOCCATO: non trovo il chunk di Allenamenti nel container"; exit 1; }
        [ -f "$BKC" ] || { echo "  BLOCCATO: nessun backup del chunk: non muto un file che non posso ripristinare"; exit 1; }
        python3 - "$BKC" /tmp/opencode/_Allenamenti_mutato.js "$TIPO" <<'PY'
import re, sys
src, dst, campo = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src, encoding='utf-8').read()
# lo shape della lista bianca, minificato: size:t.size??null
pat = re.compile(r"(?<![\w$])" + re.escape(campo) + r":([\w$]+)\." + re.escape(campo) + r"\s*\?\?\s*null")
nuovo, n = pat.subn(lambda m: "__MUTATO_" + campo + ":" + m.group(1) + "." + m.group(1) + "??null", s)
if n < 1:
    print(f"  BLOCCATO: nessuna occorrenza di '{campo}:VAR.{campo}??null' nel chunk: la mutazione non partirebbe")
    sys.exit(3)
open(dst, 'w', encoding='utf-8').write(nuovo)
print(f"  chunk mutato: {n} occorrenze del campo '{campo}' tolte dai payload (salvataggio e catalogo)")
PY
        [ $? -eq 0 ] || { echo "  BLOCCATO: la mutazione del chunk non e' partita"; exit 3; }
        cat /tmp/opencode/_Allenamenti_mutato.js | $SSH "cat > /tmp/_Allenamenti_mutato.js"
        $SSH "docker cp /tmp/_Allenamenti_mutato.js $local_c:$CH"
        echo "  chunk       : $(chunk_hash "$CH")  (pristino $(h "$BKC"): devono essere DIVERSI)"
        [ "$(chunk_hash "$CH")" != "$(h "$BKC")" ] || { echo "  BLOCCATO: il chunk nel container e' ancora il pristino"; exit 1; }
      fi
    fi
    ;;
  *) echo "uso: $0 stato|ripristino|mutare <modo> <tipo> [--dev]"; exit 2 ;;
esac
