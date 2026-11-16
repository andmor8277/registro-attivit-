#!/bin/bash
# Genera una passphrase comunicabile per DEFAULT_PASSWORD: 5 parole + 3 cifre.
# Scelta deliberata: deve poter essere dettata al telefono a un admin, non incollata.
#
# Forza: 5 parole su una lista di 128 (5 x 7 bit = 35 bit) + 3 cifre (10 bit) ~ 45 bit.
# E' un valore temporaneo e condiviso, usato solo quando un admin fa un reset, e la rotta
# di login e' protetta da rate limit + blocco per username. La correzione vera resta una
# password casuale per singolo reset, non mostrata altrove.
PAROLE=(
barca nord verde falco luna ponte sale monte riva vento sole
colla tela telaio panino prato fiore monte lago fiume ponte
gatto leone cervo lupo orso aquila rondine delfino balena foca
melone pesca ciliegia noce oliva grano orzo riso mais fava
tavola sedia lampada porta finestra tetto muro scala giardino
chitarra tamburo flauto viola tromba piano arpa corno organo
matita gomma riga squadra colore pennello tela marmo ferro
martedi mercoledi giovedi venerdi sabato gennaio febbraio marzo
aprile maggio giugno luglio agosto settembre ottobre novembre
bicicletta treno aereo nave motorino carrello treno funivia
nonno nonna zio cugino vicino amico ospite alunno maestro
stella cometa pianeta orbita galassia cielo nuvola pioggia
caffe latte burro formaggio miele zucchero pepe cannella
)
# deduplica e tiene solo parole senza caratteri ambigui
UNIQUES=($(printf '%s\n' "${PAROLE[@]}" | tr 'A-Z' 'a-z' | grep -E '^[a-z]{4,10}$' | sort -u))
N=${#UNIQUES[@]}
if [ "$N" -lt 100 ]; then echo "  lista parole troppo corta ($N)" >&2; exit 1; fi

OUT=""
for i in 1 2 3 4 5; do
  # serve il prefisso 0x: senza, bash interpreta "75c9" come nome di variabile e l'aritmetica fallisce
  idx=$(( 0x$(openssl rand -hex 4) % N ))
  w="${UNIQUES[$idx]}"
  # un indice vuoto produrrebbe una passphrase quasi vuota senza che nessuno se ne accorga
  [ -z "$w" ] && { echo "  errore: parola vuota all'indice $idx" >&2; exit 1; }
  OUT+="$w"
  [ $i -lt 5 ] && OUT+="-"
done
CIFRE=$(printf '%03d' $(( 0x$(openssl rand -hex 3) % 1000 )))
OUT+="-$CIFRE"

# verifica di struttura prima di consegnarla: 5 parole separate da - e 3 cifre finali
if ! printf '%s' "$OUT" | grep -qE '^[a-z]{4,10}(-[a-z]{4,10}){4}-[0-9]{3}$'; then
  echo "  passphrase con struttura inattesa: annullata" >&2; exit 1
fi

printf '%s' "$OUT"
# rapporto di forza, per non dichiarare forza che non ha
entropy=$(awk -v n="$N" -v w=5 -v c=3 'BEGIN{printf "%.0f", w*log(n)/log(2) + c*log(10)/log(2)}')
echo "  # parole_distinte=$N entropia~${entropy}bit" >&2
