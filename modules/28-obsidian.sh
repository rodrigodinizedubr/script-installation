#!/bin/bash

# ============================================================
# Instalação do Obsidian
#
# Estratégia:
#
#   - Detectar arquitetura
#   - Consultar a release oficial mais recente no GitHub
#   - Localizar automaticamente o pacote .deb amd64
#   - Baixar para diretório temporário
#   - Validar pacote Debian
#   - Instalar com apt
#   - Validar instalação
#   - Remover arquivos temporários
#
# Repositório oficial:
#
#   obsidianmd/obsidian-releases
#
# ============================================================

set -e


# ============================================================
# 1. Diretórios
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"


# ============================================================
# 2. Bibliotecas
# ============================================================

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"


# ============================================================
# 3. Configurações
# ============================================================

COMPONENT_NAME="Obsidian"

GITHUB_REPOSITORY="obsidianmd/obsidian-releases"

GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/latest"

DOWNLOAD_DIR="/tmp/obsidian-install"

OBSIDIAN_DEB=""


echo
echo "============================================================"
echo " Instalando Obsidian"
echo "============================================================"
echo


# ============================================================
# 4. Verificar configuração
# ============================================================

if [[ "${INSTALAR_OBSIDIAN:-true}" != "true" ]]; then

    warn "Obsidian desabilitado."
    warn "INSTALAR_OBSIDIAN=false"

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Desabilitado no config.conf"

    exit 0

fi


# ============================================================
# 5. Verificar root
# ============================================================

if [[ "$EUID" -ne 0 ]]; then

    error "Este módulo deve ser executado como root."

    echo
    error "Execute:"
    echo
    echo "    sudo bash modules/28-obsidian.sh"
    echo

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Execução sem privilégios de root"

    exit 1

fi


# ============================================================
# 6. Detectar arquitetura
# ============================================================

ARCH="$(dpkg --print-architecture)"

info "Arquitetura detectada:"
info "$ARCH"


if [[ "$ARCH" != "amd64" ]]; then

    error "O pacote .deb oficial utilizado por este script"
    error "é disponibilizado para arquitetura amd64."

    error "Arquitetura encontrada:"
    error "$ARCH"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Arquitetura não suportada: ${ARCH}"

    exit 1

fi


# ============================================================
# 7. Instalar dependências
# ============================================================

info "Verificando dependências..."

install_package curl
install_package jq
install_package ca-certificates


# ============================================================
# 8. Verificar instalação atual
# ============================================================

if dpkg-query \
    -W \
    -f='${Status}' \
    obsidian \
    2>/dev/null |
    grep -Fq "install ok installed"; then

    CURRENT_VERSION="$(
        dpkg-query \
            -W \
            -f='${Version}' \
            obsidian \
            2>/dev/null ||
            true
    )"

    info "Obsidian já está instalado."

    if [[ -n "$CURRENT_VERSION" ]]; then
        info "Versão instalada: $CURRENT_VERSION"
    fi

fi


# ============================================================
# 9. Consultar release oficial mais recente
# ============================================================

info "Consultando release oficial mais recente..."

RELEASE_JSON="$(
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --connect-timeout 15 \
        --max-time 60 \
        "$GITHUB_API_URL"
)"


if [[ -z "$RELEASE_JSON" ]]; then

    error "A API do GitHub não retornou dados."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Release oficial não encontrada"

    exit 1

fi


# ============================================================
# 10. Obter versão
# ============================================================

LATEST_TAG="$(
    printf '%s' "$RELEASE_JSON" |
    jq -r '.tag_name // empty'
)"


if [[ -z "$LATEST_TAG" ]]; then

    error "Não foi possível determinar a versão mais recente."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "tag_name ausente na release"

    exit 1

fi


LATEST_VERSION="${LATEST_TAG#v}"


info "Release encontrada:"
info "$LATEST_TAG"

info "Versão:"
info "$LATEST_VERSION"


# ============================================================
# 11. Localizar asset .deb amd64
# ============================================================

info "Localizando pacote .deb amd64..."


DEB_URL="$(
    printf '%s' "$RELEASE_JSON" |
    jq -r '
        .assets[]
        | select(
            (.name | test("^obsidian_[0-9].*_amd64\\.deb$"; "i"))
          )
        | .browser_download_url
    ' |
    head -n 1
)"


DEB_NAME="$(
    printf '%s' "$RELEASE_JSON" |
    jq -r '
        .assets[]
        | select(
            (.name | test("^obsidian_[0-9].*_amd64\\.deb$"; "i"))
          )
        | .name
    ' |
    head -n 1
)"


# ------------------------------------------------------------
# Fallback:
# procurar qualquer .deb amd64 caso o padrão de nome mude.
# ------------------------------------------------------------

if [[ -z "$DEB_URL" ||
      "$DEB_URL" == "null" ]]; then

    warn "Asset não encontrado pelo padrão principal."
    warn "Tentando busca genérica por .deb amd64..."


    DEB_URL="$(
        printf '%s' "$RELEASE_JSON" |
        jq -r '
            .assets[]
            | select(
                (.name | endswith(".deb"))
                and
                (.name | test("amd64"; "i"))
              )
            | .browser_download_url
        ' |
        head -n 1
    )"


    DEB_NAME="$(
        printf '%s' "$RELEASE_JSON" |
        jq -r '
            .assets[]
            | select(
                (.name | endswith(".deb"))
                and
                (.name | test("amd64"; "i"))
              )
            | .name
        ' |
        head -n 1
    )

fi


