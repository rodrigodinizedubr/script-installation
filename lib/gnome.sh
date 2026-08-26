#!/bin/bash

# ============================================================
# Biblioteca comum para integração com GNOME
#
# Responsabilidades:
#
#   - identificar o usuário gráfico;
#   - localizar UID, GID, HOME, runtime e D-Bus;
#   - executar comandos no contexto correto do usuário;
#   - impedir vazamento de variáveis XDG do root;
#   - executar gsettings;
#   - executar gnome-extensions;
#   - reconhecer schemas normais;
#   - reconhecer schemas relocatable;
#   - verificar chaves;
#   - ler/aplicar/resetar valores;
#   - validar doubles com tolerância;
#   - habilitar/desabilitar extensões GNOME.
#
# ============================================================


# ============================================================
# 1. Proteção contra carregamento duplicado
# ============================================================

if [[ -n "${GNOME_LIB_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

GNOME_LIB_LOADED=1


# ============================================================
# 2. Funções internas de log
# ============================================================

_gnome_info() {

    if declare -F info >/dev/null 2>&1; then
        info "$@"
    else
        echo "[INFO] $*"
    fi
}


_gnome_warn() {

    if declare -F warn >/dev/null 2>&1; then
        warn "$@"
    else
        echo "[AVISO] $*" >&2
    fi
}


_gnome_error() {

    if declare -F error >/dev/null 2>&1; then
        error "$@"
    else
        echo "[ERRO] $*" >&2
    fi
}


_gnome_success() {

    if declare -F success >/dev/null 2>&1; then
        success "$@"
    else
        echo "[OK] $*"
    fi
}


# ============================================================
# 3. Detectar usuário da sessão GNOME
# ============================================================

gnome_detect_user() {

    local detected_user=""

    # --------------------------------------------------------
    # Prioridade 1:
    # usuário definido no config.conf
    # --------------------------------------------------------

    if [[ -n "${USUARIO:-}" &&
          "${USUARIO}" != "root" ]]; then

        if id "$USUARIO" >/dev/null 2>&1; then
            detected_user="$USUARIO"
        fi

    fi


    # --------------------------------------------------------
    # Prioridade 2:
    # usuário que chamou sudo
    # --------------------------------------------------------

    if [[ -z "$detected_user" &&
          -n "${SUDO_USER:-}" &&
          "${SUDO_USER}" != "root" ]]; then

        if id "$SUDO_USER" >/dev/null 2>&1; then
            detected_user="$SUDO_USER"
        fi

    fi


    # --------------------------------------------------------
    # Prioridade 3:
    # procurar sessão gráfica ativa
    # --------------------------------------------------------

    if [[ -z "$detected_user" ]] &&
       command -v loginctl >/dev/null 2>&1; then

        local session=""
        local candidate=""
        local active=""
        local type=""

        while read -r session _ candidate _; do

            [[ -z "$session" ]] && continue
            [[ -z "$candidate" ]] && continue
            [[ "$candidate" == "root" ]] && continue

            active="$(
                loginctl show-session \
                    "$session" \
                    -p Active \
                    --value \
                    2>/dev/null ||
                    true
            )"

            type="$(
                loginctl show-session \
                    "$session" \
                    -p Type \
                    --value \
                    2>/dev/null ||
                    true
            )"

            if [[ "$active" == "yes" &&
                  ( "$type" == "wayland" ||
                    "$type" == "x11" ) ]]; then

                detected_user="$candidate"
                break

            fi

        done < <(
            loginctl list-sessions \
                --no-legend \
                2>/dev/null
        )

    fi


    # --------------------------------------------------------
    # Validar resultado
    # --------------------------------------------------------

    if [[ -z "$detected_user" ]]; then

        _gnome_error \
            "Não foi possível identificar o usuário da sessão GNOME."

        return 1

    fi


    if ! id "$detected_user" >/dev/null 2>&1; then

        _gnome_error \
            "Usuário GNOME não existe: ${detected_user}"

        return 1

    fi


    # --------------------------------------------------------
    # Informações do usuário
    # --------------------------------------------------------

    GNOME_USER="$detected_user"

    GNOME_UID="$(
        id -u "$GNOME_USER"
    )"

    GNOME_GID="$(
        id -g "$GNOME_USER"
    )"

    GNOME_GROUP="$(
        id -gn "$GNOME_USER"
    )"

    GNOME_HOME="$(
        getent passwd "$GNOME_USER" |
        cut -d: -f6
    )"


    if [[ -z "$GNOME_HOME" ||
          ! -d "$GNOME_HOME" ]]; then

        _gnome_error \
            "HOME inválido para ${GNOME_USER}: ${GNOME_HOME:-<vazio>}"

        return 1

    fi


    # --------------------------------------------------------
    # Ambiente da sessão
    # --------------------------------------------------------

    GNOME_RUNTIME_DIR="/run/user/${GNOME_UID}"
    GNOME_DBUS_SOCKET="${GNOME_RUNTIME_DIR}/bus"


    # --------------------------------------------------------
    # Exportar
    # --------------------------------------------------------

    export GNOME_USER
    export GNOME_UID
    export GNOME_GID
    export GNOME_GROUP
    export GNOME_HOME
    export GNOME_RUNTIME_DIR
    export GNOME_DBUS_SOCKET

    return 0
}


