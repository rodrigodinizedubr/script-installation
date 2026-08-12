#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Instalando e configurando Tilix"
ensure_user_exists "$USUARIO"

install_package tilix

wget -O /tmp/Dracula.json https://raw.githubusercontent.com/dracula/tilix/master/Dracula.json
mkdir -p /usr/share/tilix/schemes
cp /tmp/Dracula.json /usr/share/tilix/schemes/

BASHRC="/home/$USUARIO/.bashrc"
touch "$BASHRC"

if [ -f /etc/profile.d/vte.sh ]; then
    if ! grep -q "Tilix / VTE" "$BASHRC"; then
cat >> "$BASHRC" <<'EOF_VTE'

# Tilix / VTE
if [ -n "$TILIX_ID" ] || [ -n "$VTE_VERSION" ]; then
    source /etc/profile.d/vte.sh
fi
EOF_VTE
    fi
else
    warn "/etc/profile.d/vte.sh não encontrado."
fi

chown "$USUARIO:$USUARIO" "$BASHRC"
info "Tilix configurado. O tema Dracula deve ser selecionado pela interface do Tilix."
