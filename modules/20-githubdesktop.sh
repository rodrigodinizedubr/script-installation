#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${INSTALAR_GITHUB_DESKTOP:-false}" != true ]; then
    mark_skipped "GitHub Desktop desabilitado (INSTALAR_GITHUB_DESKTOP=false)."
    exit 0
fi

info "Iniciando instalação do GitHub Desktop"

# ============================================================
# Verificar arquitetura
# ============================================================

ARCH="$(dpkg --print-architecture)"

info "Arquitetura detectada: $ARCH"

if [ "$ARCH" != "amd64" ]; then
    error "Este módulo está configurado para arquitetura amd64."
    exit 1
fi


# ============================================================
# Configurar repositório MWT para o GitHub Desktop  
# ============================================================

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mwt-desktop.gpg] https://mirror.mwt.me/shiftkey-desktop/deb/ any main" \
    > /etc/apt/sources.list.d/mwt-desktop.list


# ============================================================
# Dependências
# ============================================================

info "Instalando dependências"

apt update

apt install -y \
    wget \
    gpg \
    ca-certificates

# ============================================================
# Chave do repositório
# ============================================================

info "Configurando chave do repositório GitHub Desktop"

wget -qO - \
    https://packagecloud.io/shiftkey/desktop/gpgkey \
    | gpg --dearmor \
    > /usr/share/keyrings/shiftkey-desktop.gpg

# ============================================================
# Repositório
# ============================================================

info "Configurando repositório GitHub Desktop"

cat > /etc/apt/sources.list.d/shiftkey-desktop.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/shiftkey-desktop.gpg] https://packagecloud.io/shiftkey/desktop/any/ any main
EOF

# ============================================================
# Instalação
# ============================================================

apt update

info "Instalando GitHub Desktop"

apt install -y github-desktop

# ============================================================
# Verificação
# ============================================================

if command -v github-desktop >/dev/null 2>&1; then

    info "GitHub Desktop instalado com sucesso."
    record_component_status "INSTALADO" "GitHub Desktop" "Executável encontrado após instalação"

else

    warn "A instalação terminou, mas o executável não foi localizado no PATH."
    record_component_status "FALHA" "GitHub Desktop" "Executável não localizado no PATH"

fi

echo
info "GitHub Desktop finalizado."
info "Procure por GitHub Desktop no menu de aplicativos."
