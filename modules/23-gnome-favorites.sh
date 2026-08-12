#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Configuração
# ============================================================

if [ "${CONFIGURAR_FAVORITOS_GNOME:-true}" != true ]; then
    info "Configuração dos favoritos do GNOME desabilitada."
    exit 0
fi

info "Configurando aplicativos favoritos do GNOME"

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
# Aplicativos desejados
# ============================================================

APLICATIVOS=(
    "org.gnome.Terminal.desktop"
    "firefox-esr.desktop"
    "google-chrome.desktop"
    "opera.desktop"
    "com.obsproject.Studio.desktop"
    "org.shotcut.Shotcut.desktop"
    "flameshot.desktop"
    "wireshark.desktop"
    "com.gexperts.Tilix.desktop"
    "code.desktop"
    "github-desktop.desktop"
)

# ============================================================
# Diretórios onde arquivos .desktop podem estar
# ============================================================

DIRETORIOS_DESKTOP=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "/home/$USUARIO/.local/share/applications"
)

# ============================================================
# Localizar aplicativos existentes
# ============================================================

FAVORITOS=()

for APP in "${APLICATIVOS[@]}"; do

    ENCONTRADO=false

    for DIRETORIO in "${DIRETORIOS_DESKTOP[@]}"; do

        if [ -f "$DIRETORIO/$APP" ]; then

            info "Aplicativo encontrado: $APP"

            FAVORITOS+=("$APP")

            ENCONTRADO=true

            break

        fi

    done

    if [ "$ENCONTRADO" = false ]; then
        warn "Aplicativo não encontrado: $APP"
    fi

done

# ============================================================
# Verificar resultado
# ============================================================

if [ "${#FAVORITOS[@]}" -eq 0 ]; then
    warn "Nenhum aplicativo foi encontrado."
    exit 0
fi

# ============================================================
# Construir lista compatível com gsettings
# ============================================================

LISTA="["

for APP in "${FAVORITOS[@]}"; do
    LISTA+="'$APP', "
done

LISTA="${LISTA%, }"
LISTA+="]"

# ============================================================
# Mostrar lista
# ============================================================

echo
info "Favoritos que serão configurados:"

for APP in "${FAVORITOS[@]}"; do
    echo "  - $APP"
done

echo

# ============================================================
# Aplicar configuração
# ============================================================

info "Aplicando favoritos"

sudo -u "$USUARIO" \
    gsettings set org.gnome.shell favorite-apps "$LISTA"

# ============================================================
# Verificação
# ============================================================

echo
info "Favoritos configurados no GNOME:"

sudo -u "$USUARIO" \
    gsettings get org.gnome.shell favorite-apps

echo
info "Configuração dos favoritos concluída."
