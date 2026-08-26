#!/bin/bash

# ============================================================
# Configuração do Dash to Dock
#
# Configura:
#
#   - Mostrar em todos os monitores
#   - Posição à esquerda
#   - Ocultação inteligente desabilitada
#   - Ocultação automática desabilitada
#   - Dock sempre visível
#   - Tamanho limite do dock em 72%
#   - Modo painel habilitado
#   - Tamanho máximo dos ícones em 32 px
#   - Encolher Dash habilitado
#   - Transparência fixa
#   - Opacidade em 0%
#
# As configurações são aplicadas ao usuário da sessão GNOME
# através da biblioteca lib/gnome.sh.
# ============================================================

set -e

# ------------------------------------------------------------
# Diretórios do projeto
# ------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ------------------------------------------------------------
# Bibliotecas
# ------------------------------------------------------------

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"
source "${ROOT_DIR}/lib/gnome.sh"

# ------------------------------------------------------------
# Configurações
# ------------------------------------------------------------

COMPONENT_NAME="Dash to Dock"

EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"
SCHEMA="org.gnome.shell.extensions.dash-to-dock"


echo
echo "============================================================"
echo " Configurando Dash to Dock"
echo "============================================================"
echo


# ============================================================
# 1. Verificar GNOME
# ============================================================

if ! command -v gnome-shell >/dev/null 2>&1; then

    warn "GNOME Shell não foi encontrado."
    warn "O Dash to Dock será ignorado."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "GNOME Shell não encontrado"

    exit 0

fi

GNOME_VERSION="$(gnome-shell --version 2>/dev/null || true)"

info "GNOME detectado:"
info "${GNOME_VERSION:-versão não identificada}"


# ============================================================
# 2. Instalar Dash to Dock
# ============================================================

info "Verificando instalação do Dash to Dock..."

install_package gnome-shell-extension-dashtodock

# Pacote que fornece a interface gráfica de configuração
# das extensões GNOME em distribuições Debian.
install_package gnome-shell-extension-prefs

success "Pacotes do Dash to Dock instalados."


# ============================================================
# 3. Identificar usuário GNOME
# ============================================================

if ! gnome_detect_user; then

    error "Não foi possível identificar o usuário da sessão GNOME."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Usuário GNOME não identificado"

    exit 1

fi

info "Usuário GNOME: ${GNOME_USER}"
info "UID: ${GNOME_UID}"


# ============================================================
# 4. Verificar sessão gráfica
# ============================================================

if ! gnome_session_available; then

    warn "A sessão GNOME do usuário ${GNOME_USER} não está disponível."
    warn "O Dash to Dock foi instalado, mas não pode ser configurado agora."

    echo
    warn "Entre na sessão gráfica do usuário e execute novamente:"
    echo
    echo "    sudo bash modules/24-dash-to-dock.sh"
    echo

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Instalado; sessão GNOME não disponível"

    exit 0

fi


# ============================================================
# 5. Verificar schema do Dash to Dock
# ============================================================

info "Verificando schema do Dash to Dock..."

if ! gnome_schema_exists "$SCHEMA"; then

    warn "O schema do Dash to Dock ainda não está disponível:"
    warn "$SCHEMA"

    echo
    warn "Isso pode acontecer quando a extensão foi instalada"
    warn "durante uma sessão GNOME já iniciada."
    echo
    warn "Encerre a sessão GNOME e entre novamente."
    warn "Depois execute este módulo novamente."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Instalado; schema ainda não carregado"

    exit 0

fi

success "Schema do Dash to Dock localizado."


# ============================================================
# 6. Verificar existência das chaves necessárias
# ============================================================

dash_key_exists() {

    local key="$1"

    gnome_gsettings list-keys "$SCHEMA" |
        grep -Fxq "$key"
}


# ============================================================
# 7. Aplicar configuração
# ============================================================

dash_set() {

    local key="$1"
    local value="$2"

    # --------------------------------------------------------
    # Verificar se a chave existe nesta versão
    # --------------------------------------------------------

    if ! dash_key_exists "$key"; then

        warn "Chave não encontrada no Dash to Dock:"
        warn "$key"

        return 0

    fi

    # --------------------------------------------------------
    # Aplicar através da biblioteca comum
    # --------------------------------------------------------

    gnome_gsettings_set \
        "$SCHEMA" \
        "$key" \
        "$value"
}


# ============================================================
# 8. Mostrar em todos os monitores
# ============================================================

info "Configurando suporte a múltiplos monitores..."

dash_set \
    "multi-monitor" \
    "true"


# ============================================================
# 9. Posição na tela
# ============================================================

info "Configurando posição do dock..."

dash_set \
    "dock-position" \
    "'LEFT'"


# ============================================================
# 10. Desabilitar ocultação inteligente
# ============================================================

info "Desabilitando ocultação inteligente..."

dash_set \
    "intellihide" \
    "false"


# ============================================================
# 11. Desabilitar ocultação automática
# ============================================================

info "Desabilitando ocultação automática..."

dash_set \
    "autohide" \
    "false"


# ============================================================
# 12. Manter dock sempre visível
# ============================================================

info "Mantendo dock sempre visível..."

dash_set \
    "dock-fixed" \
    "true"


# ============================================================
# 13. Tamanho limite do dock
# ============================================================

info "Configurando tamanho limite do dock em 72%..."

dash_set \
    "height-fraction" \
    "0.72"


