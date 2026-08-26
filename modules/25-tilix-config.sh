#!/bin/bash

# ============================================================
# Configuração do Tilix
#
# Este módulo:
#
#   - identifica o usuário GNOME;
#   - localiza o perfil padrão do Tilix;
#   - aplica o esquema Dracula;
#   - configura transparência em 50%;
#   - verifica/install libvte-2.91-common;
#   - localiza o script de integração VTE;
#   - configura ~/.bashrc de forma idempotente;
#   - evita duplicação de configuração;
#   - corrige owner/permissões do .bashrc;
#   - valida as configurações aplicadas.
#
# ============================================================

set -e


# ============================================================
# 1. Diretórios do projeto
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
# 3. Identificação
# ============================================================

COMPONENT_NAME="Tilix Configuration"


# ============================================================
# 4. Schemas Tilix
# ============================================================

TILIX_PROFILES_SCHEMA="com.gexperts.Tilix.ProfilesList"
TILIX_PROFILE_SCHEMA="com.gexperts.Tilix.Profile"
TILIX_SETTINGS_SCHEMA="com.gexperts.Tilix.Settings"


# ============================================================
# 5. Dracula
# ============================================================

DRACULA_FOREGROUND="'#F8F8F2'"

DRACULA_BACKGROUND="'#282A36'"

DRACULA_PALETTE="['#21222C', '#FF5555', '#50FA7B', '#F1FA8C', '#BD93F9', '#FF79C6', '#8BE9FD', '#F8F8F2', '#6272A4', '#FF6E6E', '#69FF94', '#FFFFA5', '#D6ACFF', '#FF92DF', '#A4FFFF', '#FFFFFF']"

TRANSPARENCY_PERCENT=50


# ============================================================
# 6. Marcadores usados no ~/.bashrc
# ============================================================

VTE_BLOCK_BEGIN="# >>> TILIX VTE INTEGRATION >>>"
VTE_BLOCK_END="# <<< TILIX VTE INTEGRATION <<<"


echo
echo "============================================================"
echo " Configurando Tilix"
echo "============================================================"
echo


# ============================================================
# 7. Verificar Tilix
# ============================================================

if ! command -v tilix >/dev/null 2>&1; then

    warn "Tilix não está instalado."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Tilix não instalado"

    exit 0

fi


success "Tilix localizado."


# ============================================================
# 8. Identificar usuário GNOME
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

info "HOME:"
info "$GNOME_HOME"


# ============================================================
# 9. Verificar sessão GNOME
# ============================================================

if ! gnome_session_available; then

    warn "Sessão GNOME de ${GNOME_USER} não disponível."

    warn "As preferências gráficas do Tilix não podem"
    warn "ser aplicadas neste momento."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Sessão GNOME não disponível"

    exit 0

fi


# ============================================================
# 10. Instalar suporte VTE
# ============================================================

info "Verificando suporte VTE..."

install_package libvte-2.91-common


# ============================================================
# 11. Localizar script VTE
#
# Debian pode disponibilizar:
#
#   /etc/profile.d/vte.sh
#
# ou:
#
#   /etc/profile.d/vte-2.91.sh
#
# Também fazemos uma busca de fallback.
# ============================================================

VTE_SCRIPT=""


if [[ -r /etc/profile.d/vte.sh ]]; then

    VTE_SCRIPT="/etc/profile.d/vte.sh"

elif [[ -r /etc/profile.d/vte-2.91.sh ]]; then

    VTE_SCRIPT="/etc/profile.d/vte-2.91.sh"

else

    VTE_SCRIPT="$(
        find /etc/profile.d \
            -maxdepth 1 \
            -type f \
            -name 'vte*.sh' \
            -readable \
            2>/dev/null |
        head -n 1
    )"

fi


if [[ -n "$VTE_SCRIPT" ]]; then

    success "Script VTE localizado:"
    info "$VTE_SCRIPT"

else

    warn "Nenhum script VTE foi localizado em /etc/profile.d."

fi


