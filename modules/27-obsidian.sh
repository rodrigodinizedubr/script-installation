#!/bin/bash

# ============================================================
# Instalação do Obsidian + Excalidraw
#
# Este módulo:
#
#   - instala/atualiza o Obsidian via pacote .deb oficial;
#   - procura a release desktop mais recente com .deb amd64;
#   - cria o Vault padrão;
#   - instala o plugin Excalidraw;
#   - habilita o plugin no Vault;
#   - preserva plugins já existentes;
#   - corrige ownership apenas do que foi criado;
#   - valida instalação.
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
# 3. Configurações gerais
# ============================================================

COMPONENT_NAME="Obsidian"

GITHUB_REPOSITORY="obsidianmd/obsidian-releases"

GITHUB_RELEASES_API="https://api.github.com/repos/${GITHUB_REPOSITORY}/releases?per_page=30"

DOWNLOAD_DIR="/tmp/obsidian-install"


# ============================================================
# 4. Usuário e Vault
# ============================================================

OBSIDIAN_USER="${USUARIO:-operador}"

if ! id "$OBSIDIAN_USER" >/dev/null 2>&1; then

    error "Usuário não encontrado:"
    error "$OBSIDIAN_USER"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Usuário não encontrado"

    exit 1
fi


OBSIDIAN_GROUP="$(
    id -gn "$OBSIDIAN_USER"
)"


OBSIDIAN_HOME="$(
    getent passwd "$OBSIDIAN_USER" |
    cut -d: -f6
)"


OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-${OBSIDIAN_HOME}/Documentos/Code/Obsidian}"


# ============================================================
# 5. Excalidraw
# ============================================================

EXCALIDRAW_PLUGIN_ID="obsidian-excalidraw-plugin"

EXCALIDRAW_REPOSITORY="zsviczian/obsidian-excalidraw-plugin"

EXCALIDRAW_RELEASE_API="https://api.github.com/repos/${EXCALIDRAW_REPOSITORY}/releases/latest"

OBSIDIAN_CONFIG_DIR="${OBSIDIAN_VAULT}/.obsidian"

OBSIDIAN_PLUGINS_DIR="${OBSIDIAN_CONFIG_DIR}/plugins"

EXCALIDRAW_PLUGIN_DIR="${OBSIDIAN_PLUGINS_DIR}/${EXCALIDRAW_PLUGIN_ID}"

COMMUNITY_PLUGINS_FILE="${OBSIDIAN_CONFIG_DIR}/community-plugins.json"


echo
echo "============================================================"
echo " Instalando Obsidian"
echo "============================================================"
echo


# ============================================================
# 6. Verificar configuração
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
# 7. Verificar root
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
        "Execução sem root"

    exit 1
fi


# ============================================================
# 8. Detectar arquitetura
# ============================================================

ARCH="$(dpkg --print-architecture)"

info "Arquitetura detectada:"
info "$ARCH"


if [[ "$ARCH" != "amd64" ]]; then

    error "Arquitetura não suportada por este módulo:"
    error "$ARCH"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Arquitetura não suportada: ${ARCH}"

    exit 1
fi


# ============================================================
# 9. Dependências
# ============================================================

info "Verificando dependências..."

install_package curl
install_package jq
install_package ca-certificates


# ============================================================
# 10. Verificar versão instalada
# ============================================================

CURRENT_VERSION=""

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
# 11. Consultar releases oficiais
# ============================================================

info "Consultando releases oficiais do Obsidian..."


RELEASES_JSON="$(
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --connect-timeout 15 \
        --max-time 60 \
        -H "Accept: application/vnd.github+json" \
        "$GITHUB_RELEASES_API"
)"


if [[ -z "$RELEASES_JSON" ]]; then

    error "Resposta vazia da API do GitHub."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "API GitHub sem resposta"

    exit 1
fi


# ============================================================
# 12. Localizar release com .deb amd64
# ============================================================

info "Procurando release desktop com pacote .deb amd64..."