# ============================================================
# 14. Modo painel
# ============================================================

info "Habilitando modo painel..."

dash_set \
    "extend-height" \
    "true"


# ============================================================
# 15. Tamanho máximo dos ícones
# ============================================================

info "Configurando tamanho máximo dos ícones em 32 px..."

dash_set \
    "dash-max-icon-size" \
    "32"


# ============================================================
# 16. Encolher o Dash
# ============================================================

info "Habilitando opção Encolher o Dash..."

dash_set \
    "custom-theme-shrink" \
    "true"


# ============================================================
# 17. Transparência fixa
# ============================================================

info "Configurando transparência como fixa..."

dash_set \
    "transparency-mode" \
    "'FIXED'"


# ============================================================
# 18. Opacidade
# ============================================================

info "Configurando opacidade em 0%..."

dash_set \
    "background-opacity" \
    "0.0"


# ============================================================
# 19. Habilitar extensão
# ============================================================

echo
info "Verificando se a extensão está carregada pelo GNOME..."

EXTENSION_LOADED=false

if gnome_extensions list 2>/dev/null |
    grep -Fxq "$EXTENSION_UUID"; then

    EXTENSION_LOADED=true

fi


if [[ "$EXTENSION_LOADED" == true ]]; then

    info "Extensão localizada:"
    info "$EXTENSION_UUID"

    # --------------------------------------------------------
    # Verificar estado atual
    # --------------------------------------------------------

    EXTENSION_STATE="$(
        gnome_extensions info "$EXTENSION_UUID" 2>/dev/null |
        awk -F': ' '/State:/ {print $2}' |
        head -n 1
    )"

    if [[ "$EXTENSION_STATE" == "ENABLED" ]]; then

        success "Dash to Dock já está habilitado."

    else

        info "Habilitando Dash to Dock..."

        if gnome_extensions enable "$EXTENSION_UUID"; then

            success "Dash to Dock habilitado."

        else

            warn "Não foi possível habilitar a extensão nesta sessão."
            warn "Pode ser necessário fazer logout/login."

        fi

    fi

else

    warn "O GNOME ainda não carregou a extensão:"
    warn "$EXTENSION_UUID"

    echo
    warn "As preferências já foram gravadas."
    warn "Faça logout e login para carregar a extensão."

fi


# ============================================================
# 20. Ler configurações finais
# ============================================================

echo
info "Validando configurações finais..."

FINAL_MULTI_MONITOR="$(
    gnome_gsettings get \
        "$SCHEMA" \
        multi-monitor
)"

FINAL_POSITION="$(
    gnome_gsettings get \
        "$SCHEMA" \
        dock-position
)"

FINAL_INTELLIHIDE="$(
    gnome_gsettings get \
        "$SCHEMA" \
        intellihide
)"

FINAL_AUTOHIDE="$(
    gnome_gsettings get \
        "$SCHEMA" \
        autohide
)"

FINAL_DOCK_FIXED="$(
    gnome_gsettings get \
        "$SCHEMA" \
        dock-fixed
)"

FINAL_HEIGHT="$(
    gnome_gsettings get \
        "$SCHEMA" \
        height-fraction
)"

FINAL_EXTEND_HEIGHT="$(
    gnome_gsettings get \
        "$SCHEMA" \
        extend-height
)"

FINAL_ICON_SIZE="$(
    gnome_gsettings get \
        "$SCHEMA" \
        dash-max-icon-size
)"

FINAL_SHRINK="$(
    gnome_gsettings get \
        "$SCHEMA" \
        custom-theme-shrink
)"

FINAL_TRANSPARENCY_MODE="$(
    gnome_gsettings get \
        "$SCHEMA" \
        transparency-mode
)"

FINAL_BACKGROUND_OPACITY="$(
    gnome_gsettings get \
        "$SCHEMA" \
        background-opacity
)"


# ============================================================
# 21. Resultado
# ============================================================

echo
echo "============================================================"
echo " Dash to Dock configurado"
echo "============================================================"
echo

echo "Usuário:"
echo "  ${GNOME_USER}"
echo

echo "Configurações:"
echo
echo "  Mostrar em todos os monitores : ${FINAL_MULTI_MONITOR}"
echo "  Posição                       : ${FINAL_POSITION}"
echo "  Ocultação inteligente         : ${FINAL_INTELLIHIDE}"
echo "  Ocultação automática          : ${FINAL_AUTOHIDE}"
echo "  Dock sempre visível           : ${FINAL_DOCK_FIXED}"
echo "  Tamanho limite                : ${FINAL_HEIGHT}"
echo "  Modo painel                   : ${FINAL_EXTEND_HEIGHT}"
echo "  Tamanho máximo dos ícones     : ${FINAL_ICON_SIZE} px"
echo "  Encolher Dash                 : ${FINAL_SHRINK}"
echo "  Transparência                 : ${FINAL_TRANSPARENCY_MODE}"
echo "  Opacidade                     : ${FINAL_BACKGROUND_OPACITY}"
echo


# ============================================================
# 22. Registrar resultado
# ============================================================

if [[ "$EXTENSION_LOADED" == true ]]; then

    success "Dash to Dock configurado com sucesso."

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Configurado para ${GNOME_USER}"

else

    warn "Preferências configuradas."
    warn "A extensão será carregada após novo login no GNOME."

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Preferências configuradas; novo login pode ser necessário"

fi


exit 0