# ============================================================
# 12. Configurar integração VTE no .bashrc
# ============================================================

BASHRC="${GNOME_HOME}/.bashrc"


# ------------------------------------------------------------
# Criar .bashrc caso não exista
# ------------------------------------------------------------

if [[ ! -f "$BASHRC" ]]; then

    info "Criando:"
    info "$BASHRC"

    touch "$BASHRC"

    chown \
        "${GNOME_USER}:${GNOME_USER}" \
        "$BASHRC"

fi


# ------------------------------------------------------------
# Remover bloco anterior, caso exista
#
# Isso deixa a operação idempotente.
# ------------------------------------------------------------

if grep -Fq "$VTE_BLOCK_BEGIN" "$BASHRC"; then

    info "Configuração VTE anterior encontrada."
    info "Atualizando bloco existente..."

    TEMP_BASHRC="$(
        mktemp
    )"


    awk \
        -v begin="$VTE_BLOCK_BEGIN" \
        -v end="$VTE_BLOCK_END" \
        '
        $0 == begin {
            skip = 1
            next
        }

        $0 == end {
            skip = 0
            next
        }

        !skip {
            print
        }
        ' \
        "$BASHRC" \
        > "$TEMP_BASHRC"


    cat "$TEMP_BASHRC" > "$BASHRC"

    rm -f "$TEMP_BASHRC"

fi


# ============================================================
# 13. Adicionar configuração VTE
# ============================================================

if [[ -n "$VTE_SCRIPT" ]]; then

    info "Configurando integração VTE no .bashrc..."

    cat >> "$BASHRC" <<EOF

${VTE_BLOCK_BEGIN}

# ------------------------------------------------------------
# Integração Tilix / VTE
#
# Necessária para recursos como:
#
#   - atualização correta do diretório atual;
#   - integração entre panes;
#   - funcionamento adequado do shell no Tilix.
#
# Gerenciado automaticamente por:
#
#   25-tilix-config.sh
# ------------------------------------------------------------

if [ -n "\${TILIX_ID:-}" ] || [ -n "\${VTE_VERSION:-}" ]; then

    if [ -r "${VTE_SCRIPT}" ]; then
        source "${VTE_SCRIPT}"
    fi

fi

${VTE_BLOCK_END}
EOF


    success "Integração VTE adicionada ao .bashrc."

else

    warn "Integração VTE não adicionada porque"
    warn "nenhum script VTE foi localizado."

fi


# ============================================================
# 14. Corrigir proprietário do .bashrc
# ============================================================

chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$BASHRC"


# ============================================================
# 15. Verificar schema da lista de perfis
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
# 16. Descobrir perfil padrão
# ============================================================

info "Localizando perfil padrão do Tilix..."


PROFILE_UUID="$(
    gnome_gsettings get \
        "$TILIX_PROFILES_SCHEMA" \
        default |
    tr -d "'"
)"


if [[ -z "$PROFILE_UUID" ]]; then

    error "Não foi possível determinar o perfil padrão."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Perfil padrão não encontrado"

    exit 1

fi


success "Perfil padrão localizado:"
info "$PROFILE_UUID"


# ============================================================
# 17. Montar schema relocatable
# ============================================================

PROFILE_PATH="/com/gexperts/Tilix/profiles/${PROFILE_UUID}/"

PROFILE_SCHEMA="${TILIX_PROFILE_SCHEMA}:${PROFILE_PATH}"


info "Schema do perfil:"
info "$PROFILE_SCHEMA"


# ============================================================
# 18. Validar acesso ao perfil
# ============================================================

if ! gnome_gsettings \
    list-keys \
    "$PROFILE_SCHEMA" \
    >/dev/null 2>&1; then

    error "Não foi possível acessar o perfil Tilix."

    error "$PROFILE_SCHEMA"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Perfil Tilix inacessível"

    exit 1

fi


# ============================================================
# 19. Verificar chave do perfil
# ============================================================

tilix_key_exists() {

    local key="$1"

    gnome_gsettings \
        list-keys \
        "$PROFILE_SCHEMA" |
        grep -Fxq "$key"
}


