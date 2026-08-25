#!/bin/bash

# ============================================================
# Configuração do Tilix
#
# Configura o perfil padrão do Tilix com:
#
#   - Esquema de cores Dracula
#   - Cor de fundo: #282A36
#   - Cor do texto: #F8F8F2
#   - Paleta Dracula
#   - Transparência: 50%
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
# Identificação do componente
# ------------------------------------------------------------

COMPONENT_NAME="Tilix Configuration"

# ------------------------------------------------------------
# Schemas do Tilix
# ------------------------------------------------------------

TILIX_PROFILES_SCHEMA="com.gexperts.Tilix.ProfilesList"
TILIX_PROFILE_SCHEMA="com.gexperts.Tilix.Profile"
TILIX_SETTINGS_SCHEMA="com.gexperts.Tilix.Settings"

# ------------------------------------------------------------
# Configuração Dracula
# ------------------------------------------------------------

DRACULA_FOREGROUND="'#F8F8F2'"
DRACULA_BACKGROUND="'#282A36'"

# IMPORTANTE:
#
# A paleta é mantida em uma única linha porque o gsettings
# normaliza arrays dessa maneira ao executar "gsettings get".
#
# Isso permite validar corretamente o valor depois da gravação.

DRACULA_PALETTE="['#21222C', '#FF5555', '#50FA7B', '#F1FA8C', '#BD93F9', '#FF79C6', '#8BE9FD', '#F8F8F2', '#6272A4', '#FF6E6E', '#69FF94', '#FFFFA5', '#D6ACFF', '#FF92DF', '#A4FFFF', '#FFFFFF']"

# ------------------------------------------------------------
# Transparência
# ------------------------------------------------------------

TRANSPARENCY_PERCENT=50


echo
echo "============================================================"
echo " Configurando Tilix"
echo "============================================================"
echo


# ============================================================
# 1. Verificar se Tilix está instalado
# ============================================================

if ! command -v tilix >/dev/null 2>&1; then

    warn "Tilix não está instalado."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Tilix não instalado"

    exit 0

fi

info "Tilix localizado."


# ============================================================
# 2. Identificar usuário GNOME
# ============================================================

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


# ============================================================
# 3. Verificar sessão GNOME
# ============================================================

if ! gnome_session_available; then

    warn "Sessão GNOME do usuário ${GNOME_USER} não está disponível."

    warn "As preferências do Tilix não podem ser aplicadas"
    warn "enquanto não existir uma sessão gráfica ativa."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Sessão GNOME não disponível"

    exit 0

fi


# ============================================================
# 4. Verificar schema da lista de perfis
# ============================================================

info "Verificando schemas do Tilix..."

if ! gnome_schema_exists "$TILIX_PROFILES_SCHEMA"; then

    error "Schema não encontrado:"
    error "$TILIX_PROFILES_SCHEMA"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Schema ProfilesList não encontrado"

    exit 1

fi


# ============================================================
# 5. Descobrir perfil padrão
# ============================================================

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


# ============================================================
# 6. Construir schema relocatable do perfil
# ============================================================

PROFILE_PATH="/com/gexperts/Tilix/profiles/${PROFILE_UUID}/"

PROFILE_SCHEMA="${TILIX_PROFILE_SCHEMA}:${PROFILE_PATH}"

info "Schema do perfil:"
info "$PROFILE_SCHEMA"


# ============================================================
# 7. Verificar acesso ao perfil
# ============================================================

if ! gnome_gsettings list-keys \
    "$PROFILE_SCHEMA" \
    >/dev/null 2>&1; then

    error "Não foi possível acessar o perfil do Tilix:"
    error "$PROFILE_SCHEMA"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Perfil Tilix inacessível"

    exit 1

fi


# ============================================================
# 8. Verificar existência de uma chave
# ============================================================

tilix_key_exists() {

    local key="$1"

    gnome_gsettings list-keys \
        "$PROFILE_SCHEMA" |
        grep -Fxq "$key"
}


# ============================================================
# 9. Aplicar e validar configuração do perfil
# ============================================================

