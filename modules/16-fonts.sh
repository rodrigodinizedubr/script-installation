#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Instalando fontes compatíveis com Windows"

install_package fontconfig
install_package fonts-crosextra-carlito
install_package fonts-crosextra-caladea

if apt-cache show ttf-mscorefonts-installer >/dev/null 2>&1; then
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections || true
    install_package ttf-mscorefonts-installer || warn "Não foi possível instalar ttf-mscorefonts-installer."
else
    warn "Pacote ttf-mscorefonts-installer não disponível nos repositórios atuais."
fi

if [ "$INSTALAR_FONTES_ASSETS" = true ]; then
    if [ -d "$BASE_DIR/assets/fonts" ] && find "$BASE_DIR/assets/fonts" -type f | grep -q .; then
        info "Copiando fontes de assets/fonts para /usr/share/fonts/custom"
        mkdir -p /usr/share/fonts/custom
        cp -r "$BASE_DIR/assets/fonts/"* /usr/share/fonts/custom/
    else
        warn "INSTALAR_FONTES_ASSETS=true, mas assets/fonts está vazio."
    fi
fi

fc-cache -fv
