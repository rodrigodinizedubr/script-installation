#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Iniciando instalação do Docker"

# ============================================================
# 1. Identificar Debian
# ============================================================

if [ ! -f /etc/os-release ]; then
    error "Não foi possível identificar o sistema operacional."
    exit 1
fi

. /etc/os-release

if [ "$ID" != "debian" ]; then
    error "Este módulo foi desenvolvido para Debian."
    exit 1
fi

CODENAME="$VERSION_CODENAME"
VERSAO_DEBIAN="$VERSION_ID"
ARCH="$(dpkg --print-architecture)"

info "Debian detectado: $PRETTY_NAME"
info "Codename: $CODENAME"
info "Arquitetura: $ARCH"

# ============================================================
# 2. Remover pacotes conflitantes
# ============================================================

info "Removendo possíveis pacotes conflitantes"

PACOTES_CONFLITANTES=(
    docker.io
    docker-compose
    docker-doc
    docker-buildx
    podman-docker
    containerd
    runc
)

for pacote in "${PACOTES_CONFLITANTES[@]}"; do
    if dpkg -s "$pacote" >/dev/null 2>&1; then
        apt remove -y "$pacote"
    fi
done

# ============================================================
# 3. Dependências
# ============================================================

info "Instalando dependências"

apt update

apt install -y \
    ca-certificates \
    curl \
    gnupg

# ============================================================
# 4. Chave oficial do Docker
# ============================================================

info "Configurando chave do repositório Docker"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
    https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

# ============================================================
# 5. Repositório oficial
# ============================================================

info "Configurando repositório oficial do Docker"

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $CODENAME
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update

# ============================================================
# 6. Docker Engine
# ============================================================

info "Instalando Docker Engine"

apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ============================================================
# 7. Habilitar serviço
# ============================================================

info "Habilitando Docker Engine"

systemctl enable --now docker

# ============================================================
# 8. Usuário no grupo docker
# ============================================================

if id "$USUARIO" >/dev/null 2>&1; then

    info "Adicionando $USUARIO ao grupo docker"

    groupadd -f docker
    usermod -aG docker "$USUARIO"

else

    warn "Usuário $USUARIO não encontrado."

fi

# ============================================================
# 9. Testar Engine
# ============================================================

info "Verificando Docker Engine"

docker --version
docker compose version

if docker run --rm hello-world; then
    info "Docker Engine funcionando corretamente."
else
    warn "O teste hello-world apresentou erro."
fi

# ============================================================
# 10. Docker Desktop
# ============================================================

info "Verificando possibilidade de instalar Docker Desktop"

if [ "$ARCH" != "amd64" ]; then

    warn "Docker Desktop não será instalado."
    warn "Arquitetura encontrada: $ARCH"
    warn "Este módulo instala Docker Desktop apenas em amd64."

    exit 0

fi

# Docker Desktop Debian atualmente requer Debian >= 12

VERSAO_MAJOR="${VERSAO_DEBIAN%%.*}"

if [ "$VERSAO_MAJOR" -lt 12 ]; then

    warn "Docker Engine foi instalado."
    warn "Docker Desktop não será instalado no Debian $VERSAO_DEBIAN."
    warn "Utilize Debian 12 ou superior."

    exit 0

fi

# ============================================================
# 11. Dependências do Docker Desktop
# ============================================================

info "Instalando dependências do Docker Desktop"

apt install -y \
    gnome-terminal \
    qemu-system-x86 \
    pass \
    uidmap

# ============================================================
# 12. Verificar KVM
# ============================================================

info "Verificando suporte ao KVM"

if [ -e /dev/kvm ]; then

    info "KVM disponível."

    if getent group kvm >/dev/null; then
        usermod -aG kvm "$USUARIO"
    fi

else

    warn "/dev/kvm não encontrado."
    warn "Docker Desktop necessita de virtualização KVM."
    warn "A instalação continuará, mas o Desktop poderá não iniciar."

fi

# ============================================================
# 13. Download Docker Desktop
# ============================================================

info "Baixando Docker Desktop"

DOCKER_DESKTOP_DEB="/tmp/docker-desktop-amd64.deb"

curl -L \
    "https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb" \
    -o "$DOCKER_DESKTOP_DEB"

# ============================================================
# 14. Instalar Docker Desktop
# ============================================================

info "Instalando Docker Desktop"

apt install -y "$DOCKER_DESKTOP_DEB"

# ============================================================
# 15. Limpeza
# ============================================================

rm -f "$DOCKER_DESKTOP_DEB"

# ============================================================
# Finalização
# ============================================================

info "Docker Engine e Docker Desktop instalados."

echo
echo "Docker:"
docker --version

echo
echo "Docker Compose:"
docker compose version

echo
echo "Contextos disponíveis:"
docker context ls || true

echo
warn "O usuário $USUARIO foi adicionado aos grupos docker/kvm."
warn "É necessário encerrar a sessão e entrar novamente."
warn "Depois, abra o Docker Desktop pelo menu de aplicativos."
