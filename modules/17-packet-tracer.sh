#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "$INSTALAR_PACKET_TRACER" != true ]; then
    mark_skipped "Instalação do Cisco Packet Tracer desabilitada (INSTALAR_PACKET_TRACER=false)."
    exit 0
fi

info "Instalando Cisco Packet Tracer"

if [ -n "$PACKET_TRACER_DEB" ] && [ -f "$PACKET_TRACER_DEB" ]; then
    if dpkg -i "$PACKET_TRACER_DEB" || apt --fix-broken install -y; then
        record_component_status "INSTALADO" "Cisco Packet Tracer" "Pacote instalado"
    else
        record_component_status "FALHA" "Cisco Packet Tracer" "dpkg/apt retornou erro"
        exit 1
    fi
else
    warn "Arquivo .deb do Packet Tracer não encontrado."
    warn "Baixe manualmente pelo Cisco Skills For All e configure PACKET_TRACER_DEB em config.conf."
    record_component_status "FALHA" "Cisco Packet Tracer" "Arquivo .deb não encontrado"
    exit 1
fi
