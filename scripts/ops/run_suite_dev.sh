#!/bin/bash
# Esegue tutta la suite DEV e stampa il totale delle asserzioni.
#
# Scopre da se' gli script test_*.sh in scripts/test: la versione precedente aveva l'elenco
# scritto a mano e sommaria solo i passati delle prime cinque suite, percio' stampava
# "0 rosse" mentre un test stava fallendo. Un elenco a mano e' lo stesso errore che si
# ripresenta appena si aggiunge un file.
#
# Esclude gli script *_prod.sh: puntano a produzione e si lanciano a parte.
cd /home/andrea/Documenti/opencode-project/registro_presenze || exit 1
tot=0; ko=0; rotti=0
SH='scripts/test'

riga() { printf "  %-34s %s\n" "$1" "$2"; }
conta() { echo "$1" | grep -oE '[0-9]+ passati, [0-9]+ falliti' | tail -1; }
primo() { echo "$1" | sed -n 's/^\([0-9]*\) passati.*/\1/p'; }
secondo() { echo "$1" | sed -n 's/.*, \([0-9]*\) falliti/\1/p'; }
aggiungi() {
  local nome="$1" out="$2" r
  r=$(conta "$out")
  if [ -z "$r" ]; then
    # nessun contatore trovato: il test e' crashato prima di stampare il riepilogo.
    # Contarlo come rotto, non come "zero asserzioni", e' il punto di tutto questo file
    riga "$nome" "NESSUN RIASSUNTO (test rotto)"
    rotti=$((rotti + 1))
  else
    riga "$nome" "$r"
    tot=$((tot + $(primo "$r")))
    ko=$((ko + $(secondo "$r")))
  fi
  echo "$out" | grep "FAIL" | sed 's/^/        /'
}

for t in "$SH"/test_*.sh; do
  base=$(basename "$t")
  case "$base" in *_prod.sh) continue ;; esac
  aggiungi "$base" "$(bash "$t" 2>&1 | grep -v 'Warning: Permanently added')"
done

u_raw=$(timeout 200 ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 \
     'docker exec -i registro_presenze-backend-1 python -' \
     < "$SH/test_orario_presentazione_unit.py" 2>&1)
aggiungi "test_orario_presentazione_unit.py" "$u_raw"

# Controllo residui: ogni test pulisce da solo, ma le pulizie cercano le proprie chiavi (di
# solito LIKE 'test%') e non vedono il resto. Una riga orfana in login_bloccaggi lasciata da un
# sondaggio lanciato a mano, non da un file della suite, era rimasta li' invisibile perche' nessuno
# la cercava. Contare gli orfani, non solo i 'test%', e' cio' che rende questo check utile.
residui=$(timeout 200 ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 \
     'docker exec -i $(docker ps -qf name=db) psql -U registro_user -d registro -tA -f -' \
     <<'SQL' 2>&1 | tr -d '\r' | tail -1
SELECT 'residui='||(SELECT count(*) FROM utenti WHERE username LIKE 'test%')
                ||'/'||(SELECT count(*) FROM login_bloccaggi WHERE chiave LIKE 'test%')
                ||'/'||(SELECT count(*) FROM login_bloccaggi lb
                        WHERE NOT EXISTS (SELECT 1 FROM utenti u WHERE u.username = lb.chiave));
SQL
)
if [ "$residui" = "residui=0/0/0" ]; then
  riga "residui nel DB (utenti/blocchi/orfani)" "nessuno"
else
  # i numeri sono utenti/bloccaggi-test/orfani: stamparli, perche' "residui" senza dire quali
  # obbligherebbe chi legge a rincorrere il DB per capire di chi sono
  riga "residui nel DB (utenti/blocchi/orfani)" "$residui  <- da pulire"
  rotti=$((rotti + 1))
fi

echo "  ------------------------------------------------------------------"
printf "  TOTALE: %s asserzioni verdi, %s rosse, %s problemi\n" "$tot" "$ko" "$rotti"
[ "$ko" -eq 0 ] && [ "$rotti" -eq 0 ]
