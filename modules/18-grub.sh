#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "$CONFIGURAR_GRUB" != true ]; then
    mark_skipped "Configuração do GRUB desabilitada (CONFIGURAR_GRUB=false)."
    exit 0
fi

if [ ! -f "$GRUB_BACKGROUND_IMAGE" ]; then
    error "Imagem do GRUB não encontrada: $GRUB_BACKGROUND_IMAGE"
    exit 1
fi

info "Configurando background do GRUB"
backup_file /etc/default/grub

if grep -q "^GRUB_BACKGROUND=" /etc/default/grub; then
    sed -i "s|^GRUB_BACKGROUND=.*|GRUB_BACKGROUND=\"$GRUB_BACKGROUND_IMAGE\"|" /etc/default/grub
else
    echo "GRUB_BACKGROUND=\"$GRUB_BACKGROUND_IMAGE\"" >> /etc/default/grub
fi

if grep -q "^GRUB_COLOR_NORMAL=" /etc/default/grub; then
    sed -i 's|^GRUB_COLOR_NORMAL=.*|GRUB_COLOR_NORMAL="light-gray/transparent"|' /etc/default/grub
else
    echo 'GRUB_COLOR_NORMAL="light-gray/transparent"' >> /etc/default/grub
fi

update-grub
