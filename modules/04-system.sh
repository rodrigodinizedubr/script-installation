#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Configurando hostname"

if [ -z "$HOSTNAME_NOVO" ]; then
    error "HOSTNAME_NOVO está vazio em config.conf."
    exit 1
fi

hostnamectl set-hostname "$HOSTNAME_NOVO"

backup_file /etc/hosts

if grep -q "^127.0.1.1" /etc/hosts; then
    sed -i "s/^127.0.1.1.*/127.0.1.1\t$HOSTNAME_NOVO/" /etc/hosts
else
    echo -e "127.0.1.1\t$HOSTNAME_NOVO" >> /etc/hosts
fi

info "Hostname configurado para: $HOSTNAME_NOVO"
