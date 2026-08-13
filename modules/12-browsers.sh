#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"


# ============================================================
# Instalar CHROME
# ============================================================

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

# ============================================================
# Instalar Opera
# ============================================================

if [ "${INSTALAR_OPERA:-false}" = true ]; then

    info "Configurando repositório do Opera"

    install -m 0755 -d /etc/apt/keyrings

    wget -qO /tmp/opera.gpg \
        https://deb.opera.com/archive.key

    gpg --dearmor \
        < /tmp/opera.gpg \
        > /etc/apt/keyrings/opera.gpg

    chmod a+r /etc/apt/keyrings/opera.gpg

    cat > /etc/apt/sources.list.d/opera.sources <<EOF
Types: deb
URIs: https://deb.opera.com/opera-stable/
Suites: stable
Components: non-free
Signed-By: /etc/apt/keyrings/opera.gpg
EOF

    apt update

    info "Instalando Opera"

    apt install -y opera-stable

    if command -v opera >/dev/null 2>&1; then
        info "Opera instalado com sucesso."

        if declare -F registrar_componente >/dev/null 2>&1; then
            registrar_componente \
                "INSTALADO" \
                "Opera" \
                "Instalação concluída"
        fi
    else
        error "Opera não foi localizado após a instalação."

        if declare -F registrar_componente >/dev/null 2>&1; then
            registrar_componente \
                "FALHA" \
                "Opera" \
                "Executável não encontrado após instalação"
        fi

        exit 1
    fi

else

    info "Instalação do Opera desabilitada."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "IGNORADO" \
            "Opera" \
            "INSTALAR_OPERA=false"
    fi

fi
