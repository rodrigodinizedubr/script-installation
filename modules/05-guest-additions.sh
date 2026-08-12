#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/lib/common.sh"

info "Instalando dependências dos Adicionais para Convidado do VirtualBox"

apt update
install_package build-essential
install_package module-assistant
install_package dkms
install_package sudo
install_package nano

apt install -y "linux-headers-$(uname -r)" || warn "Não foi possível instalar linux-headers-$(uname -r)."

m-a prepare -y || warn "m-a prepare retornou erro. Verifique os headers do kernel."

if [ -f /media/cdrom/VBoxLinuxAdditions.run ]; then
    info "Executando /media/cdrom/VBoxLinuxAdditions.run"
    sh /media/cdrom/VBoxLinuxAdditions.run
elif [ -f /media/cdrom0/VBoxLinuxAdditions.run ]; then
    info "Executando /media/cdrom0/VBoxLinuxAdditions.run"
    sh /media/cdrom0/VBoxLinuxAdditions.run
else
    warn "VBoxLinuxAdditions.run não encontrado."
    warn "No VirtualBox, use: Dispositivos > Inserir imagem de CD dos Adicionais para Convidado."
fi
