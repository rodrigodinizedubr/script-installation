#!/bin/bash

# ============================================================
# Biblioteca comum para configuração da sessão GNOME
# ============================================================
# Centraliza:
#   - identificação do usuário-alvo;
#   - acesso ao D-Bus da sessão gráfica;
#   - execução de comandos no contexto do usuário;
#   - wrappers para gsettings e gnome-extensions;
#   - aplicação e validação de chaves gsettings.
#
# Deve ser carregada após config.conf e lib/common.sh.
# ============================================================

if [ -n "${GNOME_LIB_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
GNOME_LIB_LOADED=1

# ------------------------------------------------------------
# Identificar o usuário que deve receber as configurações GNOME
# ------------------------------------------------------------

gnome_detect_user() {
    local candidate=""
    local session=""
    local session_user=""
    local session_active=""
    local session_type=""

    # O usuário definido no config.conf é a fonte principal.
    if [ -n "${USUARIO:-}" ] && [ "${USUARIO}" != "root" ]; then
        candidate="$USUARIO"
    fi

    # Fallback: usuário que iniciou o sudo.
    if [ -z "$candidate" ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        candidate="$SUDO_USER"
    fi

    # Último fallback: primeira sessão gráfica ativa encontrada.
    if [ -z "$candidate" ] && command -v loginctl >/dev/null 2>&1; then
        while read -r session _uid session_user _rest; do
            [ -n "$session" ] || continue
            [ -n "$session_user" ] || continue
            [ "$session_user" != "root" ] || continue

            session_active="$(loginctl show-session "$session" -p Active --value 2>/dev/null || true)"
            session_type="$(loginctl show-session "$session" -p Type --value 2>/dev/null || true)"

            if [ "$session_active" = "yes" ] && \
               { [ "$session_type" = "wayland" ] || [ "$session_type" = "x11" ]; }; then
                candidate="$session_user"
                break
            fi
        done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
    fi

    if [ -z "$candidate" ]; then
        error "Não foi possível identificar o usuário da sessão GNOME."
        return 1
    fi

    if ! id "$candidate" >/dev/null 2>&1; then
        error "Usuário GNOME não encontrado: $candidate"
        return 1
    fi

    GNOME_USER="$candidate"
    GNOME_UID="$(id -u "$GNOME_USER")"
    GNOME_HOME="$(getent passwd "$GNOME_USER" | cut -d: -f6)"
    GNOME_RUNTIME_DIR="/run/user/$GNOME_UID"
    GNOME_DBUS_SOCKET="$GNOME_RUNTIME_DIR/bus"

    if [ -z "$GNOME_HOME" ] || [ ! -d "$GNOME_HOME" ]; then
        error "Diretório HOME do usuário $GNOME_USER não encontrado."
        return 1
    fi

    export GNOME_USER GNOME_UID GNOME_HOME GNOME_RUNTIME_DIR GNOME_DBUS_SOCKET
    return 0
}

# ------------------------------------------------------------
# Verificar se a sessão do usuário está disponível
# ------------------------------------------------------------

gnome_session_available() {
    if [ -z "${GNOME_USER:-}" ]; then
        gnome_detect_user || return 1
    fi

    if [ ! -d "$GNOME_RUNTIME_DIR" ]; then
        warn "Runtime da sessão do usuário $GNOME_USER não encontrado."
        warn "Diretório esperado: $GNOME_RUNTIME_DIR"
        return 1
    fi

    if [ ! -S "$GNOME_DBUS_SOCKET" ]; then
        warn "D-Bus da sessão gráfica do usuário $GNOME_USER não encontrado."
        warn "Socket esperado: $GNOME_DBUS_SOCKET"
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Executar comando no contexto da sessão GNOME do usuário
# ------------------------------------------------------------

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
        XDG_DATA_DIRS="/usr/local/share:/usr/share" \
        XDG_CONFIG_DIRS="/etc/xdg" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=${GNOME_DBUS_SOCKET}" \
        "$@"
}

# ------------------------------------------------------------
# Wrappers
# ------------------------------------------------------------

gnome_gsettings() {
    if ! command -v gsettings >/dev/null 2>&1; then
        error "Comando gsettings não encontrado."
        return 1
    fi

    gnome_run gsettings "$@"
}

gnome_extensions() {
    if ! command -v gnome-extensions >/dev/null 2>&1; then
        error "Comando gnome-extensions não encontrado."
        return 1
    fi

    gnome_run gnome-extensions "$@"
}

# ------------------------------------------------------------
# Verificar schema/chave do gsettings
# ------------------------------------------------------------

gnome_schema_exists() {
    local schema="$1"
    gnome_gsettings list-schemas 2>/dev/null | grep -Fxq "$schema"
}

gnome_key_exists() {
    local schema="$1"
    local key="$2"
    gnome_gsettings list-keys "$schema" 2>/dev/null | grep -Fxq "$key"
}

# ------------------------------------------------------------
# Aplicar uma chave e validar o valor gravado
# ------------------------------------------------------------

gnome_gsettings_set() {
    local schema="$1"
    local key="$2"
    local value="$3"
    local current=""

    if ! gnome_schema_exists "$schema"; then
        error "Schema GNOME não encontrado: $schema"
        return 1
    fi

    if ! gnome_key_exists "$schema" "$key"; then
        error "Chave GNOME não encontrada: $schema::$key"
        return 1
    fi

    info "Aplicando $schema::$key = $value"

    if ! gnome_gsettings set "$schema" "$key" "$value"; then
        error "Falha ao aplicar $schema::$key."
        return 1
    fi

    current="$(gnome_gsettings get "$schema" "$key" 2>/dev/null || true)"

    if [ "$current" != "$value" ]; then
        error "Validação divergente para $schema::$key."
        error "Esperado: $value"
        error "Obtido:   ${current:-<vazio>}"
        return 1
    fi

    success "$key = $current"
    return 0
}
