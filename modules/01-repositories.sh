#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Configurando repositórios APT de acordo com a versão instalada"

if [ ! -f /etc/os-release ]; then
    error "Arquivo /etc/os-release não encontrado."
    exit 1
fi

source /etc/os-release
CODENAME="${VERSION_CODENAME:-}"

if [ -z "$CODENAME" ]; then
    error "Não foi possível identificar VERSION_CODENAME em /etc/os-release."
    exit 1
fi

info "Versão detectada: $CODENAME"
backup_file /etc/apt/sources.list

cat > /etc/apt/sources.list <<EOF_REPOS
deb http://deb.debian.org/debian $CODENAME main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $CODENAME main contrib non-free non-free-firmware

deb http://deb.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free non-free-firmware
EOF_REPOS

info "Repositórios configurados em /etc/apt/sources.list"
