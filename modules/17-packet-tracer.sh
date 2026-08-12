#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "$INSTALAR_PACKET_TRACER" != true ]; then
    warn "Instalação do Cisco Packet Tracer ignorada."
    exit 0
fi

info "Instalando Cisco Packet Tracer"

if [ -n "$PACKET_TRACER_DEB" ] && [ -f "$PACKET_TRACER_DEB" ]; then
    dpkg -i "$PACKET_TRACER_DEB" || apt --fix-broken install -y
else
    warn "Arquivo .deb do Packet Tracer não encontrado."
    warn "Baixe manualmente pelo Cisco Skills For All e configure PACKET_TRACER_DEB em config.conf."
fi
