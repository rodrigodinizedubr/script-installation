#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/lib/common.sh"

info "Instalando ferramentas principais"

PACOTES=(
    obs-studio
    shotcut
    flameshot
    tealdeer
    nmap
    wget
    curl
    git
    gnome-shell-extension-dashtodock
)

for pacote in "${PACOTES[@]}"; do
    install_package "$pacote"
done

if command_exists tldr; then
    info "tealdeer instalado. Comando disponível: tldr"
else
    warn "tealdeer foi solicitado, mas o comando tldr não foi encontrado após instalação."
fi
