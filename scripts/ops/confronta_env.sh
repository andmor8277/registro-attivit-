#!/bin/bash
# Confronta i segreti dei .env tra DEV e PROD senza mai stamparne il valore:
# per ogni chiave viene mostrato solo lunghezza e anteprima dello sha256.
CHIAVI="DB_USER DB_PASSWORD DB_NAME SECRET_KEY ENCRYPTION_KEY DEFAULT_PASSWORD FRONTEND_URL VITE_API_URL SMTP_HOST"

riga() {
  local kv="$1" ip="$2" etichetta="$3"
  echo "  --- $etichetta ($ip) ---"
  for k in $CHIAVI; do
    v=$(timeout 60 ssh -i "$kv" root@$ip "sed -n 's/^${k}=//p' /opt/registro_presenze/.env | head -1" 2>/dev/null | tr -d '\r\n')
    if [ -z "$v" ]; then
      printf "    %-18s (assente)\n" "$k"
    else
      h=$(printf '%s' "$v" | sha256sum | cut -c1-16)
      printf "    %-18s len=%-4s sha256=%s\n" "$k" "${#v}" "$h"
    fi
  done
}

riga ~/.ssh/id_ed25519_dev  192.168.178.133 DEV
riga ~/.ssh/id_ed25519_prod 192.168.178.132 PROD
