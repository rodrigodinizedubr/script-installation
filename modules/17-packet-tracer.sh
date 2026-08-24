#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

if [ "${INSTALAR_PACKET_TRACER:-false}" != true ]; then
    mark_skipped "Instalação do Cisco Packet Tracer desabilitada (INSTALAR_PACKET_TRACER=false)."
    exit 0
fi

info "Instalando Cisco Packet Tracer"

PACKET_TRACER_FILENAME="${PACKET_TRACER_FILENAME:-CiscoPacketTracer_901_Ubuntu_64bit.deb}"
PACKET_TRACER_DRIVE_FOLDER_URL="${PACKET_TRACER_DRIVE_FOLDER_URL:-}"
DOWNLOAD_DIR=""
GDOWN_CMD=""
VENV_DIR=""
INSTALLER_PATH=""

cleanup() {
    [ -z "$DOWNLOAD_DIR" ] || rm -rf "$DOWNLOAD_DIR"
    [ -z "$VENV_DIR" ] || rm -rf "$VENV_DIR"
}
trap cleanup EXIT

# Um arquivo local configurado explicitamente sempre tem prioridade.
if [ -n "${PACKET_TRACER_DEB:-}" ] && [ -f "$PACKET_TRACER_DEB" ]; then
    INSTALLER_PATH="$PACKET_TRACER_DEB"
    info "Usando instalador local: $INSTALLER_PATH"
else
    if [ -z "$PACKET_TRACER_DRIVE_FOLDER_URL" ]; then
        error "PACKET_TRACER_DRIVE_FOLDER_URL não foi configurado em config.conf."
        record_component_status "FALHA" "Cisco Packet Tracer" "URL da pasta do Google Drive não configurada"
        exit 1
    fi

    info "O instalador local não foi informado. Será usado o Google Drive."
    info "Arquivo esperado: $PACKET_TRACER_FILENAME"

    # Preferir o pacote gdown da própria distribuição quando disponível.
    if command_exists gdown; then
        GDOWN_CMD="$(command -v gdown)"
        info "gdown já está disponível: $GDOWN_CMD"
    elif apt-cache show gdown >/dev/null 2>&1; then
        install_package gdown
        GDOWN_CMD="$(command -v gdown)"
    else
        # Debian 12 não fornece gdown no repositório padrão. Usa um venv
        # temporário para evitar pip --user como root e PEP 668.
        info "Pacote gdown não disponível via APT; preparando ambiente Python temporário."
        install_package python3-venv

        VENV_DIR="$(mktemp -d /tmp/packettracer-gdown.XXXXXX)"
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip
        "$VENV_DIR/bin/python" -m pip install --quiet gdown
        GDOWN_CMD="$VENV_DIR/bin/gdown"
    fi

    if [ ! -x "$GDOWN_CMD" ]; then
        error "Não foi possível disponibilizar o gdown."
        record_component_status "FALHA" "Cisco Packet Tracer" "gdown indisponível"
        exit 1
    fi

    DOWNLOAD_DIR="$(mktemp -d /tmp/packettracer-download.XXXXXX)"

    info "Baixando conteúdo da pasta pública do Google Drive..."
    if ! "$GDOWN_CMD" --folder "$PACKET_TRACER_DRIVE_FOLDER_URL" -O "$DOWNLOAD_DIR"; then
        error "Falha ao acessar ou baixar a pasta do Google Drive."
        warn "Confirme se a pasta está compartilhada como 'Qualquer pessoa com o link'."
        record_component_status "FALHA" "Cisco Packet Tracer" "Falha no download pelo Google Drive"
        exit 1
    fi

    INSTALLER_PATH="$(find "$DOWNLOAD_DIR" -type f -name "$PACKET_TRACER_FILENAME" -print -quit)"

    if [ -z "$INSTALLER_PATH" ] || [ ! -f "$INSTALLER_PATH" ]; then
        error "O arquivo $PACKET_TRACER_FILENAME não foi encontrado na pasta baixada."
        record_component_status "FALHA" "Cisco Packet Tracer" "Arquivo esperado não encontrado no Google Drive"
        exit 1
    fi

    success "Instalador localizado: $PACKET_TRACER_FILENAME"
fi

# Validar se realmente recebemos um pacote Debian antes da instalação.
if ! dpkg-deb --info "$INSTALLER_PATH" >/dev/null 2>&1; then
    error "O arquivo obtido não é um pacote .deb válido: $INSTALLER_PATH"
    record_component_status "FALHA" "Cisco Packet Tracer" "Arquivo .deb inválido"
    exit 1
fi

info "Instalando pacote: $(basename "$INSTALLER_PATH")"

# O APT instala o arquivo local e resolve suas dependências automaticamente.
if apt install -y "$INSTALLER_PATH"; then
    success "Cisco Packet Tracer instalado com sucesso."
    record_component_status "INSTALADO" "Cisco Packet Tracer" "Pacote $PACKET_TRACER_FILENAME instalado"
else
    error "Falha ao instalar o Cisco Packet Tracer."
    record_component_status "FALHA" "Cisco Packet Tracer" "apt install retornou erro"
    exit 1
fi