# ============================================================
# 20. Aplicar configuração do perfil
# ============================================================

tilix_set() {

    local key="$1"
    local value="$2"


    if ! tilix_key_exists "$key"; then

        warn "Chave não encontrada:"
        warn "$key"

        return 0

    fi


    info "Aplicando ${key} = ${value}"


    if ! gnome_gsettings \
        set \
        "$PROFILE_SCHEMA" \
        "$key" \
        "$value"; then

        error "Falha ao configurar:"
        error "$key"

        return 1

    fi


    local current

    current="$(
        gnome_gsettings \
            get \
            "$PROFILE_SCHEMA" \
            "$key"
    )"


    # --------------------------------------------------------
    # Comparação numérica
    # --------------------------------------------------------

    if gnome_is_number "$value" &&
       gnome_is_number "$current"; then

        if ! gnome_numeric_equal \
            "$value" \
            "$current"; then

            error "Validação numérica falhou:"
            error "$key"

            error "Esperado: $value"
            error "Obtido:   $current"

            return 1

        fi


    # --------------------------------------------------------
    # Outros tipos
    # --------------------------------------------------------

    else

        if [[ "$current" != "$value" ]]; then

            error "Validação falhou:"
            error "$key"

            error "Esperado: $value"
            error "Obtido:   $current"

            return 1

        fi

    fi


    success "${key} = ${current}"

    return 0
}


# ============================================================
# 21. Desabilitar cores do tema GTK
# ============================================================

info "Desabilitando cores herdadas do tema do sistema..."


tilix_set \
    "use-theme-colors" \
    "false"


# ============================================================
# 22. Aplicar Dracula
# ============================================================

info "Aplicando esquema Dracula..."


tilix_set \
    "foreground-color" \
    "$DRACULA_FOREGROUND"


tilix_set \
    "background-color" \
    "$DRACULA_BACKGROUND"


tilix_set \
    "palette" \
    "$DRACULA_PALETTE"


# ============================================================
# 23. Transparência
# ============================================================

info "Configurando transparência em ${TRANSPARENCY_PERCENT}%..."


tilix_set \
    "background-transparency-percent" \
    "$TRANSPARENCY_PERCENT"


# ============================================================
# 24. Transparência global
# ============================================================

if gnome_schema_exists "$TILIX_SETTINGS_SCHEMA"; then

    if gnome_key_exists \
        "$TILIX_SETTINGS_SCHEMA" \
        "enable-transparency"; then

        info "Habilitando transparência global do Tilix..."


        gnome_gsettings_set \
            "$TILIX_SETTINGS_SCHEMA" \
            "enable-transparency" \
            "true"

    fi

fi


# ============================================================
# 25. Ler valores finais
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
# 26. Verificar bloco VTE
# ============================================================

VTE_CONFIGURED=false


if [[ -n "$VTE_SCRIPT" ]] &&
   grep -Fq "$VTE_BLOCK_BEGIN" "$BASHRC"; then

    VTE_CONFIGURED=true

fi


# ============================================================
# 27. Resultado
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

echo "Integração VTE:"
echo

if [[ "$VTE_CONFIGURED" == true ]]; then

    echo "  Estado               : CONFIGURADA"
    echo "  Script               : ${VTE_SCRIPT}"
    echo "  Arquivo               : ${BASHRC}"

else

    echo "  Estado               : NÃO CONFIGURADA"

fi

echo


# ============================================================
# 28. Orientação
# ============================================================

if [[ "$VTE_CONFIGURED" == true ]]; then

    info "A integração VTE será carregada em novos shells."

    info "Feche todas as janelas do Tilix e abra novamente."

fi


# ============================================================
# 29. Registrar componente
# ============================================================

if [[ "$VTE_CONFIGURED" == true ]]; then

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Dracula + transparência ${FINAL_TRANSPARENCY}% + VTE"

else

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Dracula + transparência ${FINAL_TRANSPARENCY}%"

fi


success "Tilix configurado com sucesso."

exit 0