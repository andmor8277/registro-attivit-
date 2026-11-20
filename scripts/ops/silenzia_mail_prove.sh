#!/bin/bash
# Fa SCARTARE a postfix i destinatari di prova, invece di smistarli alla Gmail del titolare.
#
# Perche' esiste
# --------------
# L'app non parla con Gmail: consegna al postfix locale (SMTP_HOST, porta 25) e la bandierina
# `email_inviata` si alza appena postfix ACCETTA il messaggio. Il relay verso Gmail e' un passo
# successivo, tutto di postfix. I test di creazione utente usano destinatari inesistenti
# (`@x.local`), quindi ogni esecuzione della suite DEV produceva due bounce
# "Indirizzo non trovato / DNS ... NXDOMAIN" nella casella del titolare: 24 in quattordici giorni,
# piu' due su PROD. Quella prova non e' mai passata da cio' che il test vuole verificare.
#
# Con `discard:` il test resta verde per il motivo giusto (postfix accetta, email_inviata=True)
# e il messaggio viene buttato invece di essere smistato: niente Gmail, niente bounce.
#
# Cosa finisce nella lista, e perche' non tutta
# ---------------------------------------------
# Un dominio si mette qui solo se puo' essere raggiunto DAI SOLI TEST. Per questo `prova.it`
# (usato in test_token_pubblico.sh) NON c'e': e' un dominio reale e un socio vero potrebbe
# averlo, e scartarlo vorrebbe dire far perdere mail legittime a una persona.
#
# Cosa si perde, e va detto
# -------------------------
# `discard:` registra comunque `status=sent` nel log di postfix, con scritto "Message discarded".
# Per questi domini, quindi, quelle righe NON sono piu' prova di consegna reale: la prova
# end-to-end delle credenziali Gmail e del relay si fa con un invio VOLUTO a un indirizzo reale
# che il titolare legge, non di sfuggita dietro alla suite quotidiana.
#
# Uso: scripts/ops/silenzia_mail_prove.sh dev|prod [--dry-run]

AMBIENTE="$1"
shift || true
DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *) echo "Argomento non valido: $a" >&2; echo "Uso: $0 dev|prod [--dry-run]" >&2; exit 2 ;;
  esac
done

case "$AMBIENTE" in
  dev)  SSH="ssh -i $HOME/.ssh/id_ed25519_dev -o ConnectTimeout=15 root@192.168.178.133" ;;
  prod) SSH="ssh -i $HOME/.ssh/id_ed25519_prod -o ConnectTimeout=15 root@192.168.178.132" ;;
  *) echo "Uso: $0 dev|prod [--dry-run]" >&2; exit 2 ;;
esac

# Solo domini che non possono appartenere a una persona reale
DISCARD="x.local test.local example.com"

echo "=== $AMBIENTE: stato attuale del postfix ==="
$SSH 'postconf -n 2>/dev/null | grep -iE "^(transport_maps|relayhost|default_transport)" || echo "  transport_maps: non impostato"; echo "  /etc/postfix/transport:"; if [ -f /etc/postfix/transport ]; then sed "s/^/    /" /etc/postfix/transport; else echo "    (assente)"; fi'

if [ "$DRY" = "1" ]; then
  echo
  echo "--- DRY RUN: scriverei queste righe in /etc/postfix/transport ---"
  for d in $DISCARD; do echo "  $d    discard:"; done
  echo "  e transport_maps = hash:/etc/postfix/transport"
  echo "  poi: postmap /etc/postfix/transport && systemctl reload postfix"
  exit 0
fi

echo
echo "=== $AMBIENTE: applico ==="
# Il file viene creato per accumulo, non sovrascritto: se un domani qualcuno ci mette una rotta
# vera per un altro dominio, non la cancelliamo.
$SSH bash -s <<EOF
set -e
touch /etc/postfix/transport
for d in $DISCARD; do
  if grep -qE "^[[:space:]]*\$d[[:space:]]" /etc/postfix/transport; then
    echo "  gia' presente: \$d"
  else
    printf '%s    discard:\n' "\$d" >> /etc/postfix/transport
    echo "  aggiunto:      \$d"
  fi
done
postmap /etc/postfix/transport
postconf -e 'transport_maps = hash:/etc/postfix/transport'
systemctl reload postfix 2>/dev/null || postfix reload
echo
echo "=== verifica: postfix deve rispondere 'discard:' a ciascun dominio ==="
for d in $DISCARD; do
  r=\$(postmap -q "\$d" hash:/etc/postfix/transport 2>/dev/null)
  if [ "\$r" = "discard:" ]; then echo "  OK   \$d -> \$r"; else echo "  FAIL \$d -> '\$r'"; fi
done
echo "  transport_maps = \$(postconf -h transport_maps)"
EOF

echo
echo "Per provarlo davvero: bash scripts/test/test_creazione_utente.sh e poi"
echo "  journalctl --since -2min | grep -a 'postfix/smtp' | grep -a x.local"
echo "Devono comparire righe 'Message discarded' e NESSUN relay verso smtp.gmail.com per x.local."
