#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"
source "$BASE_DIR/lib/gnome.sh"

EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"
SCHEMA="org.gnome.shell.extensions.dash-to-dock"
COMPONENTE="Dash to Dock"

# ============================================================
# Verificar ambiente GNOME
# ============================================================

info "Instalando e configurando Dash to Dock"

if ! command -v gnome-shell >/dev/null 2>&1; then
    error "GNOME Shell não foi encontrado."
    record_component_status "FALHA" "$COMPONENTE" "GNOME Shell não encontrado"
    exit 1
fi

info "GNOME detectado: $(gnome-shell --version)"

# ============================================================
# Instalar extensão e ferramenta de preferências
# ============================================================

install_package gnome-shell-extension-dashtodock
install_package gnome-shell-extension-prefs

# ============================================================
# Preparar sessão GNOME
# ============================================================

gnome_detect_user || {
    record_component_status "FALHA" "$COMPONENTE" "Usuário GNOME não identificado"
    exit 1
}

info "Usuário GNOME: $GNOME_USER (UID $GNOME_UID)"

if ! gnome_session_available; then
    warn "Dash to Dock foi instalado, mas a sessão GNOME não está disponível para configuração."
    warn "Entre no GNOME como $GNOME_USER e execute novamente este módulo."
    mark_component_skipped "$COMPONENTE" "Pacote instalado; sessão GNOME não disponível para configuração"
    mark_skipped "Dash to Dock instalado; aguardando sessão GNOME do usuário $GNOME_USER"
    exit 0
fi

# ============================================================
# Verificar schema
# ============================================================

if ! gnome_schema_exists "$SCHEMA"; then
    warn "O schema $SCHEMA ainda não está disponível para a sessão atual."
    warn "Isso pode acontecer imediatamente após instalar uma extensão GNOME."
    warn "Encerre a sessão GNOME, entre novamente e execute este módulo outra vez."
    mark_component_skipped "$COMPONENTE" "Pacote instalado; schema ainda não carregado pela sessão GNOME"
    mark_skipped "Dash to Dock instalado; schema ainda não carregado pela sessão GNOME"
    exit 0
fi

# ============================================================
# Aplicar e validar Posição e tamanho
# ============================================================

gnome_gsettings_set "$SCHEMA" "multi-monitor" "true"
gnome_gsettings_set "$SCHEMA" "dock-position" "'LEFT'"
gnome_gsettings_set "$SCHEMA" "intellihide" "false"
gnome_gsettings_set "$SCHEMA" "autohide" "false"
gnome_gsettings_set "$SCHEMA" "dock-fixed" "true"
gnome_gsettings_set "$SCHEMA" "height-fraction" "0.72"
gnome_gsettings_set "$SCHEMA" "extend-height" "true"
gnome_gsettings_set "$SCHEMA" "dash-max-icon-size" "32"

# ============================================================
# Pré-visualização das janelas
# ============================================================
# O procedimento original não definiu um valor para
# preview-size-scale. Por isso essa chave permanece inalterada.
# Exemplo para 50%:
# gnome_gsettings_set "$SCHEMA" "preview-size-scale" "0.5"

# ============================================================
# Aplicar e validar Aparência
# ============================================================

gnome_gsettings_set "$SCHEMA" "custom-theme-shrink" "true"
gnome_gsettings_set "$SCHEMA" "transparency-mode" "'FIXED'"
gnome_gsettings_set "$SCHEMA" "background-opacity" "0.0"

# ============================================================
# Habilitar extensão
# ============================================================

if ! command -v gnome-extensions >/dev/null 2>&1; then
    error "Comando gnome-extensions não encontrado após a instalação."
    record_component_status "FALHA" "$COMPONENTE" "gnome-extensions não encontrado"
    exit 1
fi

if gnome_extensions list | grep -Fxq "$EXTENSION_UUID"; then
    info "Habilitando extensão $EXTENSION_UUID"

    if gnome_extensions enable "$EXTENSION_UUID"; then
        success "Dash to Dock habilitado na sessão GNOME."
    else
        warn "As preferências foram gravadas, mas a extensão não pôde ser habilitada nesta sessão."
        warn "Faça logout/login e verifique novamente."
        record_component_status "FALHA" "$COMPONENTE" "Preferências aplicadas, mas falhou ao habilitar extensão"
        exit 1
    fi
else
    warn "A extensão ainda não aparece em 'gnome-extensions list'."
    warn "As preferências foram gravadas, porém um logout/login pode ser necessário para carregar a extensão."
    record_component_status "IGNORADO" "$COMPONENTE" "Preferências aplicadas; extensão aguardando recarga da sessão GNOME"
    mark_skipped "Dash to Dock configurado; extensão aguardando logout/login"
    exit 0
fi

# ============================================================
# Resultado
# ============================================================

success "Dash to Dock instalado, configurado, validado e habilitado."
record_component_status "OK" "$COMPONENTE" "Preferências aplicadas e extensão habilitada"
