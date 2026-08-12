#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "$CONFIGURAR_IP" != true ]; then
    mark_skipped "Configuração de IP desabilitada (CONFIGURAR_IP=false)."
    exit 0
fi

info "Configurando rede em /etc/network/interfaces"
backup_file /etc/network/interfaces

if [ "$TIPO_IP" = "dhcp" ]; then
cat > /etc/network/interfaces <<EOF_DHCP
auto lo
iface lo inet loopback

allow-hotplug $INTERFACE_REDE
iface $INTERFACE_REDE inet dhcp
EOF_DHCP
elif [ "$TIPO_IP" = "static" ]; then
cat > /etc/network/interfaces <<EOF_STATIC
auto lo
iface lo inet loopback

allow-hotplug $INTERFACE_REDE
iface $INTERFACE_REDE inet static
address $IP_ADDRESS
netmask $NETMASK
network $NETWORK
broadcast $BROADCAST
gateway $GATEWAY
EOF_STATIC
else
    error "TIPO_IP inválido: $TIPO_IP. Use dhcp ou static."
    exit 1
fi

warn "Reinicie o sistema para aplicar a configuração de rede."
