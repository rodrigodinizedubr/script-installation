#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/lib/common.sh"

info "Configurando .bashrc do root para ls colorido"
ROOT_BASHRC="/root/.bashrc"

touch "$ROOT_BASHRC"

if ! grep -q "LS_OPTIONS='--color=auto'" "$ROOT_BASHRC"; then
cat >> "$ROOT_BASHRC" <<'EOF_BASHRC'

# ls colorido
export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias la='ls $LS_OPTIONS -la'
EOF_BASHRC
fi

info ".bashrc do root configurado."
