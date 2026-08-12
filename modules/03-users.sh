#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Configurando usuário sudo"
ensure_user_exists "$USUARIO"

install_package sudo
install_package nano

usermod -aG sudo "$USUARIO"

cat > "/etc/sudoers.d/$USUARIO" <<EOF_SUDO
$USUARIO ALL=(ALL) ALL
EOF_SUDO

chmod 440 "/etc/sudoers.d/$USUARIO"
visudo -cf "/etc/sudoers.d/$USUARIO"

info "Usuário $USUARIO adicionado ao grupo sudo."
