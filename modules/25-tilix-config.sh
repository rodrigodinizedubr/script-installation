#!/bin/bash

# ============================================================
# Configuração do Tilix
# Perfil padrão:
#   - Esquema de cores Dracula
#   - Transparência 50%
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"
source "${ROOT_DIR}/lib/gnome.sh"

COMPONENT_NAME="Tilix Configuration"

TILIX_PROFILES_SCHEMA="com.gexperts.Tilix.ProfilesList"
TILIX_PROFILE_SCHEMA="com.gexperts.Tilix.Profile"

# ------------------------------------------------------------
# Dracula
# ------------------------------------------------------------

DRACULA_FOREGROUND="'#F8F8F2'"
DRACULA_BACKGROUND="'#282A36'"

DRACULA_PALETTE="[
'#21222C',
'#FF5555',
'#50FA7B',
'#F1FA8C',
'#BD93F9',
'#FF79C6',
'#8BE9FD',
'#F8F8F2',
'#6272A4',
'#FF6E6E',
'#69FF94',
'#FFFFA5',
'#D6ACFF',
'#FF92DF',
'#A4FFFF',
'#FFFFFF'
]"

TRANSPARENCY_PERCENT=50


echo
echo "============================================================"
echo " Configurando Tilix"
echo "============================================================"
echo


# ------------------------------------------------------------
# Verificar instalação
# ------------------------------------------------------------

if ! command -v tilix >/dev/null 2>&1; then

    warn "Tilix não está instalado."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Tilix não instalado"

    exit 0

fi

info "Tilix localizado."


# ------------------------------------------------------------
# Identificar usuário GNOME
# ------------------------------------------------------------

if ! gnome_detect_user; then

    error "Não foi possível identificar o usuário GNOME."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Usuário GNOME não identificado"

    exit 1

fi

info "Usuário GNOME: ${GNOME_USER}"
info "UID: ${GNOME_UID}"


# ------------------------------------------------------------
# Verificar sessão GNOME
# ------------------------------------------------------------

if ! gnome_session_available; then

    warn "Sessão GNOME do usuário ${GNOME_USER} não está disponível."
    warn "As preferências do Tilix não podem ser aplicadas agora."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Sessão GNOME não disponível"

    exit 0

fi


# ------------------------------------------------------------
# Verificar schemas do Tilix
# ------------------------------------------------------------

if ! gnome_schema_exists "$TILIX_PROFILES_SCHEMA"; then

    error "Schema não encontrado:"
    error "$TILIX_PROFILES_SCHEMA"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Schema ProfilesList não encontrado"

    exit 1

fi


# ------------------------------------------------------------
# Descobrir perfil padrão
# ------------------------------------------------------------

info "Localizando perfil padrão do Tilix..."

PROFILE_UUID="$(
    gnome_gsettings get \
        "$TILIX_PROFILES_SCHEMA" \
        default |
    tr -d "'"
)"

if [[ -z "$PROFILE_UUID" ]]; then

    error "Não foi possível determinar o perfil padrão do Tilix."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Perfil padrão não encontrado"

    exit 1

fi

info "Perfil padrão localizado:"
info "$PROFILE_UUID"


# ------------------------------------------------------------
# Montar schema relocatable
# ------------------------------------------------------------

PROFILE_PATH="/com/gexperts/Tilix/profiles/${PROFILE_UUID}/"

PROFILE_SCHEMA="${TILIX_PROFILE_SCHEMA}:${PROFILE_PATH}"

info "Schema do perfil:"
info "$PROFILE_SCHEMA"


# ------------------------------------------------------------
# Verificar se schema relocatable funciona
# ------------------------------------------------------------

if ! gnome_gsettings list-keys "$PROFILE_SCHEMA" >/dev/null 2>&1; then

    error "Não foi possível acessar o perfil do Tilix:"
    error "$PROFILE_SCHEMA"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Perfil Tilix inacessível"

    exit 1

fi


# ------------------------------------------------------------
# Função local para aplicar configuração
# ------------------------------------------------------------

tilix_set() {

    local key="$1"
    local value="$2"

    info "Aplicando ${key} = ${value}"

    if ! gnome_gsettings set \
        "$PROFILE_SCHEMA" \
        "$key" \
        "$value"; then

        error "Falha ao configurar:"
        error "${key}"

        return 1

    fi

    local current

    current="$(
        gnome_gsettings get \
            "$PROFILE_SCHEMA" \
            "$key"
    )"

    if [[ "$current" != "$value" ]]; then

        error "Falha na validação de ${key}"
        error "Esperado : ${value}"
        error "Obtido   : ${current}"

        return 1

    fi

    success "${key} = ${current}"

}


# ------------------------------------------------------------
# Desabilitar cores do tema GTK
# ------------------------------------------------------------

tilix_set \
    "use-theme-colors" \
    "false"


# ------------------------------------------------------------
# Aplicar cores Dracula
# ------------------------------------------------------------

info "Aplicando esquema de cores Dracula..."

tilix_set \
    "foreground-color" \
    "$DRACULA_FOREGROUND"

tilix_set \
    "background-color" \
    "$DRACULA_BACKGROUND"


# ------------------------------------------------------------
# Aplicar paleta Dracula
# ------------------------------------------------------------

info "Aplicando paleta Dracula..."

tilix_set \
    "palette" \
    "$DRACULA_PALETTE"


# ------------------------------------------------------------
# Configurar transparência
# ------------------------------------------------------------

info "Configurando transparência em ${TRANSPARENCY_PERCENT}%..."

tilix_set \
    "background-transparency-percent" \
    "$TRANSPARENCY_PERCENT"


# ------------------------------------------------------------
# Habilitar transparência global do Tilix
# ------------------------------------------------------------

if gnome_gsettings list-keys \
    "com.gexperts.Tilix.Settings" |
    grep -Fxq "enable-transparency"; then

    info "Habilitando suporte global à transparência..."

    gnome_gsettings_set \
        "com.gexperts.Tilix.Settings" \
        "enable-transparency" \
        "true"

fi


# ------------------------------------------------------------
# Resultado
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Tilix configurado"
echo "============================================================"
echo

echo "Perfil:"
echo "  ${PROFILE_UUID}"
echo
echo "Configurações:"
echo "  Esquema             : Dracula"
echo "  Cor de fundo        : #282A36"
echo "  Cor do texto        : #F8F8F2"
echo "  Transparência       : 50%"
echo

success "Tilix configurado com sucesso."

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Dracula + transparência 50%"
