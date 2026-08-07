#!/bin/sh
# The Home of Football — installa i git hook di sicurezza
# Crea il symlink in .git/hooks/pre-commit verso scripts/git-hooks/pre-commit
# e, se manca, un secrets.lst di esempio (riempilo con i tuoi segreti reali).

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.git/hooks"
ln -sf ../../scripts/git-hooks/pre-commit "$ROOT/.git/hooks/pre-commit"

HOOK_LIST="$ROOT/scripts/git-hooks/secrets.lst"
if [ ! -f "$HOOK_LIST" ]; then
  cat > "$HOOK_LIST" <<'EOF'
# Segreti da bloccare nei commit (ogni riga = una stringa, letterale).
# NB: questo file NON va committato (è in .gitignore).
# Quando ruoti una credenziale, aggiorna questa lista con quella nuova.
EOF
  chmod 600 "$HOOK_LIST"
  echo "Creato $HOOK_LIST vuoto. Inserisci i tuoi segreti reali (non committarlo)."
fi

echo "Hook pre-commit installato in $ROOT/.git/hooks/pre-commit"
ls -l "$ROOT/.git/hooks/pre-commit"