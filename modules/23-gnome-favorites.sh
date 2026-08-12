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
# Verificar D-Bus da sessão gráfica
# ============================================================

if [ ! -S "$DBUS_SOCKET" ]; then
    warn "D-Bus da sessão gráfica do usuário $USUARIO não encontrado."
    warn "Arquivo esperado: $DBUS_SOCKET"
    warn "Os favoritos do GNOME não serão alterados."
    exit 0
fi

# ============================================================
# Função para executar gsettings como o usuário correto
# ============================================================

gsettings_usuario() {
    sudo -u "$USUARIO" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCKET" \
        gsettings "$@"
}

# ============================================================
# Aplicativos que desejamos adicionar aos favoritos
# ============================================================

APLICATIVOS=(
    "org.gnome.Terminal.desktop"
    "firefox-esr.desktop"
    "google-chrome.desktop"
    "com.obsproject.Studio.desktop"
    "org.shotcut.Shotcut.desktop"
    "org.flameshot.Flameshot.desktop"
    "org.wireshark.Wireshark.desktop"
    "com.gexperts.Tilix.desktop"
    "code.desktop"
    "github-desktop.desktop"
)

# ============================================================
# Diretórios onde arquivos .desktop podem existir
# ============================================================

DIRETORIOS_DESKTOP=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "/home/$USUARIO/.local/share/applications"
)

# ============================================================
# Localizar aplicativos realmente instalados
# ============================================================

NOVOS_FAVORITOS=()

for APP in "${APLICATIVOS[@]}"; do

    ENCONTRADO=false

    for DIRETORIO in "${DIRETORIOS_DESKTOP[@]}"; do

        if [ -f "$DIRETORIO/$APP" ]; then

            info "Aplicativo encontrado: $APP"

            NOVOS_FAVORITOS+=("$APP")

            ENCONTRADO=true

            break

        fi

    done

    if [ "$ENCONTRADO" = false ]; then
        warn "Aplicativo não encontrado: $APP"
    fi

done

# ============================================================
# Verificar se algum aplicativo foi localizado
# ============================================================

if [ "${#NOVOS_FAVORITOS[@]}" -eq 0 ]; then
    warn "Nenhum aplicativo foi localizado para adicionar aos favoritos."
    exit 0
fi

# ============================================================
# Ler favoritos atuais do GNOME
# ============================================================

info "Lendo favoritos atuais"

FAVORITOS_ATUAIS="$(
    gsettings_usuario get \
        org.gnome.shell \
        favorite-apps
)"

echo
echo "Favoritos atuais:"
echo "$FAVORITOS_ATUAIS"
echo

# ============================================================
# Converter favoritos atuais para array Bash
# ============================================================

mapfile -t FAVORITOS_EXISTENTES < <(
    echo "$FAVORITOS_ATUAIS" \
        | tr -d "[]" \
        | tr "," "\n" \
        | sed \
            -e "s/^[[:space:]]*'//" \
            -e "s/'[[:space:]]*$//" \
            -e '/^$/d'
)

# ============================================================
# Unir favoritos atuais + novos sem duplicar
# ============================================================

FAVORITOS_FINAIS=()

for APP in "${FAVORITOS_EXISTENTES[@]}"; do
    FAVORITOS_FINAIS+=("$APP")
done

for APP in "${NOVOS_FAVORITOS[@]}"; do

    JA_EXISTE=false

    for EXISTENTE in "${FAVORITOS_FINAIS[@]}"; do

        if [ "$EXISTENTE" = "$APP" ]; then
            JA_EXISTE=true
            break
        fi

    done

    if [ "$JA_EXISTE" = false ]; then
        FAVORITOS_FINAIS+=("$APP")
    fi

done

# ============================================================
# Montar lista no formato esperado pelo gsettings
# ============================================================

LISTA="["

for APP in "${FAVORITOS_FINAIS[@]}"; do
    LISTA+="'$APP', "
done

LISTA="${LISTA%, }"
LISTA+="]"

# ============================================================
# Mostrar configuração que será aplicada
# ============================================================

echo
info "Favoritos que serão configurados:"

for APP in "${FAVORITOS_FINAIS[@]}"; do
    echo "  - $APP"
done

echo

# ============================================================
# Aplicar configuração
# ============================================================

info "Aplicando favoritos no GNOME"

gsettings_usuario set \
    org.gnome.shell \
    favorite-apps \
    "$LISTA"

# ============================================================
# Ler configuração final
# ============================================================

FAVORITOS_CONFIGURADOS="$(
    gsettings_usuario get \
        org.gnome.shell \
        favorite-apps
)"

echo
info "Favoritos após configuração:"
echo "$FAVORITOS_CONFIGURADOS"
echo

# ============================================================
# Validar favoritos adicionados
# ============================================================

FALHA=false

for APP in "${NOVOS_FAVORITOS[@]}"; do

    if [[ "$FAVORITOS_CONFIGURADOS" == *"'$APP'"* ]]; then

        info "Favorito validado: $APP"

    else

        warn "Favorito não encontrado após configuração: $APP"
        FALHA=true

    fi

done

# ============================================================
# Registrar resultado
# ============================================================

if [ "$FALHA" = false ]; then

    info "Favoritos do GNOME configurados e validados com sucesso."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "OK" \
            "Favoritos GNOME" \
            "Aplicativos adicionados e validados"
    fi

    exit 0

else

    error "Nem todos os favoritos foram aplicados corretamente."

    if declare -F registrar_componente >/dev/null 2>&1; then
        registrar_componente \
            "FALHA" \
            "Favoritos GNOME" \
            "Verificação final divergente"
    fi

    exit 1

fi