# ============================================================
# 4. Verificar disponibilidade da sessão GNOME
# ============================================================

gnome_session_available() {

    if [[ -z "${GNOME_USER:-}" ]]; then

        if ! gnome_detect_user; then
            return 1
        fi

    fi


    if [[ ! -d "$GNOME_RUNTIME_DIR" ]]; then

        _gnome_error \
            "Runtime da sessão GNOME não encontrado: ${GNOME_RUNTIME_DIR}"

        return 1

    fi


    if [[ ! -S "$GNOME_DBUS_SOCKET" ]]; then

        _gnome_error \
            "D-Bus da sessão GNOME não encontrado: ${GNOME_DBUS_SOCKET}"

        return 1

    fi


    return 0
}


# ============================================================
# 5. Executar comando no contexto do usuário GNOME
# ============================================================

gnome_run() {

    gnome_session_available || return 1


    runuser -u "$GNOME_USER" -- env \
        -u XDG_DATA_HOME \
        -u XDG_DATA_DIRS \
        -u XDG_CONFIG_HOME \
        -u XDG_CONFIG_DIRS \
        -u XDG_CACHE_HOME \
        -u FLATPAK_ID \
        -u FLATPAK_SANDBOX_DIR \
        HOME="$GNOME_HOME" \
        USER="$GNOME_USER" \
        LOGNAME="$GNOME_USER" \
        XDG_RUNTIME_DIR="$GNOME_RUNTIME_DIR" \
        XDG_DATA_HOME="$GNOME_HOME/.local/share" \
        XDG_CONFIG_HOME="$GNOME_HOME/.config" \
        XDG_CACHE_HOME="$GNOME_HOME/.cache" \
        XDG_DATA_DIRS="/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:${GNOME_HOME}/.local/share/flatpak/exports/share" \
        XDG_CONFIG_DIRS="/etc/xdg" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=${GNOME_DBUS_SOCKET}" \
        "$@"
}


# ============================================================
# 6. Wrapper para gsettings
# ============================================================

gnome_gsettings() {

    if ! command -v gsettings >/dev/null 2>&1; then

        _gnome_error \
            "Comando gsettings não encontrado."

        return 1

    fi

    gnome_run gsettings "$@"
}


# ============================================================
# 7. Wrapper para gnome-extensions
# ============================================================

gnome_extensions() {

    if ! command -v gnome-extensions >/dev/null 2>&1; then

        _gnome_error \
            "Comando gnome-extensions não encontrado."

        return 1

    fi

    gnome_run gnome-extensions "$@"
}


# ============================================================
# 8. Obter nome-base de um schema
# ============================================================

