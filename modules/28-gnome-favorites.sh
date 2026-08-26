#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"
source "$BASE_DIR/lib/gnome.sh"

COMPONENTE="Favoritos GNOME"
SCHEMA="org.gnome.shell"
CHAVE="favorite-apps"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${CONFIGURAR_FAVORITOS_GNOME:-true}" != true ]; then
    info "Configuração dos favoritos do GNOME desabilitada."
    mark_component_skipped "$COMPONENTE" "CONFIGURAR_FAVORITOS_GNOME=false"
    mark_skipped "CONFIGURAR_FAVORITOS_GNOME=false"
    exit 0
fi

info "Configurando aplicativos favoritos do GNOME"

# ============================================================
# Preparar sessão GNOME
# ============================================================

gnome_detect_user || {
    record_component_status "FALHA" "$COMPONENTE" "Usuário GNOME não identificado"
    exit 1
}

info "Usuário GNOME: $GNOME_USER (UID $GNOME_UID)"

if ! gnome_session_available; then
    mark_component_skipped "$COMPONENTE" "Sessão GNOME não disponível"
    mark_skipped "Sessão GNOME do usuário $GNOME_USER não disponível"
    exit 0
fi

if ! gnome_schema_exists "$SCHEMA"; then
    error "Schema GNOME não encontrado: $SCHEMA"
    record_component_status "FALHA" "$COMPONENTE" "Schema $SCHEMA não encontrado"
    exit 1
fi

# ============================================================
# Verificar lista configurada
# ============================================================

if ! declare -p FAVORITOS_GNOME >/dev/null 2>&1; then
    error "A variável FAVORITOS_GNOME não foi definida no config.conf."
    record_component_status "FALHA" "$COMPONENTE" "FAVORITOS_GNOME não definida"
    exit 1
fi

if [ "${#FAVORITOS_GNOME[@]}" -eq 0 ]; then
    warn "A lista FAVORITOS_GNOME está vazia."
    mark_component_skipped "$COMPONENTE" "Lista FAVORITOS_GNOME vazia"
    mark_skipped "Lista FAVORITOS_GNOME vazia"
    exit 0
fi

# ============================================================
# Diretórios onde arquivos .desktop podem existir
# ============================================================

DIRETORIOS_DESKTOP=(
    # Aplicativos instalados localmente para o usuário
    "$GNOME_HOME/.local/share/applications"

    # Flatpaks instalados somente para o usuário
    "$GNOME_HOME/.local/share/flatpak/exports/share/applications"

    # Aplicativos instalados localmente no sistema
    "/usr/local/share/applications"

    # Aplicativos instalados via APT/.deb
    "/usr/share/applications"

    # Flatpaks instalados globalmente (--system)
    "/var/lib/flatpak/exports/share/applications"
)

# ============================================================
# Validar aplicativos na ordem definida no config.conf
# ============================================================

FAVORITOS_VALIDOS=()

info "Verificando aplicativos configurados"

for APP in "${FAVORITOS_GNOME[@]}"; do
    ENCONTRADO=false

    for DIRETORIO in "${DIRETORIOS_DESKTOP[@]}"; do
        if [ -f "$DIRETORIO/$APP" ]; then
            ENCONTRADO=true
            break
        fi
    done

    if [ "$ENCONTRADO" = true ]; then

        info "Aplicativo encontrado:"
        info "  $APP"
        info "  $DIRETORIO/$APP"

        FAVORITOS_VALIDOS+=("$APP")

    else

        warn "Aplicativo não encontrado: $APP"

    fi
done

if [ "${#FAVORITOS_VALIDOS[@]}" -eq 0 ]; then
    error "Nenhum aplicativo configurado foi encontrado."
    record_component_status "FALHA" "$COMPONENTE" "Nenhum arquivo .desktop encontrado"
    exit 1
fi

# ============================================================
# Remover duplicidades preservando a ordem
# ============================================================

FAVORITOS_UNICOS=()

for APP in "${FAVORITOS_VALIDOS[@]}"; do
    JA_EXISTE=false

    for EXISTENTE in "${FAVORITOS_UNICOS[@]}"; do
        if [ "$EXISTENTE" = "$APP" ]; then
            JA_EXISTE=true
            break
        fi
    done

    if [ "$JA_EXISTE" = false ]; then
        FAVORITOS_UNICOS+=("$APP")
    fi
done

# ============================================================
# Construir lista no formato esperado pelo gsettings
# ============================================================

LISTA="["
for APP in "${FAVORITOS_UNICOS[@]}"; do
    LISTA+="'$APP', "
done
LISTA="${LISTA%, }]"

# ============================================================
# Exibir ordem que será aplicada
# ============================================================

echo
info "Ordem dos favoritos que será aplicada:"
echo

POSICAO=1
for APP in "${FAVORITOS_UNICOS[@]}"; do
    printf "  %02d - %s\n" "$POSICAO" "$APP"
    POSICAO=$((POSICAO + 1))
done

echo
info "Favoritos atuais do GNOME:"
gnome_gsettings get "$SCHEMA" "$CHAVE"
echo

# ============================================================
# Aplicar e validar lista ordenada
# ============================================================

gnome_gsettings_set "$SCHEMA" "$CHAVE" "$LISTA"

success "Favoritos do GNOME configurados na ordem desejada."
record_component_status "OK" "$COMPONENTE" "Ordem aplicada e validada"