RELEASE_DATA="$(
    printf '%s' "$RELEASES_JSON" |
    jq -r '
        [
            .[]
            | select(.draft == false)
            | {
                tag: .tag_name,
                asset: (
                    .assets[]
                    | select(
                        .name
                        | test("_amd64\\.deb$"; "i")
                    )
                )
            }
        ]
        | .[0]
        | select(. != null)
        | [
            .tag,
            .asset.name,
            .asset.browser_download_url
          ]
        | @tsv
    '
)"


if [[ -z "$RELEASE_DATA" ||
      "$RELEASE_DATA" == "null" ]]; then

    error "Nenhuma release com .deb amd64 encontrada."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Release desktop não encontrada"

    exit 1
fi


IFS=$'\t' read -r \
    LATEST_TAG \
    DEB_NAME \
    DEB_URL \
    <<< "$RELEASE_DATA"


LATEST_VERSION="${LATEST_TAG#v}"


success "Release desktop encontrada:"
info "$LATEST_TAG"

info "Pacote:"
info "$DEB_NAME"


# ============================================================
# 13. Verificar se já está atualizado
# ============================================================

NORMALIZED_CURRENT="${CURRENT_VERSION%%-*}"

if [[ -n "$CURRENT_VERSION" &&
      "$NORMALIZED_CURRENT" == "$LATEST_VERSION" ]]; then

    success "Obsidian já está na versão mais recente."

    SKIP_INSTALL=true

else

    SKIP_INSTALL=false

fi


# ============================================================
# 14. Baixar e instalar
# ============================================================

if [[ "$SKIP_INSTALL" != true ]]; then

    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    OBSIDIAN_DEB="${DOWNLOAD_DIR}/${DEB_NAME}"


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


    if [[ ! -s "$OBSIDIAN_DEB" ]]; then

        error "Download do Obsidian inválido."

        rm -rf "$DOWNLOAD_DIR"

        exit 1
    fi


    info "Validando pacote Debian..."


    if ! dpkg-deb \
        --info \
        "$OBSIDIAN_DEB" \
        >/dev/null 2>&1; then

        error "Pacote Debian inválido."

        rm -rf "$DOWNLOAD_DIR"

        exit 1
    fi


    PACKAGE_ARCH="$(
        dpkg-deb \
            -f \
            "$OBSIDIAN_DEB" \
            Architecture
    )"


    if [[ "$PACKAGE_ARCH" != "amd64" ]]; then

        error "Arquitetura incorreta no pacote:"
        error "$PACKAGE_ARCH"

        rm -rf "$DOWNLOAD_DIR"

        exit 1
    fi


    info "Instalando/atualizando Obsidian..."


    apt-get install \
        -y \
        "$OBSIDIAN_DEB"

fi


# ============================================================
# 15. Validar instalação
# ============================================================

if ! dpkg-query \
    -W \
    -f='${Status}' \
    obsidian \
    2>/dev/null |
    grep -Fq "install ok installed"; then

    error "Obsidian não aparece como instalado."

    exit 1
fi


INSTALLED_VERSION="$(
    dpkg-query \
        -W \
        -f='${Version}' \
        obsidian \
        2>/dev/null ||
        true
)"


success "Obsidian instalado."

info "Versão:"
info "$INSTALLED_VERSION"


# ============================================================
# 16. Localizar .desktop
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

    OBSIDIAN_DESKTOP_NAME="$(
        basename "$OBSIDIAN_DESKTOP"
    )"

    success "Atalho gráfico localizado:"
    info "$OBSIDIAN_DESKTOP_NAME"

else

    warn "Arquivo .desktop não localizado."

    OBSIDIAN_DESKTOP_NAME=""

fi


# ============================================================
# 17. Criar Vault
# ============================================================

echo
info "Preparando Vault do Obsidian..."


if [[ ! -d "$OBSIDIAN_VAULT" ]]; then

    mkdir -p "$OBSIDIAN_VAULT"

    chown \
        "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
        "$OBSIDIAN_VAULT"

    success "Vault criado."

else

    info "Vault já existe."

fi


info "Vault:"
info "$OBSIDIAN_VAULT"


# ============================================================
# 18. Criar estrutura .obsidian
# ============================================================

