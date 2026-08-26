#!/bin/bash

# ============================================================
# Configuração do Flameshot
#
# Corrige o funcionamento no GNOME + Wayland usando:
#
#   QT_QPA_PLATFORM=wayland flameshot gui
#
# Também cria um atalho personalizado do GNOME.
# ============================================================

set -e


# ============================================================
# 1. Diretórios
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"


# ============================================================
# 2. Bibliotecas
# ============================================================

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"
source "${ROOT_DIR}/lib/gnome.sh"


# ============================================================
# 3. Configurações
# ============================================================

COMPONENT_NAME="Flameshot"

CUSTOM_KEYS_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_BINDING_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"

CUSTOM_BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"

CUSTOM_BINDING_SCHEMA_PATH="${CUSTOM_BINDING_SCHEMA}:${CUSTOM_BINDING_PATH}"

SHORTCUT="<Shift>Print"


echo
echo "============================================================"
echo " Configurando Flameshot"
echo "============================================================"
echo


# ============================================================
# 4. Instalar pacotes
# ============================================================

info "Verificando instalação do Flameshot..."

install_package flameshot

install_package xdg-desktop-portal
install_package xdg-desktop-portal-gnome

success "Pacotes necessários instalados."


# ============================================================
# 5. Identificar usuário GNOME
# ============================================================

if ! gnome_detect_user; then

    error "Não foi possível identificar o usuário GNOME."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Usuário GNOME não identificado"

    exit 1
fi


info "Usuário GNOME:"
info "$GNOME_USER"

info "UID:"
info "$GNOME_UID"


# ============================================================
# 6. Verificar sessão GNOME
# ============================================================

if ! gnome_session_available; then

    warn "Sessão GNOME não disponível."
    warn "O Flameshot foi instalado, mas o atalho não pode"
    warn "ser configurado neste momento."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Instalado; sessão GNOME não disponível"

    exit 0
fi


# ============================================================
# 7. Detectar tipo da sessão
# ============================================================

SESSION_TYPE="$(
    loginctl show-session \
        "$(
            loginctl list-sessions --no-legend |
            awk -v user="$GNOME_USER" '$3 == user {print $1; exit}'
        )" \
        -p Type \
        --value \
        2>/dev/null ||
        true
)"


info "Tipo da sessão:"
info "${SESSION_TYPE:-desconhecido}"


# ============================================================
# 8. Definir comando do Flameshot
# ============================================================

if [[ "$SESSION_TYPE" == "wayland" ]]; then

    FLAMESHOT_COMMAND="bash -c 'QT_QPA_PLATFORM=wayland flameshot gui'"

else

    FLAMESHOT_COMMAND="flameshot gui"

fi


info "Comando configurado:"
info "$FLAMESHOT_COMMAND"


# ============================================================
# 9. Verificar schemas
# ============================================================

if ! gnome_schema_exists "$CUSTOM_KEYS_SCHEMA"; then

    error "Schema de atalhos GNOME não encontrado:"
    error "$CUSTOM_KEYS_SCHEMA"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Schema de atalhos não encontrado"

    exit 1
fi


# ============================================================
# 10. Obter atalhos personalizados existentes
# ============================================================

CURRENT_BINDINGS="$(
    gnome_gsettings get \
        "$CUSTOM_KEYS_SCHEMA" \
        custom-keybindings
)"


# ============================================================
# 11. Adicionar Flameshot à lista de atalhos
# ============================================================

if [[ "$CURRENT_BINDINGS" == "@as []" ||
      "$CURRENT_BINDINGS" == "[]" ]]; then

    NEW_BINDINGS="['${CUSTOM_BINDING_PATH}']"

else

    if echo "$CURRENT_BINDINGS" |
        grep -Fq "$CUSTOM_BINDING_PATH"; then

        NEW_BINDINGS="$CURRENT_BINDINGS"

    else

        NEW_BINDINGS="$(
            printf '%s' "$CURRENT_BINDINGS" |
            sed "s/]$/, '${CUSTOM_BINDING_PATH}']/"
        )"

    fi

fi


info "Configurando lista de atalhos personalizados..."

gnome_gsettings set \
    "$CUSTOM_KEYS_SCHEMA" \
    custom-keybindings \
    "$NEW_BINDINGS"


# ============================================================
# 12. Configurar nome
# ============================================================

gnome_gsettings set \
    "$CUSTOM_BINDING_SCHEMA_PATH" \
    name \
    "'Flameshot'"


# ============================================================
# 13. Configurar comando
# ============================================================

gnome_gsettings set \
    "$CUSTOM_BINDING_SCHEMA_PATH" \
    command \
    "\"${FLAMESHOT_COMMAND}\""


# ============================================================
# 14. Configurar tecla
# ============================================================

gnome_gsettings set \
    "$CUSTOM_BINDING_SCHEMA_PATH" \
    binding \
    "'${SHORTCUT}'"


# ============================================================
# 15. Validar
# ============================================================

FINAL_NAME="$(
    gnome_gsettings get \
        "$CUSTOM_BINDING_SCHEMA_PATH" \
        name
)"

FINAL_COMMAND="$(
    gnome_gsettings get \
        "$CUSTOM_BINDING_SCHEMA_PATH" \
        command
)"

FINAL_BINDING="$(
    gnome_gsettings get \
        "$CUSTOM_BINDING_SCHEMA_PATH" \
        binding
)"


echo
echo "============================================================"
echo " Flameshot configurado"
echo "============================================================"
echo

echo "Usuário:"
echo "  ${GNOME_USER}"
echo

echo "Sessão:"
echo "  ${SESSION_TYPE:-desconhecida}"
echo

echo "Atalho:"
echo "  ${FINAL_BINDING}"
echo

echo "Comando:"
echo "  ${FINAL_COMMAND}"
echo


# ============================================================
# 16. Resultado
# ============================================================

success "Flameshot configurado com sucesso."

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Atalho ${SHORTCUT} configurado"

exit 0