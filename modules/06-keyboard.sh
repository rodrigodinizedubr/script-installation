#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/lib/common.sh"

info "Configurando teclado brasileiro"
backup_file /etc/default/keyboard

cat > /etc/default/keyboard <<'EOF_KEYBOARD'
XKBMODEL="pc105"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF_KEYBOARD

info "Teclado configurado como br/pc105."