gnome_schema_base_name() {

    local schema="$1"

    printf '%s\n' "${schema%%:*}"
}


# ============================================================
# 9. Verificar existência de schema
#
# Suporta:
#
#   Schema normal:
#
#     org.gnome.shell
#
#   Schema relocatable:
#
#     org.example.Schema:/caminho/
#
# Para schemas relocatable completos, a validação mais
# confiável é tentar acessar diretamente a instância através
# de "gsettings list-keys".
# ============================================================

gnome_schema_exists() {

    local schema="$1"

    if [[ -z "$schema" ]]; then

        _gnome_error \
            "Schema não informado."

        return 1

    fi


    # --------------------------------------------------------
    # Schema relocatable completo
    #
    # Exemplo:
    #
    # org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:
    # /org/gnome/settings-daemon/plugins/media-keys/
    # custom-keybindings/flameshot/
    # --------------------------------------------------------

    if [[ "$schema" == *:* ]]; then

        if gnome_gsettings \
            list-keys \
            "$schema" \
            >/dev/null 2>&1; then

            return 0

        fi

        return 1

    fi


    # --------------------------------------------------------
    # Schema normal
    # --------------------------------------------------------

    if gnome_gsettings \
        list-schemas \
        2>/dev/null |
        grep -Fxq "$schema"; then

        return 0

    fi


    # --------------------------------------------------------
    # Schema relocatable informado somente pelo nome-base
    # --------------------------------------------------------

    if gnome_gsettings \
        list-relocatable-schemas \
        2>/dev/null |
        grep -Fxq "$schema"; then

        return 0

    fi


    return 1
}


# ============================================================
# 10. Verificar existência de chave
#
# Para schemas relocatable deve ser usado o schema COMPLETO.
# ============================================================

gnome_key_exists() {

    local schema="$1"
    local key="$2"

    if [[ -z "$schema" ||
          -z "$key" ]]; then

        return 1

    fi


    gnome_gsettings \
        list-keys \
        "$schema" \
        2>/dev/null |
        grep -Fxq "$key"
}


# ============================================================
# 11. Verificar se valor é numérico
# ============================================================

gnome_is_number() {

    local value="$1"

    [[ "$value" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]
}


# ============================================================
# 12. Comparar valores numéricos com tolerância
# ============================================================

gnome_numeric_equal() {

    local expected="$1"
    local actual="$2"

    local tolerance="${3:-0.000000001}"


    awk \
        -v expected="$expected" \
        -v actual="$actual" \
        -v tolerance="$tolerance" \
        'BEGIN {

            difference = expected - actual

            if (difference < 0)
                difference = -difference

            if (difference <= tolerance)
                exit 0

            exit 1
        }'
}


# ============================================================
# 13. Ler configuração
# ============================================================

gnome_gsettings_get() {

    local schema="$1"
    local key="$2"


    if [[ -z "$schema" ||
          -z "$key" ]]; then

        _gnome_error \
            "Schema ou chave não informado."

        return 1

    fi


    gnome_gsettings \
        get \
        "$schema" \
        "$key"
}


# ============================================================
# 14. Aplicar e validar configuração
# ============================================================

