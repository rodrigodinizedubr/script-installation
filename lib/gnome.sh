#!/bin/bash

# ============================================================
# Biblioteca comum para configurações GNOME
#
# Responsabilidades:
#
#   - Identificar o usuário da sessão GNOME
#   - Identificar UID e HOME
#   - Localizar XDG_RUNTIME_DIR
#   - Localizar D-Bus da sessão
#   - Executar comandos como usuário gráfico
#   - Isolar o ambiente XDG do root
#   - Executar gsettings
#   - Executar gnome-extensions
#   - Verificar schemas
#   - Verificar chaves
#   - Aplicar configurações gsettings
#   - Validar valores gravados
#   - Comparar valores numéricos com tolerância
#
# Utilizado por:
#
#   22-disable-screen-lock.sh
#   23-gnome-favorites.sh
#   24-dash-to-dock.sh
#   25-tilix-config.sh
#
# ============================================================


# ============================================================
# 1. Evitar carregamento duplicado
# ============================================================

if [[ -n "${GNOME_LIB_LOADED:-}" ]]; then
    return 0
fi

GNOME_LIB_LOADED=1


# ============================================================
# 2. Identificar usuário GNOME
# ============================================================

gnome_detect_user() {

    local detected_user=""

    # --------------------------------------------------------
    # Prioridade 1:
    # usuário definido no config.conf do projeto
    #
    # Exemplo:
    #
    #   USUARIO="operador"
    #
    # Essa é a prioridade principal porque o projeto pode ser
    # executado por outro administrador usando sudo.
    # --------------------------------------------------------

    if [[ -n "${USUARIO:-}" && "${USUARIO}" != "root" ]]; then

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
    # procurar sessão gráfica ativa através do loginctl
    # --------------------------------------------------------

    if [[ -z "$detected_user" ]] &&
       command -v loginctl >/dev/null 2>&1; then

        local session
        local candidate
        local active
        local type

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
    # Nenhum usuário encontrado
    # --------------------------------------------------------

    if [[ -z "$detected_user" ]]; then

        echo "[ERRO] Não foi possível identificar o usuário GNOME." >&2

        return 1

    fi


    # --------------------------------------------------------
    # Validar usuário
    # --------------------------------------------------------

    if ! id "$detected_user" >/dev/null 2>&1; then

        echo "[ERRO] Usuário GNOME não existe:" >&2
        echo "       $detected_user" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Obter informações
    # --------------------------------------------------------

    GNOME_USER="$detected_user"

    GNOME_UID="$(
        id -u "$GNOME_USER"
    )"

    GNOME_HOME="$(
        getent passwd "$GNOME_USER" |
        cut -d: -f6
    )"


    # --------------------------------------------------------
    # Validar HOME
    # --------------------------------------------------------

    if [[ -z "$GNOME_HOME" ||
          ! -d "$GNOME_HOME" ]]; then

        echo "[ERRO] HOME do usuário GNOME inválido:" >&2
        echo "       ${GNOME_HOME:-<não encontrado>}" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Ambiente da sessão
    # --------------------------------------------------------

    GNOME_RUNTIME_DIR="/run/user/${GNOME_UID}"

    GNOME_DBUS_SOCKET="${GNOME_RUNTIME_DIR}/bus"


    # --------------------------------------------------------
    # Exportar informações
    # --------------------------------------------------------

    export GNOME_USER
    export GNOME_UID
    export GNOME_HOME
    export GNOME_RUNTIME_DIR
    export GNOME_DBUS_SOCKET

    return 0
}


# ============================================================
# 3. Verificar sessão GNOME
# ============================================================

gnome_session_available() {

    # --------------------------------------------------------
    # Detectar usuário caso ainda não tenha sido feito
    # --------------------------------------------------------

    if [[ -z "${GNOME_USER:-}" ]]; then

        if ! gnome_detect_user; then
            return 1
        fi

    fi


    # --------------------------------------------------------
    # Verificar runtime
    # --------------------------------------------------------

    if [[ ! -d "$GNOME_RUNTIME_DIR" ]]; then

        echo "[ERRO] Runtime da sessão GNOME não encontrado:" >&2
        echo "       $GNOME_RUNTIME_DIR" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Verificar D-Bus
    # --------------------------------------------------------

    if [[ ! -S "$GNOME_DBUS_SOCKET" ]]; then

        echo "[ERRO] D-Bus da sessão GNOME não encontrado:" >&2
        echo "       $GNOME_DBUS_SOCKET" >&2

        return 1

    fi

    return 0
}


# ============================================================
# 4. Executar comando no contexto do usuário GNOME
# ============================================================