if [[ -z "$DEB_URL" ||
      "$DEB_URL" == "null" ||
      -z "$DEB_NAME" ||
      "$DEB_NAME" == "null" ]]; then

    error "Nenhum pacote .deb amd64 foi encontrado"
    error "na release ${LATEST_TAG}."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Asset .deb amd64 não encontrado"

    exit 1

fi


success "Pacote localizado:"
info "$DEB_NAME"


# ============================================================
# 12. Preparar diretório temporário
# ============================================================

info "Preparando diretório temporário..."

rm -rf "$DOWNLOAD_DIR"

mkdir -p "$DOWNLOAD_DIR"


OBSIDIAN_DEB="${DOWNLOAD_DIR}/${DEB_NAME}"


# ============================================================
# 13. Baixar pacote
# ============================================================

info "Baixando Obsidian..."

curl \
    --fail \
    --location \
    --show-error \
    --progress-bar \
    --connect-timeout 15 \
    --retry 3 \
    --retry-delay 2 \
    --output "$OBSIDIAN_DEB" \
    "$DEB_URL"


# ============================================================
# 14. Validar arquivo baixado
# ============================================================

if [[ ! -s "$OBSIDIAN_DEB" ]]; then

    error "O arquivo baixado está vazio ou não existe."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Download inválido"

    rm -rf "$DOWNLOAD_DIR"

    exit 1

fi


info "Validando pacote Debian..."


if ! dpkg-deb \
    --info \
    "$OBSIDIAN_DEB" \
    >/dev/null 2>&1; then

    error "O arquivo baixado não é um pacote Debian válido."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Pacote .deb inválido"

    rm -rf "$DOWNLOAD_DIR"

    exit 1

fi


success "Pacote Debian válido."


# ============================================================
# 15. Verificar arquitetura interna
# ============================================================

PACKAGE_ARCH="$(
    dpkg-deb \
        -f \
        "$OBSIDIAN_DEB" \
        Architecture
)"


info "Arquitetura do pacote:"
info "$PACKAGE_ARCH"


if [[ "$PACKAGE_ARCH" != "amd64" ]]; then

    error "Arquitetura inesperada no pacote:"
    error "$PACKAGE_ARCH"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Arquitetura incorreta no .deb"

    rm -rf "$DOWNLOAD_DIR"

    exit 1

fi


# ============================================================
# 16. Obter versão interna
# ============================================================

PACKAGE_VERSION="$(
    dpkg-deb \
        -f \
        "$OBSIDIAN_DEB" \
        Version \
        2>/dev/null ||
        true
)"


if [[ -n "$PACKAGE_VERSION" ]]; then

    info "Versão declarada pelo pacote:"
    info "$PACKAGE_VERSION"

fi


# ============================================================
# 17. Instalar / atualizar Obsidian
# ============================================================

info "Instalando Obsidian..."


apt-get install \
    -y \
    "$OBSIDIAN_DEB"


# ============================================================
# 18. Validar instalação no dpkg
# ============================================================

info "Validando instalação..."


if ! dpkg-query \
    -W \
    -f='${Status}' \
    obsidian \
    2>/dev/null |
    grep -Fq "install ok installed"; then

    error "O pacote Obsidian não aparece como instalado."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Pacote não registrado no dpkg"

    rm -rf "$DOWNLOAD_DIR"

    exit 1

fi


# ============================================================
# 19. Obter versão instalada
# ============================================================

INSTALLED_VERSION="$(
    dpkg-query \
        -W \
        -f='${Version}' \
        obsidian \
        2>/dev/null ||
        true
)"


# ============================================================
# 20. Verificar comando
# ============================================================

if command -v obsidian >/dev/null 2>&1; then

    OBSIDIAN_COMMAND="$(
        command -v obsidian
    )"

    success "Comando Obsidian localizado:"
    info "$OBSIDIAN_COMMAND"

else

    warn "O pacote está instalado,"
    warn "mas o comando obsidian não foi encontrado no PATH."

fi


# ============================================================
# 21. Localizar arquivo .desktop
# ============================================================

OBSIDIAN_DESKTOP="$(
    find \
        /usr/share/applications \
        /usr/local/share/applications \
        -maxdepth 1 \
        -type f \
        -iname '*obsidian*.desktop' \
        2>/dev/null |
    head -n 1
)"


if [[ -n "$OBSIDIAN_DESKTOP" ]]; then

    success "Atalho gráfico localizado:"
    info "$OBSIDIAN_DESKTOP"

    OBSIDIAN_DESKTOP_NAME="$(
        basename "$OBSIDIAN_DESKTOP"
    )"

else

    warn "Arquivo .desktop do Obsidian não foi localizado."

    OBSIDIAN_DESKTOP_NAME=""

fi


# ============================================================
# 22. Limpar arquivos temporários
# ============================================================

info "Removendo arquivos temporários..."

rm -rf "$DOWNLOAD_DIR"


# ============================================================
# 23. Resultado
# ============================================================

echo
echo "============================================================"
echo " Obsidian instalado"
echo "============================================================"
echo

echo "Release:"
echo "  ${LATEST_TAG}"
echo

if [[ -n "$INSTALLED_VERSION" ]]; then

    echo "Versão instalada:"
    echo "  ${INSTALLED_VERSION}"
    echo

fi

if [[ -n "$OBSIDIAN_DESKTOP_NAME" ]]; then

    echo "Arquivo .desktop:"
    echo "  ${OBSIDIAN_DESKTOP_NAME}"
    echo

fi

echo "Para executar:"
echo
echo "  obsidian"
echo


# ============================================================
# 24. Registrar resultado
# ============================================================

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Obsidian ${INSTALLED_VERSION:-${LATEST_VERSION}}"


success "Obsidian instalado com sucesso."

exit 0