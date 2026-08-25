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
PACKET_TRACER_USER="${USUARIO:-${SUDO_USER:-}}"
DOWNLOAD_DIR=""
GDOWN_CMD=""
VENV_DIR=""
INSTALLER_PATH=""
PACKAGE_NAME=""

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
        # Em distribuições nas quais gdown não está disponível via APT,
        # usa um venv temporário para não alterar o Python do sistema.
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

PACKAGE_NAME="$(dpkg-deb -f "$INSTALLER_PATH" Package 2>/dev/null || true)"

info "Instalando pacote: $(basename "$INSTALLER_PATH")"

# O APT instala o arquivo local e resolve suas dependências automaticamente.
if ! apt install -y "$INSTALLER_PATH"; then
    error "Falha ao instalar o Cisco Packet Tracer."
    record_component_status "FALHA" "Cisco Packet Tracer" "apt install retornou erro"
    exit 1
fi

# ---------------------------------------------------------------------------
# Validação pós-instalação
# ---------------------------------------------------------------------------
POST_INSTALL_OK=true

if [ -n "$PACKAGE_NAME" ]; then
    if dpkg -s "$PACKAGE_NAME" >/dev/null 2>&1; then
        success "Pacote Debian instalado e registrado: $PACKAGE_NAME"
    else
        error "O pacote $PACKAGE_NAME não aparece como instalado no dpkg."
        POST_INSTALL_OK=false
    fi
else
    warn "Não foi possível determinar o nome interno do pacote para validação via dpkg."
fi

if command -v packettracer >/dev/null 2>&1; then
    PACKET_TRACER_CMD="$(command -v packettracer)"
    success "Comando packettracer disponível: $PACKET_TRACER_CMD"
elif [ -x /opt/pt/packettracer ]; then
    PACKET_TRACER_CMD="/opt/pt/packettracer"
    success "Executável do Packet Tracer encontrado: $PACKET_TRACER_CMD"
else
    error "O comando 'packettracer' não foi encontrado após a instalação."
    POST_INSTALL_OK=false
fi

if [ -f /opt/pt/packettracer.AppImage ]; then
    success "Aplicação principal encontrada: /opt/pt/packettracer.AppImage"
elif [ -d /opt/pt ]; then
    warn "Diretório /opt/pt existe, mas /opt/pt/packettracer.AppImage não foi encontrado."
else
    warn "Diretório esperado /opt/pt não foi encontrado."
fi

if [ "$POST_INSTALL_OK" != true ]; then
    record_component_status "FALHA" "Cisco Packet Tracer" "Instalação concluída, mas a validação pós-instalação falhou"
    exit 1
fi

success "Cisco Packet Tracer instalado e validado com sucesso."
record_component_status "INSTALADO" "Cisco Packet Tracer" "Pacote $PACKET_TRACER_FILENAME instalado e validado"

# ---------------------------------------------------------------------------
# Primeira execução / EULA
# ---------------------------------------------------------------------------
echo
info "Primeira execução do Cisco Packet Tracer"
info "A EULA da Cisco deve ser revisada e aceita interativamente pelo usuário."

if [ -n "$PACKET_TRACER_USER" ] && id "$PACKET_TRACER_USER" >/dev/null 2>&1; then
    info "Usuário da sessão: $PACKET_TRACER_USER"
else
    PACKET_TRACER_USER=""
    warn "Não foi possível determinar um usuário gráfico válido para a primeira execução."
fi

echo
warn "Não execute o Packet Tracer como root e não use 'sudo packettracer'."
info "Abra um terminal na sessão gráfica do usuário normal e execute:"
echo
echo "    packettracer"
echo
info "Na primeira execução será exibida a EULA."
info "Leia os termos e escolha a opção de aceitação somente se concordar com eles."
info "No Packet Tracer 9.0.1 atualmente instalado, a tela apresenta:"
echo
echo "    1) Show EULA text again"
echo "    2) Accept EULA"
echo "    3) Decline EULA"
echo
info "O script não aceita a EULA automaticamente e não inicia a interface gráfica como root."
