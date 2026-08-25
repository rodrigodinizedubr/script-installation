#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"
source "$BASE_DIR/lib/gnome.sh"

COMPONENTE="Bloqueio de tela GNOME"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${DESABILITAR_BLOQUEIO_TELA:-true}" != true ]; then
    info "Configuração de bloqueio de tela desabilitada."
    mark_component_skipped "$COMPONENTE" "DESABILITAR_BLOQUEIO_TELA=false"
    mark_skipped "DESABILITAR_BLOQUEIO_TELA=false"
    exit 0
fi

info "Desabilitando bloqueio automático da tela no GNOME"

# ============================================================
# Preparar sessão GNOME
# ============================================================

gnome_detect_user || {
    record_component_status "FALHA" "$COMPONENTE" "Usuário GNOME não identificado"
    exit 1
}

info "Usuário GNOME: $GNOME_USER (UID $GNOME_UID)"

if ! gnome_session_available; then
    warn "Execute este módulo com o usuário $GNOME_USER logado no GNOME."
    mark_component_skipped "$COMPONENTE" "Sessão GNOME não disponível"
    mark_skipped "Sessão GNOME do usuário $GNOME_USER não disponível"
    exit 0
fi

# ============================================================
# Mostrar valores atuais
# ============================================================

info "Valores atuais"
echo "idle-delay   = $(gnome_gsettings get org.gnome.desktop.session idle-delay)"
echo "lock-enabled = $(gnome_gsettings get org.gnome.desktop.screensaver lock-enabled)"

# ============================================================
# Aplicar e validar configurações
# ============================================================

gnome_gsettings_set \
    "org.gnome.desktop.session" \
    "idle-delay" \
    "uint32 0"

gnome_gsettings_set \
    "org.gnome.desktop.screensaver" \
    "lock-enabled" \
    "false"

# ============================================================
# Resultado
# ============================================================

success "Bloqueio automático da tela desabilitado e validado."
record_component_status "OK" "$COMPONENTE" "idle-delay=0 e lock-enabled=false"