gnome_gsettings_set() {

    local schema="$1"
    local key="$2"
    local value="$3"


    # --------------------------------------------------------
    # Validar argumentos
    # --------------------------------------------------------

    if [[ -z "$schema" ]]; then

        _gnome_error \
            "Schema não informado."

        return 1

    fi


    if [[ -z "$key" ]]; then

        _gnome_error \
            "Chave não informada."

        return 1

    fi


    # --------------------------------------------------------
    # Validar schema
    # --------------------------------------------------------

    if ! gnome_schema_exists "$schema"; then

        _gnome_error \
            "Schema GNOME não encontrado:"

        echo "       $schema" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Validar chave
    # --------------------------------------------------------

    if ! gnome_key_exists \
        "$schema" \
        "$key"; then

        _gnome_error \
            "Chave GNOME não encontrada:"

        echo "       ${schema}::${key}" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Aplicar
    # --------------------------------------------------------

    _gnome_info \
        "Aplicando ${schema}::${key} = ${value}"


    if ! gnome_gsettings \
        set \
        "$schema" \
        "$key" \
        "$value"; then

        _gnome_error \
            "Falha ao aplicar ${schema}::${key}."

        return 1

    fi


    # --------------------------------------------------------
    # Ler novamente
    # --------------------------------------------------------

    local current

    current="$(
        gnome_gsettings \
            get \
            "$schema" \
            "$key" \
            2>/dev/null
    )"


    # --------------------------------------------------------
    # Validar números
    # --------------------------------------------------------

    if gnome_is_number "$value" &&
       gnome_is_number "$current"; then

        if ! gnome_numeric_equal \
            "$value" \
            "$current"; then

            _gnome_error \
                "Validação numérica divergente para ${schema}::${key}."

            _gnome_error \
                "Esperado: ${value}"

            _gnome_error \
                "Obtido:   ${current}"

            return 1

        fi


    # --------------------------------------------------------
    # Demais tipos
    # --------------------------------------------------------

    else

        if [[ "$current" != "$value" ]]; then

            _gnome_error \
                "Validação divergente para ${schema}::${key}."

            _gnome_error \
                "Esperado: ${value}"

            _gnome_error \
                "Obtido:   ${current:-<vazio>}"

            return 1

        fi

    fi


    _gnome_success \
        "${key} = ${current}"

    return 0
}


# ============================================================
# 15. Resetar configuração
# ============================================================

gnome_gsettings_reset() {

    local schema="$1"
    local key="$2"


    if [[ -z "$schema" ||
          -z "$key" ]]; then

        _gnome_error \
            "Schema ou chave não informado."

        return 1

    fi


    if ! gnome_schema_exists "$schema"; then

        _gnome_error \
            "Schema GNOME não encontrado: ${schema}"

        return 1

    fi


    if ! gnome_key_exists "$schema" "$key"; then

        _gnome_error \
            "Chave GNOME não encontrada: ${schema}::${key}"

        return 1

    fi


    _gnome_info \
        "Resetando ${schema}::${key}"


    gnome_gsettings \
        reset \
        "$schema" \
        "$key"
}


# ============================================================
# 16. Verificar extensão GNOME
# ============================================================

gnome_extension_exists() {

    local uuid="$1"


    if [[ -z "$uuid" ]]; then
        return 1
    fi


    gnome_extensions \
        list \
        2>/dev/null |
        grep -Fxq "$uuid"
}


# ============================================================
# 17. Verificar se extensão está habilitada
# ============================================================

gnome_extension_enabled() {

    local uuid="$1"


    if [[ -z "$uuid" ]]; then
        return 1
    fi


    if ! gnome_extension_exists "$uuid"; then
        return 1
    fi


    gnome_extensions \
        list \
        --enabled \
        2>/dev/null |
        grep -Fxq "$uuid"
}


# ============================================================
# 18. Habilitar extensão GNOME
# ============================================================

gnome_extension_enable() {

    local uuid="$1"


    if [[ -z "$uuid" ]]; then

        _gnome_error \
            "UUID da extensão GNOME não informado."

        return 1

    fi


    if ! gnome_extension_exists "$uuid"; then

        _gnome_warn \
            "Extensão GNOME não encontrada: ${uuid}"

        return 1

    fi


    if gnome_extension_enabled "$uuid"; then

        _gnome_success \
            "Extensão já habilitada: ${uuid}"

        return 0

    fi


    _gnome_info \
        "Habilitando extensão: ${uuid}"


    if ! gnome_extensions \
        enable \
        "$uuid"; then

        _gnome_error \
            "Não foi possível habilitar a extensão: ${uuid}"

        return 1

    fi


    if gnome_extension_enabled "$uuid"; then

        _gnome_success \
            "Extensão habilitada: ${uuid}"

        return 0

    fi


    _gnome_warn \
        "A extensão foi habilitada, mas o GNOME ainda não confirmou o estado."

    _gnome_warn \
        "Pode ser necessário logout/login."

    return 1
}


