#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Instalando e configurando Wireshark"
ensure_user_exists "$USUARIO"

echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

install_package wireshark

groupadd wireshark || true
usermod -aG wireshark "$USUARIO"

if [ -f /usr/bin/dumpcap ]; then
    chgrp wireshark /usr/bin/dumpcap
    chmod 750 /usr/bin/dumpcap
    setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
    getcap /usr/bin/dumpcap
else
    warn "/usr/bin/dumpcap não encontrado."
fi

info "Wireshark configurado. Será necessário fazer logout/login para atualizar grupos do usuário."