mkdir -p "$OBSIDIAN_CONFIG_DIR"
mkdir -p "$OBSIDIAN_PLUGINS_DIR"


chown \
    "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
    "$OBSIDIAN_CONFIG_DIR"


chown \
    "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
    "$OBSIDIAN_PLUGINS_DIR"


# ============================================================
# 19. Instalar Excalidraw
# ============================================================

if [[ "${INSTALAR_OBSIDIAN_EXCALIDRAW:-true}" == "true" ]]; then

    echo
    echo "============================================================"
    echo " Instalando plugin Excalidraw"
    echo "============================================================"
    echo


    # ========================================================
    # 20. Consultar release
    # ========================================================

    info "Consultando release mais recente do Excalidraw..."


    EXCALIDRAW_RELEASE_JSON="$(
        curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 15 \
            --max-time 60 \
            -H "Accept: application/vnd.github+json" \
            "$EXCALIDRAW_RELEASE_API"
    )"


    if [[ -z "$EXCALIDRAW_RELEASE_JSON" ]]; then

        error "Não foi possível consultar release do Excalidraw."

        exit 1
    fi


    EXCALIDRAW_TAG="$(
        printf '%s' "$EXCALIDRAW_RELEASE_JSON" |
        jq -r '.tag_name // empty'
    )"


    if [[ -z "$EXCALIDRAW_TAG" ]]; then

        error "Tag da release Excalidraw não encontrada."

        exit 1
    fi


    info "Release Excalidraw:"
    info "$EXCALIDRAW_TAG"


    # ========================================================
    # 21. Preparar diretório
    # ========================================================

    mkdir -p "$EXCALIDRAW_PLUGIN_DIR"

    chown \
        "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
        "$EXCALIDRAW_PLUGIN_DIR"


    # ========================================================
    # 22. Baixar arquivos do plugin
    #
    # Community plugins do Obsidian usam:
    #
    #   main.js
    #   manifest.json
    #   styles.css
    #
    # styles.css pode eventualmente não existir.
    # ========================================================

    for ASSET in \
        manifest.json \
        main.js \
        styles.css; do

        ASSET_URL="$(
            printf '%s' "$EXCALIDRAW_RELEASE_JSON" |
            jq -r \
                --arg asset "$ASSET" \
                '
                .assets[]
                | select(.name == $asset)
                | .browser_download_url
                ' |
            head -n 1
        )"


        if [[ -z "$ASSET_URL" ||
              "$ASSET_URL" == "null" ]]; then

            if [[ "$ASSET" == "styles.css" ]]; then

                warn "styles.css não encontrado."
                warn "Prosseguindo sem ele."

                continue

            fi


            error "Asset obrigatório não encontrado:"
            error "$ASSET"

            exit 1
        fi


        info "Baixando:"
        info "$ASSET"


        curl \
            --fail \
            --location \
            --show-error \
            --silent \
            --output "${EXCALIDRAW_PLUGIN_DIR}/${ASSET}" \
            "$ASSET_URL"


        if [[ ! -s "${EXCALIDRAW_PLUGIN_DIR}/${ASSET}" ]]; then

            error "Arquivo inválido:"
            error "$ASSET"

            exit 1
        fi

    done


    # ========================================================
    # 23. Validar manifest
    # ========================================================

    MANIFEST_FILE="${EXCALIDRAW_PLUGIN_DIR}/manifest.json"


    if ! jq empty \
        "$MANIFEST_FILE" \
        >/dev/null 2>&1; then

        error "manifest.json do Excalidraw inválido."

        exit 1
    fi


    MANIFEST_ID="$(
        jq -r '.id // empty' \
            "$MANIFEST_FILE"
    )"


    MANIFEST_VERSION="$(
        jq -r '.version // empty' \
            "$MANIFEST_FILE"
    )"


    if [[ "$MANIFEST_ID" != "$EXCALIDRAW_PLUGIN_ID" ]]; then

        error "ID inesperado no manifest Excalidraw:"
        error "$MANIFEST_ID"

        exit 1
    fi


    success "Excalidraw instalado."

    info "Versão:"
    info "$MANIFEST_VERSION"


    # ========================================================
    # 24. Corrigir ownership dos arquivos do plugin
    # ========================================================

    chown \
        "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
        "$EXCALIDRAW_PLUGIN_DIR"


    find "$EXCALIDRAW_PLUGIN_DIR" \
        -maxdepth 1 \
        -type f \
        -exec chown \
            "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
            {} \;


    # ========================================================
    # 25. Habilitar community plugin
    #
    # Não sobrescrevemos outros plugins.
    # ========================================================

    info "Habilitando Excalidraw no Vault..."


    if [[ -f "$COMMUNITY_PLUGINS_FILE" ]]; then

        # ----------------------------------------------------
        # Validar JSON existente
        # ----------------------------------------------------

        if ! jq empty \
            "$COMMUNITY_PLUGINS_FILE" \
            >/dev/null 2>&1; then

            error "community-plugins.json existente é inválido."

            exit 1
        fi


        TEMP_COMMUNITY="$(
            mktemp
        )"


        jq \
            --arg plugin "$EXCALIDRAW_PLUGIN_ID" \
            '
            if index($plugin) then
                .
            else
                . + [$plugin]
            end
            ' \
            "$COMMUNITY_PLUGINS_FILE" \
            > "$TEMP_COMMUNITY"


        cat "$TEMP_COMMUNITY" \
            > "$COMMUNITY_PLUGINS_FILE"


        rm -f "$TEMP_COMMUNITY"

    else

        printf '[\n  "%s"\n]\n' \
            "$EXCALIDRAW_PLUGIN_ID" \
            > "$COMMUNITY_PLUGINS_FILE"

    fi


    chown \
        "${OBSIDIAN_USER}:${OBSIDIAN_GROUP}" \
        "$COMMUNITY_PLUGINS_FILE"


    # ========================================================
    # 26. Validar habilitação
    # ========================================================

    if jq -e \
        --arg plugin "$EXCALIDRAW_PLUGIN_ID" \
        'index($plugin) != null' \
        "$COMMUNITY_PLUGINS_FILE" \
        >/dev/null; then

        success "Excalidraw registrado em community-plugins.json."

    else

        error "Não foi possível habilitar Excalidraw."

        exit 1
    fi


