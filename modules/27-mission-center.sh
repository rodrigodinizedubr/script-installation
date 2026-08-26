#!/bin/bash

# ============================================================
# Instalação do Mission Center
#
# Monitor de recursos para Linux.
#
# Instalação realizada via Flatpak / Flathub.
#
# Flatpak ID:
#
#   io.missioncenter.MissionCenter
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

COMPONENT_NAME="Mission Center"

FLATPAK_ID="io.missioncenter.MissionCenter"


echo
echo "============================================================"
echo " Instalando Mission Center"
echo "============================================================"
echo


# ============================================================
# 4. Verificar configuração
# ============================================================

if [[ "${INSTALAR_MISSION_CENTER:-true}" != "true" ]]; then

    warn "Mission Center desabilitado."
    warn "INSTALAR_MISSION_CENTER=false"

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Desabilitado no config.conf"

    exit 0

fi


# ============================================================
# 5. Instalar Flatpak
# ============================================================

info "Verificando Flatpak..."

install_package flatpak


if ! command -v flatpak >/dev/null 2>&1; then

    error "Flatpak não foi encontrado."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Flatpak não disponível"

    exit 1

fi


success "Flatpak disponível."


# ============================================================
# 6. Configurar Flathub
# ============================================================

info "Verificando repositório Flathub..."


if flatpak remotes \
    --system \
    --columns=name |
    grep -Fxq "flathub"; then

    success "Flathub já está configurado."

else

    info "Adicionando Flathub..."

    flatpak remote-add \
        --system \
        --if-not-exists \
        flathub \
        https://flathub.org/repo/flathub.flatpakrepo

    success "Flathub configurado."

fi


# ============================================================
# 7. Verificar instalação existente
# ============================================================

if flatpak info \
    --system \
    "$FLATPAK_ID" \
    >/dev/null 2>&1; then

    success "Mission Center já está instalado."

else

    # ========================================================
    # 8. Instalar Mission Center
    # ========================================================

    info "Instalando Mission Center..."

    flatpak install \
        --system \
        -y \
        flathub \
        "$FLATPAK_ID"

fi


# ============================================================
# 9. Validar instalação
# ============================================================

info "Validando instalação..."


if ! flatpak info \
    --system \
    "$FLATPAK_ID" \
    >/dev/null 2>&1; then

    error "Mission Center não foi localizado após a instalação."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Flatpak não localizado após instalação"

    exit 1

fi


# ============================================================
# 10. Obter versão
# ============================================================

MISSION_CENTER_VERSION="$(
    flatpak info \
        --system \
        --show-version \
        "$FLATPAK_ID" \
        2>/dev/null ||
        true
)"


# ============================================================
# 11. Resultado
# ============================================================

echo
echo "============================================================"
echo " Mission Center instalado"
echo "============================================================"
echo

echo "Flatpak ID:"
echo "  ${FLATPAK_ID}"
echo

if [[ -n "$MISSION_CENTER_VERSION" ]]; then

    echo "Versão:"
    echo "  ${MISSION_CENTER_VERSION}"
    echo

fi

echo "Para executar:"
echo
echo "  flatpak run ${FLATPAK_ID}"
echo


success "Mission Center instalado com sucesso."


# ============================================================
# 12. Registrar resultado
# ============================================================

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Mission Center ${MISSION_CENTER_VERSION:-instalado}"


exit 0