#!/bin/bash

# ============================================================
# Flameshot - GNOME + Wayland
#
# Estratégia:
#
#   1. Instala Flameshot e portais.
#   2. Instala suporte AppIndicator/KStatusNotifierItem.
#   3. Cria autostart do daemon Flameshot.
#   4. Cria wrapper D-Bus:
#
#      ~/.local/bin/flameshot-screenshot
#
#   5. O wrapper chama Activate no StatusNotifierItem
#      do Flameshot, equivalendo à ação do tray.
#
#   6. Configura atalho personalizado GNOME.
#
# ============================================================

set -e


# ============================================================
# 1. Diretórios
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"


# ============================================================
# 2. Configuração e bibliotecas
# ============================================================

if [[ -f "${ROOT_DIR}/config.conf" ]]; then
    source "${ROOT_DIR}/config.conf"
fi

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"
source "${ROOT_DIR}/lib/gnome.sh"


# ============================================================
# 3. Configurações
# ============================================================

COMPONENT_NAME="Flameshot"

CUSTOM_KEYS_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"

CUSTOM_BINDING_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"

CUSTOM_BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"

CUSTOM_BINDING_SCHEMA_PATH="${CUSTOM_BINDING_SCHEMA}:${CUSTOM_BINDING_PATH}"

FLAMESHOT_SHORTCUT="${FLAMESHOT_SHORTCUT:-<Shift>Print}"

EXTENSION_UUID="ubuntu-appindicators@ubuntu.com"


echo
echo "============================================================"
echo " Configurando Flameshot"
echo "============================================================"
echo


# ============================================================
# 4. Verificar configuração
# ============================================================

if [[ "${INSTALAR_FLAMESHOT:-true}" != "true" ]]; then

    warn "Flameshot desabilitado."
    warn "INSTALAR_FLAMESHOT=false"

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

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Execução sem root"

    exit 1
fi


# ============================================================
# 6. Instalar pacotes
# ============================================================

info "Verificando Flameshot e dependências..."

install_package flameshot
install_package xdg-desktop-portal
install_package xdg-desktop-portal-gnome
install_package libglib2.0-bin

# Suporte a StatusNotifierItem/AppIndicator no GNOME.
#
# O nome do pacote Debian é este nas versões atuais.
if apt-cache show \
    gnome-shell-extension-appindicator \
    >/dev/null 2>&1; then

    install_package gnome-shell-extension-appindicator

else

    warn "gnome-shell-extension-appindicator não disponível no APT."

fi


success "Pacotes necessários disponíveis."


# ============================================================
# 7. Verificar executáveis
# ============================================================

for command_name in flameshot gdbus; do

    if ! command -v "$command_name" >/dev/null 2>&1; then

        error "Comando necessário não encontrado:"
        error "$command_name"

        record_component_status \
            "$COMPONENT_NAME" \
            "FAIL" \
            "Dependência ausente: ${command_name}"

        exit 1
    fi

done


# ============================================================
# 8. Identificar usuário GNOME
# ============================================================

if ! gnome_detect_user; then

    error "Não foi possível identificar o usuário GNOME."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Usuário GNOME não identificado"

    exit 1
fi


info "Usuário GNOME:"
info "$GNOME_USER"

info "UID:"
info "$GNOME_UID"

info "HOME:"
info "$GNOME_HOME"


# ============================================================
# 9. Verificar sessão GNOME
# ============================================================

if ! gnome_session_available; then

    warn "Sessão GNOME não disponível."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "Instalado; sessão GNOME indisponível"

    exit 0
fi


# ============================================================
# 10. Detectar tipo da sessão
# ============================================================

SESSION_ID="$(
    loginctl list-sessions \
        --no-legend \
        2>/dev/null |
    awk \
        -v user="$GNOME_USER" \
        '$3 == user {print $1; exit}'
)"


SESSION_TYPE=""

if [[ -n "$SESSION_ID" ]]; then

    SESSION_TYPE="$(
        loginctl show-session \
            "$SESSION_ID" \
            -p Type \
            --value \
            2>/dev/null ||
            true
    )"

fi


info "Tipo da sessão:"
info "${SESSION_TYPE:-desconhecido}"


# ============================================================
# 11. Diretórios do usuário
# ============================================================

USER_BIN_DIR="${GNOME_HOME}/.local/bin"

USER_AUTOSTART_DIR="${GNOME_HOME}/.config/autostart"

WRAPPER_FILE="${USER_BIN_DIR}/flameshot-screenshot"

AUTOSTART_FILE="${USER_AUTOSTART_DIR}/flameshot.desktop"


mkdir -p "$USER_BIN_DIR"
mkdir -p "$USER_AUTOSTART_DIR"


chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$USER_BIN_DIR"

chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$USER_AUTOSTART_DIR"


# ============================================================
# 12. Criar wrapper D-Bus
# ============================================================