gnome_run() {

    # --------------------------------------------------------
    # Verificar sessão
    # --------------------------------------------------------

    gnome_session_available || return 1


    # --------------------------------------------------------
    # Executar como usuário GNOME
    #
    # IMPORTANTE:
    #
    # Removemos explicitamente variáveis XDG herdadas do root.
    #
    # Isso evita problemas como:
    #
    #   Unable to open
    #   /root/.local/share/flatpak/exports/share/dconf/...
    #
    # quando o setup.sh é executado como root.
    # --------------------------------------------------------

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
        XDG_DATA_DIRS="/usr/local/share:/usr/share" \
        XDG_CONFIG_DIRS="/etc/xdg" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=${GNOME_DBUS_SOCKET}" \
        "$@"
}


# ============================================================
# 5. Wrapper para gsettings
# ============================================================

gnome_gsettings() {

    if ! command -v gsettings >/dev/null 2>&1; then

        echo "[ERRO] Comando gsettings não encontrado." >&2

        return 1

    fi

    gnome_run gsettings "$@"
}


# ============================================================
# 6. Wrapper para gnome-extensions
# ============================================================

gnome_extensions() {

    if ! command -v gnome-extensions >/dev/null 2>&1; then

        echo "[ERRO] Comando gnome-extensions não encontrado." >&2

        return 1

    fi

    gnome_run gnome-extensions "$@"
}


# ============================================================
# 7. Verificar existência de schema
# ============================================================

gnome_schema_exists() {

    local schema="$1"

    if [[ -z "$schema" ]]; then

        echo "[ERRO] Schema não informado." >&2

        return 1

    fi

    gnome_gsettings list-schemas |
        grep -Fxq "$schema"
}


# ============================================================
# 8. Verificar existência de chave
# ============================================================

gnome_key_exists() {

    local schema="$1"
    local key="$2"

    if [[ -z "$schema" ||
          -z "$key" ]]; then

        return 1

    fi

    gnome_gsettings list-keys "$schema" |
        grep -Fxq "$key"
}


# ============================================================
# 9. Verificar se valor é numérico
# ============================================================

gnome_is_number() {

    local value="$1"

    [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}


# ============================================================
# 10. Comparar números com tolerância
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
# 11. Aplicar configuração gsettings
# ============================================================

gnome_gsettings_set() {

    local schema="$1"
    local key="$2"
    local value="$3"


    # --------------------------------------------------------
    # Validar parâmetros
    # --------------------------------------------------------

    if [[ -z "$schema" ]]; then

        echo "[ERRO] Schema não informado." >&2

        return 1

    fi

    if [[ -z "$key" ]]; then

        echo "[ERRO] Chave não informada." >&2

        return 1

    fi


    # --------------------------------------------------------
    # Verificar schema
    # --------------------------------------------------------

    if ! gnome_schema_exists "$schema"; then

        echo "[ERRO] Schema GNOME não encontrado:" >&2
        echo "       $schema" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Verificar chave
    # --------------------------------------------------------

    if ! gnome_key_exists "$schema" "$key"; then

        echo "[ERRO] Chave GNOME não encontrada:" >&2
        echo "       ${schema}::${key}" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Mostrar operação
    # --------------------------------------------------------

    if declare -F info >/dev/null 2>&1; then

        info "Aplicando ${schema}::${key} = ${value}"

    else

        echo "[INFO] Aplicando ${schema}::${key} = ${value}"

    fi


    # --------------------------------------------------------
    # Gravar valor
    # --------------------------------------------------------

    if ! gnome_gsettings set \
        "$schema" \
        "$key" \
        "$value"; then

        if declare -F error >/dev/null 2>&1; then

            error "Falha ao aplicar ${schema}::${key}."

        else

            echo "[ERRO] Falha ao aplicar ${schema}::${key}." >&2

        fi

        return 1

    fi


    # --------------------------------------------------------
    # Ler valor gravado
    # --------------------------------------------------------

    local current

    current="$(
        gnome_gsettings get \
            "$schema" \
            "$key" \
            2>/dev/null
    )"


    # --------------------------------------------------------
    # Validar números
    #
    # IMPORTANTE:
    #
    # GSettings utiliza tipos de ponto flutuante.
    #
    # Um valor solicitado como:
    #
    #   0.72
    #
    # pode ser devolvido como:
    #
    #   0.71999999999999997
    #
    # Esses valores são numericamente equivalentes.
    # --------------------------------------------------------

    if gnome_is_number "$value" &&
       gnome_is_number "$current"; then

        if ! gnome_numeric_equal \
            "$value" \
            "$current"; then

            if declare -F error >/dev/null 2>&1; then

                error \
                    "Validação numérica divergente para ${schema}::${key}."

                error "Esperado: ${value}"
                error "Obtido:   ${current}"

            else

                echo \
                    "[ERRO] Validação numérica divergente para ${schema}::${key}." \
                    >&2

                echo \
                    "[ERRO] Esperado: ${value}" \
                    >&2

                echo \
                    "[ERRO] Obtido:   ${current}" \
                    >&2

            fi

            return 1

        fi


    # --------------------------------------------------------
    # Validar demais tipos
    #
    # Boolean:
    #   true
    #
    # String:
    #   'LEFT'
    #
    # Enum:
    #   'FIXED'
    #
    # Array:
    #   ['app1.desktop', 'app2.desktop']
    # --------------------------------------------------------

    else

        if [[ "$current" != "$value" ]]; then

            if declare -F error >/dev/null 2>&1; then

                error \
                    "Validação divergente para ${schema}::${key}."

                error "Esperado: ${value}"

                error \
                    "Obtido:   ${current:-<vazio>}"

            else

                echo \
                    "[ERRO] Validação divergente para ${schema}::${key}." \
                    >&2

                echo \
                    "[ERRO] Esperado: ${value}" \
                    >&2

                echo \
                    "[ERRO] Obtido: ${current:-<vazio>}" \
                    >&2

            fi

            return 1

        fi

    fi


    # --------------------------------------------------------
    # Sucesso
    # --------------------------------------------------------

    if declare -F success >/dev/null 2>&1; then

        success "${key} = ${current}"

    else

        echo "[OK] ${key} = ${current}"

    fi

    return 0
}


