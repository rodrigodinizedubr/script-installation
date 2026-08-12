#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${DESABILITAR_BLOQUEIO_TELA:-true}" != true ]; then
    info "Configuração de bloqueio de tela desabilitada."
    exit 0
fi

info "Desabilitando bloqueio automático da tela no GNOME"

# ============================================================
# Verificar usuário
# ============================================================

if ! id "$USUARIO" >/dev/null 2>&1; then
    error "Usuário $USUARIO não encontrado."
    exit 1
fi

UID_USUARIO="$(id -u "$USUARIO")"
DBUS_SOCKET="/run/user/$UID_USUARIO/bus"

# ============================================================
# Verificar sessão gráfica / D-Bus
# ============================================================

if [ ! -S "$DBUS_SOCKET" ]; then
    warn "D-Bus da sessão gráfica do usuário $USUARIO não encontrado."
    warn "Arquivo esperado: $DBUS_SOCKET"
    warn "Execute este módulo com o usuário logado no GNOME."
    exit 0
fi

# ============================================================
# Função para executar gsettings na sessão do usuário
# ============================================================

gsettings_usuario() {
    sudo -u "$USUARIO" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCKET" \
        gsettings "$@"
}

# ============================================================
# Mostrar valores atuais
# ============================================================

info "Valores atuais"

gsettings_usuario get org.gnome.desktop.session idle-delay
gsettings_usuario get org.gnome.desktop.screensaver lock-enabled

# ============================================================
# Aplicar configurações
# ============================================================

info "Desabilitando tempo de inatividade"

gsettings_usuario set \
    org.gnome.desktop.session \
    idle-delay \
    "uint32 0"

info "Desabilitando bloqueio automático"

gsettings_usuario set \
    org.gnome.desktop.screensaver \
    lock-enabled \
    false

# ============================================================
# Verificar valores finais
# ============================================================

IDLE_DELAY="$(
    gsettings_usuario get \
        org.gnome.desktop.session \
        idle-delay
)"

LOCK_ENABLED="$(
    gsettings_usuario get \
        org.gnome.desktop.screensaver \
        lock-enabled
)"

info "Valores finais:"
echo "idle-delay   = $IDLE_DELAY"
echo "lock-enabled = $LOCK_ENABLED"

# ============================================================
# Validação
# ============================================================

if [ "$IDLE_DELAY" = "uint32 0" ] && \
   [ "$LOCK_ENABLED" = "false" ]; then

    info "Bloqueio automático da tela desabilitado com sucesso."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "OK" \
            "Bloqueio de tela GNOME" \
            "idle-delay=0 e lock-enabled=false"
    fi

    exit 0

else

    error "Verificação final divergente."
    error "idle-delay recebido: $IDLE_DELAY"
    error "lock-enabled recebido: $LOCK_ENABLED"

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "Bloqueio de tela GNOME" \
            "Verificação final divergente"
    fi

    exit 1

fi
