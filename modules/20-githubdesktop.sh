#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${INSTALAR_GITHUB_DESKTOP:-false}" != true ]; then
    info "Instalação do GitHub Desktop desabilitada."
    
    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "IGNORADO" \
            "GitHub Desktop" \
            "INSTALAR_GITHUB_DESKTOP=false"
    fi

    exit 0
fi

info "Iniciando instalação do GitHub Desktop"

# ============================================================
# Verificar execução como root
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Este módulo deve ser executado como root."
    exit 1
fi

# ============================================================
# Verificar arquitetura
# ============================================================

ARCH="$(dpkg --print-architecture)"

info "Arquitetura detectada: $ARCH"

if [ "$ARCH" != "amd64" ]; then
    error "GitHub Desktop não será instalado."
    error "Arquitetura suportada neste módulo: amd64."
    error "Arquitetura encontrada: $ARCH"

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Arquitetura não suportada: $ARCH"
    fi

    exit 1
fi

# ============================================================
# Definir caminhos utilizados
# ============================================================

KEYRING="/usr/share/keyrings/mwt-desktop.gpg"

REPOSITORY_LIST="/etc/apt/sources.list.d/mwt-desktop.list"

REPOSITORY_SOURCES="/etc/apt/sources.list.d/mwt-desktop.sources"

GPG_URL="https://mirror.mwt.me/shiftkey-desktop/gpgkey"

REPOSITORY_URL="https://mirror.mwt.me/shiftkey-desktop/deb/"

# ============================================================
# Remover configurações antigas ou incompletas
# ============================================================

info "Removendo configurações antigas do repositório GitHub Desktop"

rm -f "$REPOSITORY_LIST"
rm -f "$REPOSITORY_SOURCES"
rm -f "$KEYRING"

# Também remover configuração antiga baseada em PackageCloud
rm -f /etc/apt/sources.list.d/shiftkey-desktop.list
rm -f /etc/apt/sources.list.d/shiftkey-desktop.sources
rm -f /usr/share/keyrings/shiftkey-desktop.gpg

# ============================================================
# Instalar dependências
# ============================================================

info "Instalando dependências"

# Não executar apt update aqui.
# Um repositório antigo/quebrado poderia impedir a execução.

apt install -y \
    wget \
    curl \
    gpg \
    ca-certificates

# ============================================================
# Criar diretório de keyrings
# ============================================================

info "Preparando diretório de chaves"

install -m 0755 -d /usr/share/keyrings

# ============================================================
# Baixar chave GPG
# ============================================================

info "Baixando chave GPG do repositório GitHub Desktop"

GPG_TEMP="/tmp/mwt-desktop-gpgkey"

rm -f "$GPG_TEMP"

if ! curl -fsSL "$GPG_URL" -o "$GPG_TEMP"; then

    error "Não foi possível baixar a chave GPG."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Falha ao baixar chave GPG"
    fi

    exit 1
fi

# ============================================================
# Validar chave GPG antes da conversão
# ============================================================

info "Validando chave GPG"

if ! gpg --show-keys "$GPG_TEMP" >/dev/null 2>&1; then

    error "O arquivo obtido não contém uma chave OpenPGP válida."

    rm -f "$GPG_TEMP"

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Chave GPG inválida"
    fi

    exit 1
fi

# ============================================================
# Converter chave para keyring
# ============================================================

info "Criando keyring do repositório GitHub Desktop"

if ! gpg \
    --dearmor \
    --yes \
    --output "$KEYRING" \
    "$GPG_TEMP"; then

    error "Não foi possível criar o keyring."

    rm -f "$GPG_TEMP"

    exit 1
fi

rm -f "$GPG_TEMP"

chmod 644 "$KEYRING"

# ============================================================
# Validar keyring criado
# ============================================================

if ! gpg --show-keys "$KEYRING" >/dev/null 2>&1; then

    error "O keyring criado não pôde ser validado."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Keyring inválido"
    fi

    exit 1
fi

info "Chave GPG validada com sucesso."

# ============================================================
# Configurar repositório MWT para o GitHub Desktop
# ============================================================

info "Configurando repositório MWT para o GitHub Desktop"

cat > "$REPOSITORY_SOURCES" <<EOF
Types: deb
URIs: $REPOSITORY_URL
Suites: any
Components: main
Architectures: amd64
Signed-By: $KEYRING
EOF

chmod 644 "$REPOSITORY_SOURCES"

# ============================================================
# Atualizar lista de pacotes
# ============================================================

info "Atualizando lista de pacotes"

if ! apt update; then

    error "Falha ao atualizar os repositórios APT."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Falha no apt update"
    fi

    exit 1
fi

# ============================================================
# Verificar disponibilidade do pacote
# ============================================================

info "Verificando disponibilidade do pacote github-desktop"

CANDIDATO="$(
    apt-cache policy github-desktop \
    | awk '/Candidate:/ {print $2}'
)"

if [ -z "$CANDIDATO" ] || [ "$CANDIDATO" = "(none)" ]; then

    error "O pacote github-desktop não possui uma versão candidata."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Pacote não disponível no repositório"
    fi

    exit 1
fi

info "Versão candidata encontrada: $CANDIDATO"

# ============================================================
# Verificar se já está instalado
# ============================================================

if dpkg -s github-desktop >/dev/null 2>&1; then

    info "GitHub Desktop já está instalado."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "JA_EXISTIA" \
            "GitHub Desktop" \
            "Pacote já instalado"
    fi

    exit 0
fi

# ============================================================
# Instalar GitHub Desktop
# ============================================================

info "Instalando GitHub Desktop"

if ! apt install -y github-desktop; then

    error "Falha durante a instalação do GitHub Desktop."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "apt install retornou erro"
    fi

    exit 1
fi

# ============================================================
# Verificar instalação
# ============================================================

info "Validando instalação do GitHub Desktop"

if dpkg -s github-desktop >/dev/null 2>&1; then

    VERSAO="$(
        dpkg-query \
            -W \
            -f='${Version}' \
            github-desktop \
            2>/dev/null
    )"

    info "GitHub Desktop instalado com sucesso."
    info "Versão instalada: $VERSAO"

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "INSTALADO" \
            "GitHub Desktop" \
            "Versão $VERSAO"
    fi

else

    error "O pacote github-desktop não foi encontrado após a instalação."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "GitHub Desktop" \
            "Pacote não encontrado após instalação"
    fi

    exit 1
fi

# ============================================================
# Finalização
# ============================================================

echo
info "Instalação do GitHub Desktop concluída."
