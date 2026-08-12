#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Iniciando instalação dos Adicionais para Convidado do VirtualBox"

# ============================================================
# Verificar se está executando como root
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Este módulo deve ser executado como root."
    exit 1
fi

# ============================================================
# Verificar se está em uma máquina VirtualBox
# ============================================================

if command -v systemd-detect-virt >/dev/null 2>&1; then

    VIRTUALIZACAO="$(systemd-detect-virt || true)"

    if [ "$VIRTUALIZACAO" != "oracle" ]; then
        warn "O sistema não parece estar executando no VirtualBox."
        warn "Virtualização detectada: ${VIRTUALIZACAO:-nenhuma}"
    else
        info "VirtualBox detectado."
    fi

fi

# ============================================================
# Atualizar lista de pacotes
# ============================================================

info "Atualizando lista de pacotes"

apt update

# ============================================================
# Instalar dependências
# ============================================================

info "Instalando dependências dos Adicionais para Convidado"

install_package build-essential
install_package module-assistant
install_package dkms
install_package linux-headers-$(uname -r)

# ============================================================
# Preparar ambiente para módulos do kernel
# ============================================================

info "Preparando ambiente para compilação dos módulos do kernel"

m-a prepare -y

# ============================================================
# Procurar VBoxLinuxAdditions.run
# ============================================================

info "Procurando VBoxLinuxAdditions.run"

VBOX_INSTALLER=""

LOCAIS=(
    "/media/cdrom/VBoxLinuxAdditions.run"
    "/media/cdrom0/VBoxLinuxAdditions.run"
    "/run/media/$USUARIO/VBox_GAs_*/VBoxLinuxAdditions.run"
)

for LOCAL in "${LOCAIS[@]}"; do

    ARQUIVO=$(compgen -G "$LOCAL" | head -n 1 || true)

    if [ -n "$ARQUIVO" ] && [ -f "$ARQUIVO" ]; then
        VBOX_INSTALLER="$ARQUIVO"
        break
    fi

done

# ============================================================
# Caso a mídia não esteja montada
# ============================================================

if [ -z "$VBOX_INSTALLER" ]; then

    warn "VBoxLinuxAdditions.run não foi localizado."

    echo
    warn "No menu do VirtualBox, execute:"
    warn "Dispositivos -> Inserir imagem de CD dos Adicionais para Convidado"
    echo
    warn "Depois execute novamente este módulo."

    exit 1

fi

info "Instalador localizado em:"
echo "$VBOX_INSTALLER"

# ============================================================
# Executar instalador
# ============================================================

info "Executando VBoxLinuxAdditions.run"

sh "$VBOX_INSTALLER"

# ============================================================
# Verificar módulos carregados
# ============================================================

info "Verificando módulos do VirtualBox"

if lsmod | grep -q vboxguest; then
    info "Módulo vboxguest carregado."
else
    warn "Módulo vboxguest ainda não está carregado."
fi

if lsmod | grep -q vboxsf; then
    info "Módulo vboxsf carregado."
else
    warn "Módulo vboxsf ainda não está carregado."
fi

if lsmod | grep -q vboxvideo; then
    info "Módulo vboxvideo carregado."
else
    warn "Módulo vboxvideo ainda não está carregado."
fi

# ============================================================
# Verificar instalação
# ============================================================

if command -v VBoxClient >/dev/null 2>&1; then
    info "VBoxClient encontrado."
else
    warn "VBoxClient não foi encontrado."
fi

echo
info "Instalação dos Adicionais para Convidado finalizada."

warn "Reinicie a máquina virtual para aplicar todas as alterações."
warn "Após reiniciar, teste o redimensionamento automático da tela."
