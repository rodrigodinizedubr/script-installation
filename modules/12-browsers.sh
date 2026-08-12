#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "$INSTALAR_CHROME" = true ]; then
    info "Instalando Google Chrome"

    if command_exists google-chrome; then
        info "Google Chrome já está instalado."
    else
        if wget -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb; then
            dpkg -i /tmp/google-chrome.deb || apt --fix-broken install -y
        else
            warn "Não foi possível baixar o Google Chrome. Verifique a conexão com a Internet."
            warn "A execução continuará para os próximos módulos."
        fi
    fi
else
    warn "Instalação do Google Chrome ignorada."
fi

if [ "$INSTALAR_OPERA" = true ]; then
    info "Instalando Opera"

    if [ -n "$OPERA_DEB" ] && [ -f "$OPERA_DEB" ]; then
        dpkg -i "$OPERA_DEB" || apt --fix-broken install -y
    else
        warn "Arquivo .deb do Opera não encontrado. Configure OPERA_DEB em config.conf."
    fi
else
    warn "Instalação do Opera ignorada."
fi
