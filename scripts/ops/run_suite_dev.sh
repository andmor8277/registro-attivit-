#!/bin/bash
# Esegue tutta la suite DEV e stampa il totale delle asserzioni.
cd /home/andrea/Documenti/opencode-project/registro_presenze || exit 1
tot=0; ko=0
SH='scripts/test'

riga() { printf "  %-34s %s\n" "$1" "$2"; }
conta() { echo "$1" | grep -oE '[0-9]+ passati, [0-9]+ falliti' | tail -1; }
primo() { echo "$1" | sed -n 's/^\([0-9]*\) passati.*/\1/p'; }
secondo() { echo "$1" | sed -n 's/.*, \([0-9]*\) falliti/\1/p'; }

for t in test_registro_tenant.sh test_orario_presentazione.sh test_token_pubblico.sh \
         test_fix_a2_a8_a9.sh test_pii_accessi.sh; do
  out=$(bash "$SH/$t" 2>&1 | grep -v "Warning: Permanently added")
  r=$(conta "$out")
  riga "$t" "$r"
  tot=$((tot + $(primo "$r")))
  ko=$((ko + $(secondo "$r")))
  echo "$out" | grep "FAIL" | sed 's/^/        /'
done

u_raw=$(timeout 200 ssh -i ~/.ssh/id_ed25519_dev root@192.168.178.133 \
     'docker exec -i registro_presenze-backend-1 python -' \
     < "$SH/test_orario_presentazione_unit.py" 2>&1)
u=$(conta "$u_raw")
riga "test_orario_presentazione_unit.py" "$u"
tot=$((tot + $(primo "$u"))); ko=$((ko + $(secondo "$u")))

g_raw=$(bash "$SH/test_login_guard.sh" 2>&1)
g=$(conta "$g_raw")
riga "test_login_guard.sh" "$g"
tot=$((tot + $(primo "$g"))); ko=$((ko + $(secondo "$g")))
echo "$g_raw" | grep "FAIL" | sed 's/^/        /'

echo "  ------------------------------------------------------------------"
printf "  TOTALE: %s asserzioni verdi, %s rosse\n" "$tot" "$ko"
[ "$ko" -eq 0 ]