info "Criando wrapper do Flameshot..."


cat > "$WRAPPER_FILE" <<'EOF'
#!/bin/bash

# ============================================================
# Flameshot Screenshot - GNOME Wayland
#
# Workaround:
#
# Em algumas versões GNOME/Wayland:
#
#   flameshot gui
#
# pode retornar:
#
#   Screenshot aborted
#
# O tray do Flameshot, entretanto, funciona.
#
# Este script chama Activate no StatusNotifierItem,
# equivalendo à ação do ícone do tray.
# ============================================================

set -e


# ------------------------------------------------------------
# Ambiente gráfico
# ------------------------------------------------------------

export QT_QPA_PLATFORM=wayland

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"


# ------------------------------------------------------------
# Garantir daemon Flameshot
# ------------------------------------------------------------

if ! pgrep -x flameshot >/dev/null 2>&1; then

    /usr/bin/env \
        QT_QPA_PLATFORM=wayland \
        /usr/bin/flameshot \
        >/dev/null 2>&1 &

    sleep 2

fi


# ------------------------------------------------------------
# Aguardar registro do StatusNotifierItem
# ------------------------------------------------------------

ITEMS=""

for attempt in $(seq 1 10); do

    ITEMS="$(
        /usr/bin/gdbus call \
            --session \
            --dest=org.kde.StatusNotifierWatcher \
            --object-path=/StatusNotifierWatcher \
            --method=org.freedesktop.DBus.Properties.Get \
            org.kde.StatusNotifierWatcher \
            RegisteredStatusNotifierItems \
            2>/dev/null ||
            true
    )"

    if [[ -n "$ITEMS" ]]; then
        break
    fi

    sleep 1

done


# ------------------------------------------------------------
# Extrair nomes únicos de serviços D-Bus
#
# Exemplos possíveis:
#
#   :1.123
#
#   org.kde.StatusNotifierItem-1234-1
# ------------------------------------------------------------

BUS_NAMES="$(
    printf '%s\n' "$ITEMS" |
    grep -oE \
        '(:[0-9]+\.[0-9]+|org\.kde\.StatusNotifierItem-[^/,'"' ]+)' |
    sort -u
)"


if [[ -z "$BUS_NAMES" ]]; then

    echo "[ERRO] Nenhum StatusNotifierItem encontrado." >&2
    exit 1

fi


# ------------------------------------------------------------
# Encontrar especificamente o item do Flameshot
# ------------------------------------------------------------

FLAMESHOT_BUS=""

while read -r bus_name; do

    [[ -z "$bus_name" ]] && continue

    TITLE="$(
        /usr/bin/gdbus call \
            --session \
            --dest="$bus_name" \
            --object-path=/StatusNotifierItem \
            --method=org.freedesktop.DBus.Properties.Get \
            org.kde.StatusNotifierItem \
            Title \
            2>/dev/null ||
            true
    )"

    ID="$(
        /usr/bin/gdbus call \
            --session \
            --dest="$bus_name" \
            --object-path=/StatusNotifierItem \
            --method=org.freedesktop.DBus.Properties.Get \
            org.kde.StatusNotifierItem \
            Id \
            2>/dev/null ||
            true
    )"


    if printf '%s\n%s\n' "$TITLE" "$ID" |
        grep -qi flameshot; then

        FLAMESHOT_BUS="$bus_name"
        break

    fi

done <<< "$BUS_NAMES"


# ------------------------------------------------------------
# Fallback:
#
# Se houver exatamente um StatusNotifierItem, usamos ele.
# ------------------------------------------------------------

if [[ -z "$FLAMESHOT_BUS" ]]; then

    ITEM_COUNT="$(
        printf '%s\n' "$BUS_NAMES" |
        sed '/^$/d' |
        wc -l
    )"

    if [[ "$ITEM_COUNT" -eq 1 ]]; then

        FLAMESHOT_BUS="$(
            printf '%s\n' "$BUS_NAMES" |
            head -n 1
        )"

    fi

fi


if [[ -z "$FLAMESHOT_BUS" ]]; then

    echo "[ERRO] StatusNotifierItem do Flameshot não encontrado." >&2
    exit 1

fi


# ------------------------------------------------------------
# Disparar captura
# ------------------------------------------------------------

/usr/bin/gdbus call \
    --session \
    --dest="$FLAMESHOT_BUS" \
    --object-path=/StatusNotifierItem \
    --method=org.kde.StatusNotifierItem.Activate \
    0 \
    0 \
    >/dev/null 2>&1


exit 0
EOF


chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$WRAPPER_FILE"

chmod 755 \
    "$WRAPPER_FILE"


success "Wrapper criado:"
info "$WRAPPER_FILE"


# ============================================================
# 13. Criar autostart
# ============================================================

info "Criando autostart do Flameshot..."


cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Flameshot
Comment=Inicia Flameshot para integração GNOME/Wayland
Exec=/usr/bin/env QT_QPA_PLATFORM=wayland /usr/bin/flameshot
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;
EOF


chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$AUTOSTART_FILE"

chmod 644 \
    "$AUTOSTART_FILE"


success "Autostart criado:"
info "$AUTOSTART_FILE"


# ============================================================
# 14. Habilitar AppIndicator, se disponível
# ============================================================

if gnome_extension_exists "$EXTENSION_UUID"; then

    if gnome_extension_enabled "$EXTENSION_UUID"; then

        success "AppIndicator já está habilitado."

    else

        info "Habilitando AppIndicator..."

        if gnome_extension_enable "$EXTENSION_UUID"; then

            success "AppIndicator habilitado."

        else

            warn "Não foi possível confirmar AppIndicator nesta sessão."
            warn "Pode ser necessário logout/login."

        fi

    fi

else

    warn "Extensão AppIndicator ainda não aparece nesta sessão."
    warn "Ela poderá ser carregada no próximo login."

fi


# ============================================================
# 15. Iniciar daemon agora
# ============================================================

info "Iniciando daemon Flameshot..."


gnome_run \
    sh \
    -c '
        if ! pgrep -x flameshot >/dev/null 2>&1; then

            /usr/bin/env \
                QT_QPA_PLATFORM=wayland \
                /usr/bin/flameshot \
                >/dev/null 2>&1 &

        fi
    '


sleep 2


# ============================================================
# 16. Validar daemon
# ============================================================

if gnome_run \
    pgrep \
    -x \
    flameshot \
    >/dev/null 2>&1; then

    success "Daemon Flameshot está ativo."

else

    warn "Daemon Flameshot não foi confirmado."

fi


# ============================================================
# 17. Adicionar custom keybinding
# ============================================================

CURRENT_BINDINGS="$(
    gnome_gsettings get \
        "$CUSTOM_KEYS_SCHEMA" \
        custom-keybindings
)"


if printf '%s' "$CURRENT_BINDINGS" |
    grep -Fq "$CUSTOM_BINDING_PATH"; then

    NEW_BINDINGS="$CURRENT_BINDINGS"

else

    if [[ "$CURRENT_BINDINGS" == "@as []" ||
          "$CURRENT_BINDINGS" == "[]" ]]; then

        NEW_BINDINGS="['${CUSTOM_BINDING_PATH}']"

    else

        NEW_BINDINGS="${CURRENT_BINDINGS%]}"

        NEW_BINDINGS="${NEW_BINDINGS}, '${CUSTOM_BINDING_PATH}']"

    fi

fi


gnome_gsettings \
    set \
    "$CUSTOM_KEYS_SCHEMA" \
    custom-keybindings \
    "$NEW_BINDINGS"


# ============================================================
# 18. Configurar atalho
# ============================================================

gnome_gsettings_set \
    "$CUSTOM_BINDING_SCHEMA_PATH" \
    name \
    "'Flameshot'"


gnome_gsettings_set \
    "$CUSTOM_BINDING_SCHEMA_PATH" \
    command \
    "'${WRAPPER_FILE}'"


gnome_gsettings_set \
    "$CUSTOM_BINDING_SCHEMA_PATH" \
    binding \
    "'${FLAMESHOT_SHORTCUT}'"


# ============================================================
# 19. Validar configuração
# ============================================================

FINAL_COMMAND="$(
    gnome_gsettings get \
        "$CUSTOM_BINDING_SCHEMA_PATH" \
        command
)"


FINAL_BINDING="$(
    gnome_gsettings get \
        "$CUSTOM_BINDING_SCHEMA_PATH" \
        binding
)"


FINAL_BINDINGS="$(
    gnome_gsettings get \
        "$CUSTOM_KEYS_SCHEMA" \
        custom-keybindings
)"


if ! printf '%s' "$FINAL_BINDINGS" |
    grep -Fq "$CUSTOM_BINDING_PATH"; then

    error "Atalho Flameshot não está registrado em custom-keybindings."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Custom keybinding ausente"

    exit 1
fi


# ============================================================
# 20. Resultado
# ============================================================

echo
echo "============================================================"
echo " Flameshot configurado"
echo "============================================================"
echo

echo "Usuário:"
echo "  ${GNOME_USER}"
echo

echo "Sessão:"
echo "  ${SESSION_TYPE:-desconhecida}"
echo

echo "Wrapper:"
echo "  ${WRAPPER_FILE}"
echo

echo "Autostart:"
echo "  ${AUTOSTART_FILE}"
echo

echo "Comando do atalho:"
echo "  ${FINAL_COMMAND}"
echo

echo "Atalho:"
echo "  ${FINAL_BINDING}"
echo


# ============================================================
# 21. Registrar resultado
# ============================================================

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Wayland D-Bus wrapper + ${FLAMESHOT_SHORTCUT}"


success "Flameshot configurado com sucesso."

exit 0