else

    warn "Excalidraw desabilitado."
    warn "INSTALAR_OBSIDIAN_EXCALIDRAW=false"

fi


# ============================================================
# 27. Limpeza
# ============================================================

if [[ -d "$DOWNLOAD_DIR" ]]; then

    info "Removendo arquivos temporários..."

    rm -rf "$DOWNLOAD_DIR"

fi


# ============================================================
# 28. Resultado
# ============================================================

echo
echo "============================================================"
echo " Obsidian configurado"
echo "============================================================"
echo

echo "Usuário:"
echo "  ${OBSIDIAN_USER}"
echo

echo "Versão Obsidian:"
echo "  ${INSTALLED_VERSION:-desconhecida}"
echo

echo "Vault:"
echo "  ${OBSIDIAN_VAULT}"
echo


if [[ -n "$OBSIDIAN_DESKTOP_NAME" ]]; then

    echo "Arquivo .desktop:"
    echo "  ${OBSIDIAN_DESKTOP_NAME}"
    echo

fi


if [[ "${INSTALAR_OBSIDIAN_EXCALIDRAW:-true}" == "true" ]]; then

    echo "Excalidraw:"
    echo "  Instalado"
    echo
    echo "Plugin ID:"
    echo "  ${EXCALIDRAW_PLUGIN_ID}"
    echo

fi


echo "Para abrir o Obsidian:"
echo
echo "  obsidian"
echo


# ============================================================
# 29. Registrar componente
# ============================================================

if [[ "${INSTALAR_OBSIDIAN_EXCALIDRAW:-true}" == "true" ]]; then

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Obsidian ${INSTALLED_VERSION} + Excalidraw"

else

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Obsidian ${INSTALLED_VERSION}"

fi


success "Obsidian configurado com sucesso."

exit 0