# ============================================================
# 12. Ler configuração gsettings
# ============================================================

gnome_gsettings_get() {

    local schema="$1"
    local key="$2"

    if [[ -z "$schema" ||
          -z "$key" ]]; then

        return 1

    fi

    gnome_gsettings get \
        "$schema" \
        "$key"
}


# ============================================================
# 13. Resetar configuração
# ============================================================

gnome_gsettings_reset() {

    local schema="$1"
    local key="$2"

    if [[ -z "$schema" ||
          -z "$key" ]]; then

        return 1

    fi

    gnome_gsettings reset \
        "$schema" \
        "$key"
}


# ============================================================
# 14. Verificar extensão GNOME
# ============================================================

gnome_extension_exists() {

    local uuid="$1"

    if [[ -z "$uuid" ]]; then
        return 1
    fi

    gnome_extensions list 2>/dev/null |
        grep -Fxq "$uuid"
}


# ============================================================
# 15. Verificar se extensão está habilitada
# ============================================================

gnome_extension_enabled() {

    local uuid="$1"

    if ! gnome_extension_exists "$uuid"; then
        return 1
    fi

    gnome_extensions list \
        --enabled \
        2>/dev/null |
        grep -Fxq "$uuid"
}


# ============================================================
# 16. Habilitar extensão GNOME
# ============================================================

gnome_extension_enable() {

    local uuid="$1"

    if [[ -z "$uuid" ]]; then

        echo "[ERRO] UUID da extensão não informado." >&2

        return 1

    fi


    # --------------------------------------------------------
    # Verificar existência
    # --------------------------------------------------------

    if ! gnome_extension_exists "$uuid"; then

        echo "[AVISO] Extensão GNOME não encontrada:" >&2
        echo "        $uuid" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Já habilitada
    # --------------------------------------------------------

    if gnome_extension_enabled "$uuid"; then

        if declare -F success >/dev/null 2>&1; then
            success "Extensão já habilitada: $uuid"
        else
            echo "[OK] Extensão já habilitada: $uuid"
        fi

        return 0

    fi


    # --------------------------------------------------------
    # Habilitar
    # --------------------------------------------------------

    if ! gnome_extensions enable "$uuid"; then

        echo "[ERRO] Não foi possível habilitar:" >&2
        echo "       $uuid" >&2

        return 1

    fi


    # --------------------------------------------------------
    # Validar
    # --------------------------------------------------------

    if gnome_extension_enabled "$uuid"; then

        if declare -F success >/dev/null 2>&1; then
            success "Extensão habilitada: $uuid"
        else
            echo "[OK] Extensão habilitada: $uuid"
        fi

        return 0

    fi

    echo "[AVISO] A extensão foi habilitada, mas o GNOME ainda" >&2
    echo "        não confirmou seu estado nesta sessão." >&2

    return 1
}


# ============================================================