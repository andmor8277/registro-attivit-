#!/usr/bin/env bash
# Riallinea i cloni remoti (DEV e PROD) alla storia git riscritta con git-filter-repo.
#
# Dopo la riscrittura del 2026-11-13 i vecchi SHA non esistono piu': i cloni sui
# server hanno ancora ref e oggetti della storia precedente, incluso il keystore
# rimosso dalla storia. Questo script:
#   1. fetch forzato di branch e tag (refspec con '+' per accettare il non-ff)
#   2. mostra le modifiche locali non committate PRIMA di distruggerle
#   3. git reset --hard origin/master
#   4. reflog expire + gc --prune=now per cancellare gli oggetti vecchi
#   5. verifica che il keystore non esista piu' nel clone
#
# Non tocca i container: dopo il riallineamento serve un deploy normale
# (./deploy.sh o ./deploy_dev.sh), che va lanciato solo con autorizzazione esplicita.
#
# Uso:
#   ./scripts/realigna_cloni.sh            # entrambi i server
#   ./scripts/realigna_cloni.sh prod       # solo PROD
#   ./scripts/realigna_cloni.sh dev        # solo DEV
#   ./scripts/realigna_cloni.sh --dry-run  # mostra solo cosa succedera'

set -euo pipefail

REMOTE_PATH="/opt/registro_presenze"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE_PATH="frontend/android/app/thof-release.keystore"

DRY_RUN=0
TARGETS=()
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        prod|dev)    TARGETS+=("$arg") ;;
        *) echo "Argomento non valido: $arg" >&2; exit 2 ;;
    esac
done
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(prod dev)

host_of()  { [ "$1" = "prod" ] && echo "192.168.178.132" || echo "192.168.178.133"; }
key_of()   { [ "$1" = "prod" ] && echo "$HOME/.ssh/id_ed25519_prod" || echo "$HOME/.ssh/id_ed25519_dev"; }

# L'atteso viene dal clone locale: se locale e remoto non coincidono, il server non e' allineato.
git -C "$REPO_ROOT" fetch --quiet origin || { echo "fetch locale fallito" >&2; exit 1; }
EXPECTED="$(git -C "$REPO_ROOT" rev-parse origin/master)"
echo "Storia attesa (origin/master locale): ${EXPECTED:0:7}"
echo

rc_totale=0
for env in "${TARGETS[@]}"; do
    host="$(host_of "$env")"
    key="$(key_of "$env")"
    ssh_cmd=(ssh -i "$key" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "root@$host")

    echo "=== [$env] $host ==="
    if ! "${ssh_cmd[@]}" "true" 2>/dev/null; then
        echo "  ✗ non raggiungibile via SSH (stato: skippato)"
        rc_totale=1
        continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        "${ssh_cmd[@]}" "cd $REMOTE_PATH && \
            echo '  HEAD attuale : '\$(git rev-parse --short HEAD) && \
            echo '  origin/master: '\$(git rev-parse --short origin/master 2>/dev/null || echo '(nessuno)') && \
            echo '  modifiche locali non committate: '\$(git status --porcelain | wc -l) && \
            echo '  commit che contengono il keystore: '\$(git log --all --oneline -- $KEYSTORE_PATH | wc -l)"
        echo "  (dry-run: nessuna modifica applicata)"
        echo
        continue
    fi

    # 1) fetch forzato di branch + tag
    "${ssh_cmd[@]}" "cd $REMOTE_PATH && git fetch --prune --tags --force origin '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*'" >/dev/null

    # 2) mostra cosa si sta per sovrascrivere
    local_mods="$("${ssh_cmd[@]}" "cd $REMOTE_PATH && git status --porcelain | wc -l")"
    echo "  modifiche locali non committate: $local_mods"
    if [ "$local_mods" != "0" ]; then
        echo "  --- file che verranno sovrascritti dal reset --hard ---"
        "${ssh_cmd[@]}" "cd $REMOTE_PATH && git status --porcelain" | sed 's/^/    /'
    fi

    # 3) reset alla storia riscritta
    "${ssh_cmd[@]}" "cd $REMOTE_PATH && git checkout -f master >/dev/null 2>&1 || true; git reset --hard origin/master" | sed 's/^/  /'

    # 4) rimuove gli oggetti della storia precedente
    "${ssh_cmd[@]}" "cd $REMOTE_PATH && git reflog expire --expire=now --all && git gc --prune=now --quiet" >/dev/null

    # 5) verifica
    head_now="$("${ssh_cmd[@]}" "cd $REMOTE_PATH && git rev-parse HEAD")"
    ks="$("${ssh_cmd[@]}" "cd $REMOTE_PATH && git log --all --oneline -- $KEYSTORE_PATH | wc -l")"
    if [ "$head_now" = "$EXPECTED" ] && [ "$ks" = "0" ]; then
        echo "  ✓ HEAD = ${head_now:0:7}  (coincide)   keystore nella storia: 0"
    else
        echo "  ✗ HEAD = ${head_now:0:7}  atteso ${EXPECTED:0:7}   keystore nella storia: $ks"
        rc_totale=1
    fi
    echo "  nota: i file ormai non piu' tracciati (releases/, $KEYSTORE_PATH) restano su disco;"
    echo "        per rimuoverli: ssh -i $key root@$host 'cd $REMOTE_PATH && rm -rf releases $KEYSTORE_PATH'"
    echo
done

if [ "$rc_totale" -eq 0 ]; then
    echo "✓ Tutti i cloni riallineati. Ricorda: il deploy va lanciato a parte e solo con autorizzazione esplicita."
else
    echo "⚠ Alcuni server non sono stati riallineati (vedi sopra). Riprova quando sono raggiungibili."
fi
exit $rc_totale
