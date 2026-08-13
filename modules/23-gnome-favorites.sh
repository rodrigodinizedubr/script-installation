#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${CONFIGURAR_FAVORITOS_GNOME:-true}" != true ]; then
    info "Configuração dos favoritos do GNOME desabilitada."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "IGNORADO" \
            "Favoritos GNOME" \
            "CONFIGURAR_FAVORITOS_GNOME=false"
    fi

    exit 0
fi

info "Configurando aplicativos favoritos do GNOME"

# ============================================================
# Verificar usuário
# ============================================================

if ! id "$USUARIO" >/dev/null 2>&1; then
    error "Usuário $USUARIO não encontrado."
    exit 1
fi

UID_USUARIO="$(id -u "$USUARIO")"
DBUS_SOCKET="/run/user/$UID_USUARIO/bus"

# ============================================================
# Verificar gsettings
# ============================================================

if ! command -v gsettings >/dev/null 2>&1; then
    error "Comando gsettings não encontrado."
    exit 1
fi

# ============================================================
# Verificar sessão gráfica / D-Bus
# ============================================================

if [ ! -S "$DBUS_SOCKET" ]; then
    warn "D-Bus da sessão gráfica do usuário $USUARIO não encontrado."
    warn "Arquivo esperado: $DBUS_SOCKET"

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "IGNORADO" \
            "Favoritos GNOME" \
            "Sessão gráfica do usuário não disponível"
    fi

    exit 0
fi

# ============================================================
# Função para executar gsettings na sessão do usuário
# ============================================================

gsettings_usuario() {
    sudo -u "$USUARIO" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCKET" \
        gsettings "$@"
}

# ============================================================
# Verificar lista configurada
# ============================================================

if ! declare -p FAVORITOS_GNOME >/dev/null 2>&1; then
    error "A variável FAVORITOS_GNOME não foi definida no config.conf."
    exit 1
fi

if [ "${#FAVORITOS_GNOME[@]}" -eq 0 ]; then
    warn "A lista FAVORITOS_GNOME está vazia."
    exit 0
fi

# ============================================================
# Diretórios onde arquivos .desktop podem existir
# ============================================================

DIRETORIOS_DESKTOP=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "/home/$USUARIO/.local/share/applications"
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

        info "Aplicativo encontrado: $APP"
        FAVORITOS_VALIDOS+=("$APP")

    else

        warn "Aplicativo não encontrado: $APP"

    fi

done

# ============================================================
# Verificar se algum aplicativo foi encontrado
# ============================================================

if [ "${#FAVORITOS_VALIDOS[@]}" -eq 0 ]; then
    error "Nenhum aplicativo configurado foi encontrado."
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

LISTA="${LISTA%, }"
LISTA+="]"

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

# ============================================================
# Mostrar configuração atual
# ============================================================

info "Favoritos atuais do GNOME:"

FAVORITOS_ANTES="$(
    gsettings_usuario get \
        org.gnome.shell \
        favorite-apps
)"

echo "$FAVORITOS_ANTES"
echo

# ============================================================
# Aplicar lista ordenada
# ============================================================

info "Aplicando nova ordem dos favoritos"

gsettings_usuario set \
    org.gnome.shell \
    favorite-apps \
    "$LISTA"

# ============================================================
# Ler configuração após alteração
# ============================================================

FAVORITOS_DEPOIS="$(
    gsettings_usuario get \
        org.gnome.shell \
        favorite-apps
)"

echo
info "Favoritos após configuração:"
echo "$FAVORITOS_DEPOIS"
echo

# ============================================================
# Validar a ordem final
# ============================================================

LISTA_ESPERADA="$LISTA"

if [ "$FAVORITOS_DEPOIS" = "$LISTA_ESPERADA" ]; then

    info "Favoritos do GNOME configurados na ordem desejada."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "OK" \
            "Favoritos GNOME" \
            "Ordem aplicada e validada"
    fi

    exit 0

else

    error "A configuração final dos favoritos diverge da lista esperada."

    echo
    error "Esperado:"
    echo "$LISTA_ESPERADA"

    echo
    error "Obtido:"
    echo "$FAVORITOS_DEPOIS"

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "Favoritos GNOME" \
            "Verificação final divergente"
    fi

    exit 1
fi