# ============================================================
# 19. Desabilitar extensão
# ============================================================

gnome_extension_disable() {

    local uuid="$1"


    if [[ -z "$uuid" ]]; then

        _gnome_error \
            "UUID da extensão GNOME não informado."

        return 1

    fi


    if ! gnome_extension_exists "$uuid"; then

        _gnome_warn \
            "Extensão GNOME não encontrada: ${uuid}"

        return 1

    fi


    if ! gnome_extension_enabled "$uuid"; then

        _gnome_success \
            "Extensão já está desabilitada: ${uuid}"

        return 0

    fi


    _gnome_info \
        "Desabilitando extensão: ${uuid}"


    if ! gnome_extensions \
        disable \
        "$uuid"; then

        _gnome_error \
            "Não foi possível desabilitar a extensão: ${uuid}"

        return 1

    fi


    if ! gnome_extension_enabled "$uuid"; then

        _gnome_success \
            "Extensão desabilitada: ${uuid}"

        return 0

    fi


    _gnome_error \
        "Não foi possível confirmar a desativação: ${uuid}"

    return 1
}


# ============================================================
# 20. Obter estado de extensão
# ============================================================

gnome_extension_state() {

    local uuid="$1"


    if [[ -z "$uuid" ]]; then
        return 1
    fi


    if ! gnome_extension_exists "$uuid"; then
        return 1
    fi


    gnome_extensions \
        info \
        "$uuid" \
        2>/dev/null |
        awk -F': ' \
            '/State:/ {
                print $2
                exit
            }'
}


# ============================================================
# 21. Exibir informações da sessão
# ============================================================

gnome_session_info() {

    if ! gnome_detect_user; then
        return 1
    fi


    echo
    echo "============================================================"
    echo " Sessão GNOME"
    echo "============================================================"
    echo

    echo "Usuário:"
    echo "  ${GNOME_USER}"
    echo

    echo "UID:"
    echo "  ${GNOME_UID}"
    echo

    echo "GID:"
    echo "  ${GNOME_GID}"
    echo

    echo "Grupo:"
    echo "  ${GNOME_GROUP}"
    echo

    echo "HOME:"
    echo "  ${GNOME_HOME}"
    echo

    echo "XDG_RUNTIME_DIR:"
    echo "  ${GNOME_RUNTIME_DIR}"
    echo

    echo "D-Bus:"
    echo "  ${GNOME_DBUS_SOCKET}"
    echo


    if gnome_session_available; then

        echo "Estado:"
        echo "  DISPONÍVEL"

    else

        echo "Estado:"
        echo "  INDISPONÍVEL"

        return 1

    fi


    echo

    return 0
}


# ============================================================
# 22. Testar comunicação com GSettings
# ============================================================

gnome_test_gsettings() {

    if ! gnome_session_available; then
        return 1
    fi


    _gnome_info \
        "Testando comunicação com GSettings..."


    if gnome_gsettings \
        list-schemas \
        >/dev/null 2>&1; then

        _gnome_success \
            "Comunicação com GSettings funcionando."

        return 0

    fi


    _gnome_error \
        "Não foi possível comunicar com GSettings."

    return 1
}


# ============================================================
# 23. Testar schema
# ============================================================

gnome_test_schema() {

    local schema="$1"


    if [[ -z "$schema" ]]; then

        _gnome_error \
            "Schema não informado."

        return 1

    fi


    local base_schema

    base_schema="$(
        gnome_schema_base_name "$schema"
    )"


    echo
    echo "Schema solicitado:"
    echo "  $schema"
    echo

    echo "Schema base:"
    echo "  $base_schema"
    echo


    if gnome_schema_exists "$schema"; then

        _gnome_success \
            "Schema encontrado."

        return 0

    fi


    _gnome_error \
        "Schema não encontrado."

    return 1
}


# ============================================================
# 24. Fim
# ============================================================

return 0 2>/dev/null || true