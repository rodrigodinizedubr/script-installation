#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${DESABILITAR_BLOQUEIO_TELA:-true}" != true ]; then
    mark_skipped "Desativação do bloqueio de tela desabilitada (DESABILITAR_BLOQUEIO_TELA=false)."
    exit 0
fi

info "Configurando GNOME para não bloquear a tela"

# ============================================================
# Verificar usuário
# ============================================================

if ! id "$USUARIO" >/dev/null 2>&1; then
    error "Usuário $USUARIO não encontrado."
    exit 1
fi

# ============================================================
# Verificar gsettings
# ============================================================

if ! command -v gsettings >/dev/null 2>&1; then
    error "Comando gsettings não encontrado."
    exit 1
fi

# ============================================================
# Mostrar configuração atual
# ============================================================

info "Configuração atual:"

sudo -u "$USUARIO" \
    gsettings get org.gnome.desktop.session idle-delay || true

sudo -u "$USUARIO" \
    gsettings get org.gnome.desktop.screensaver lock-enabled || true

# ============================================================
# Desabilitar tempo de inatividade
# ============================================================

info "Desabilitando tempo limite de inatividade"

sudo -u "$USUARIO" \
    gsettings set org.gnome.desktop.session idle-delay 0

# ============================================================
# Desabilitar bloqueio automático
# ============================================================

info "Desabilitando bloqueio automático da tela"

sudo -u "$USUARIO" \
    gsettings set org.gnome.desktop.screensaver lock-enabled false

# ============================================================
# Verificação
# ============================================================

echo
info "Verificando novas configurações"

IDLE_DELAY=$(
    sudo -u "$USUARIO" \
        gsettings get org.gnome.desktop.session idle-delay
)

LOCK_ENABLED=$(
    sudo -u "$USUARIO" \
        gsettings get org.gnome.desktop.screensaver lock-enabled
)

echo "idle-delay   : $IDLE_DELAY"
echo "lock-enabled : $LOCK_ENABLED"

# ============================================================
# Resultado
# ============================================================

if [[ "$IDLE_DELAY" == *"0"* ]] && \
   [[ "$LOCK_ENABLED" == "false" ]]; then

    info "Bloqueio automático da tela desabilitado com sucesso."
    record_component_status "OK" "Bloqueio de tela GNOME" "idle-delay=0; lock-enabled=false"

else

    warn "Não foi possível confirmar todas as configurações."
    record_component_status "FALHA" "Bloqueio de tela GNOME" "Verificação final divergente"
    exit 1

fi
