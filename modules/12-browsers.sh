#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "${INSTALAR_CHROME:-false}" != true ] && [ "${INSTALAR_OPERA:-false}" != true ]; then
    mark_skipped "Navegadores opcionais desabilitados (Chrome e Opera)."
    exit 0
fi

if [ "$INSTALAR_CHROME" = true ]; then
    info "Instalando Google Chrome"

    if command_exists google-chrome; then
        info "Google Chrome já está instalado."
        record_component_status "JA_EXISTIA" "Google Chrome" "Executável encontrado"
    else
        if wget -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb; then
            if dpkg -i /tmp/google-chrome.deb || apt --fix-broken install -y; then
                record_component_status "INSTALADO" "Google Chrome" "Instalação concluída"
            else
                record_component_status "FALHA" "Google Chrome" "dpkg/apt retornou erro"
                return 1 2>/dev/null || exit 1
            fi
        else
            warn "Não foi possível baixar o Google Chrome. Verifique a conexão com a Internet."
            warn "A execução continuará para os próximos módulos."
            record_component_status "FALHA" "Google Chrome" "Falha no download"
        fi
    fi
else
    warn "Instalação do Google Chrome ignorada."
    mark_component_skipped "Google Chrome" "INSTALAR_CHROME=false"
fi

if [ "$INSTALAR_OPERA" = true ]; then
    info "Instalando Opera"

    if [ -n "$OPERA_DEB" ] && [ -f "$OPERA_DEB" ]; then
        if dpkg -i "$OPERA_DEB" || apt --fix-broken install -y; then
            record_component_status "INSTALADO" "Opera" "Instalação concluída"
        else
            record_component_status "FALHA" "Opera" "dpkg/apt retornou erro"
        fi
    else
        warn "Arquivo .deb do Opera não encontrado. Configure OPERA_DEB em config.conf."
        record_component_status "FALHA" "Opera" "Arquivo .deb não encontrado"
    fi
else
    warn "Instalação do Opera ignorada."
    mark_component_skipped "Opera" "INSTALAR_OPERA=false"
fi