tilix_set() {

    local key="$1"
    local value="$2"

    # --------------------------------------------------------
    # Verificar existência da chave
    # --------------------------------------------------------

    if ! tilix_key_exists "$key"; then

        warn "Chave não encontrada no perfil do Tilix:"
        warn "$key"

        return 0

    fi

    # --------------------------------------------------------
    # Aplicar
    # --------------------------------------------------------

    info "Aplicando ${key} = ${value}"

    if ! gnome_gsettings set \
        "$PROFILE_SCHEMA" \
        "$key" \
        "$value"; then

        error "Falha ao configurar:"
        error "$key"

        return 1

    fi

    # --------------------------------------------------------
    # Ler valor novamente
    # --------------------------------------------------------

    local current

    current="$(
        gnome_gsettings get \
            "$PROFILE_SCHEMA" \
            "$key"
    )"

    # --------------------------------------------------------
    # Validar
    # --------------------------------------------------------

    if [[ "$current" != "$value" ]]; then

        error "Falha na validação de ${key}"
        error "Esperado : ${value}"
        error "Obtido   : ${current}"

        return 1

    fi

    success "${key} = ${current}"

    return 0
}


# ============================================================
# 10. Desabilitar cores herdadas do tema GTK
# ============================================================

info "Desabilitando cores herdadas do tema do sistema..."

tilix_set \
    "use-theme-colors" \
    "false"


# ============================================================
# 11. Aplicar esquema Dracula
# ============================================================

info "Aplicando esquema de cores Dracula..."

tilix_set \
    "foreground-color" \
    "$DRACULA_FOREGROUND"

tilix_set \
    "background-color" \
    "$DRACULA_BACKGROUND"


# ============================================================
# 12. Aplicar paleta Dracula
# ============================================================

info "Aplicando paleta Dracula..."

tilix_set \
    "palette" \
    "$DRACULA_PALETTE"


# ============================================================
# 13. Configurar transparência
# ============================================================

info "Configurando transparência em ${TRANSPARENCY_PERCENT}%..."

tilix_set \
    "background-transparency-percent" \
    "$TRANSPARENCY_PERCENT"


# ============================================================
# 14. Habilitar transparência global
# ============================================================

info "Verificando suporte global à transparência..."

if gnome_schema_exists "$TILIX_SETTINGS_SCHEMA"; then

    if gnome_gsettings list-keys \
        "$TILIX_SETTINGS_SCHEMA" |
        grep -Fxq "enable-transparency"; then

        info "Habilitando transparência global do Tilix..."

        gnome_gsettings_set \
            "$TILIX_SETTINGS_SCHEMA" \
            "enable-transparency" \
            "true"

    else

        warn "A versão instalada do Tilix não possui:"
        warn "enable-transparency"

    fi

else

    warn "Schema global do Tilix não encontrado:"
    warn "$TILIX_SETTINGS_SCHEMA"

fi


# ============================================================
# 15. Ler configurações finais
# ============================================================

FINAL_FOREGROUND="$(
    gnome_gsettings get \
        "$PROFILE_SCHEMA" \
        foreground-color
)"

FINAL_BACKGROUND="$(
    gnome_gsettings get \
        "$PROFILE_SCHEMA" \
        background-color
)"

FINAL_TRANSPARENCY="$(
    gnome_gsettings get \
        "$PROFILE_SCHEMA" \
        background-transparency-percent
)"


# ============================================================
# 16. Resultado
# ============================================================

echo
echo "============================================================"
echo " Tilix configurado"
echo "============================================================"
echo

echo "Usuário:"
echo "  ${GNOME_USER}"
echo

echo "Perfil padrão:"
echo "  ${PROFILE_UUID}"
echo

echo "Configurações:"
echo
echo "  Esquema             : Dracula"
echo "  Cor do texto        : ${FINAL_FOREGROUND}"
echo "  Cor de fundo        : ${FINAL_BACKGROUND}"
echo "  Transparência       : ${FINAL_TRANSPARENCY}%"
echo

success "Tilix configurado com sucesso."

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Dracula + transparência ${FINAL_TRANSPARENCY}%"

exit 0
