#!/bin/bash

# ============================================================
# Configuração do Dash to Dock
#
# Estratégia:
#
#   Fase 1:
#     - instala a extensão;
#     - tenta aplicar as configurações imediatamente;
#
#   Fase 2:
#     - cria um autostart temporário;
#     - reaplica as configurações no próximo login GNOME;
#     - valida;
#     - remove o autostart e o helper após sucesso.
#
# Configurações:
#
#   - Mostrar em todos os monitores
#   - Posição: esquerda
#   - Ocultação inteligente: desabilitada
#   - Ocultação automática: desabilitada
#   - Dock sempre visível
#   - Tamanho limite: 72%
#   - Modo painel: habilitado
#   - Ícones: 32 px
#   - Encolher Dash: habilitado
#   - Transparência fixa
#   - Opacidade: 0%
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
source "${ROOT_DIR}/lib/gnome.sh"


# ============================================================
# 3. Configurações
# ============================================================

COMPONENT_NAME="Dash to Dock"

EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"
SCHEMA="org.gnome.shell.extensions.dash-to-dock"

POST_LOGIN_HELPER_NAME="apply-dash-to-dock.sh"
AUTOSTART_NAME="apply-dash-to-dock.desktop"


echo
echo "============================================================"
echo " Configurando Dash to Dock"
echo "============================================================"
echo


# ============================================================
# 4. Verificar GNOME Shell
# ============================================================

if ! command -v gnome-shell >/dev/null 2>&1; then

    warn "GNOME Shell não encontrado."
    warn "O Dash to Dock será ignorado."

    record_component_status \
        "$COMPONENT_NAME" \
        "SKIPPED" \
        "GNOME Shell não encontrado"

    exit 0

fi


GNOME_VERSION="$(
    gnome-shell --version 2>/dev/null ||
    true
)"

info "GNOME detectado:"
info "${GNOME_VERSION:-versão desconhecida}"


# ============================================================
# 5. Instalar Dash to Dock
# ============================================================

info "Instalando/verificando Dash to Dock..."

install_package gnome-shell-extension-dashtodock
install_package gnome-shell-extension-prefs

success "Pacotes do Dash to Dock instalados."


# ============================================================
# 6. Identificar usuário GNOME
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
# 7. Diretórios do helper pós-login
# ============================================================

USER_HELPER_DIR="${GNOME_HOME}/.local/lib/script-installation"

USER_HELPER_FILE="${USER_HELPER_DIR}/${POST_LOGIN_HELPER_NAME}"

USER_AUTOSTART_DIR="${GNOME_HOME}/.config/autostart"

USER_AUTOSTART_FILE="${USER_AUTOSTART_DIR}/${AUTOSTART_NAME}"


# ============================================================
# 8. Criar helper pós-login
# ============================================================

info "Criando helper de configuração pós-login..."

mkdir -p "$USER_HELPER_DIR"
mkdir -p "$USER_AUTOSTART_DIR"


cat > "$USER_HELPER_FILE" <<'EOF'
#!/bin/bash

# ============================================================
# Aplicação pós-login do Dash to Dock
#
# Este arquivo é criado automaticamente pelo módulo:
#
#   24-dash-to-dock.sh
#
# Ele é executado no primeiro login GNOME após a instalação.
# Depois de aplicar e validar as configurações, remove:
#
#   - o arquivo de autostart;
#   - este próprio helper.
#
# ============================================================

set -e


SCHEMA="org.gnome.shell.extensions.dash-to-dock"

EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"

AUTOSTART_FILE="${HOME}/.config/autostart/apply-dash-to-dock.desktop"

HELPER_FILE="${HOME}/.local/lib/script-installation/apply-dash-to-dock.sh"


echo "[INFO] Configuração pós-login do Dash to Dock iniciada."


# ============================================================
# 1. Aguardar sessão GNOME estabilizar
# ============================================================

MAX_ATTEMPTS=30
ATTEMPT=1

while [[ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]]; do

    if gsettings list-schemas 2>/dev/null |
        grep -Fxq "$SCHEMA"; then

        break

    fi

    echo "[INFO] Aguardando schema do Dash to Dock..."
    echo "[INFO] Tentativa ${ATTEMPT}/${MAX_ATTEMPTS}"

    sleep 2

    ATTEMPT=$((ATTEMPT + 1))

done


# ============================================================
# 2. Validar schema
# ============================================================

if ! gsettings list-schemas 2>/dev/null |
    grep -Fxq "$SCHEMA"; then

    echo "[ERRO] Schema do Dash to Dock ainda não disponível."

    echo "[INFO] O autostart será mantido para nova tentativa."

    exit 1

fi


echo "[OK] Schema do Dash to Dock disponível."


# ============================================================
# 3. Aplicar configurações
# ============================================================

echo "[INFO] Aplicando configurações..."

gsettings set "$SCHEMA" multi-monitor true

gsettings set "$SCHEMA" dock-position 'LEFT'

gsettings set "$SCHEMA" intellihide false

gsettings set "$SCHEMA" autohide false

gsettings set "$SCHEMA" dock-fixed true

gsettings set "$SCHEMA" height-fraction 0.72

gsettings set "$SCHEMA" extend-height true

gsettings set "$SCHEMA" dash-max-icon-size 32

gsettings set "$SCHEMA" custom-theme-shrink true

gsettings set "$SCHEMA" transparency-mode 'FIXED'

gsettings set "$SCHEMA" background-opacity 0.0


# ============================================================
# 4. Habilitar extensão
# ============================================================

if command -v gnome-extensions >/dev/null 2>&1; then

    if gnome-extensions list 2>/dev/null |
        grep -Fxq "$EXTENSION_UUID"; then

        echo "[INFO] Habilitando Dash to Dock..."

        gnome-extensions enable "$EXTENSION_UUID" \
            2>/dev/null ||
            true

    else

        echo "[AVISO] Extensão ainda não aparece em gnome-extensions list."

    fi

fi


# ============================================================
# 5. Validar configurações
# ============================================================

MULTI_MONITOR="$(
    gsettings get \
        "$SCHEMA" \
        multi-monitor
)"

POSITION="$(
    gsettings get \
        "$SCHEMA" \
        dock-position
)"

INTELLIHIDE="$(
    gsettings get \
        "$SCHEMA" \
        intellihide
)"

AUTOHIDE="$(
    gsettings get \
        "$SCHEMA" \
        autohide
)"

DOCK_FIXED="$(
    gsettings get \
        "$SCHEMA" \
        dock-fixed
)"

HEIGHT="$(
    gsettings get \
        "$SCHEMA" \
        height-fraction
)"

EXTEND_HEIGHT="$(
    gsettings get \
        "$SCHEMA" \
        extend-height
)"

ICON_SIZE="$(
    gsettings get \
        "$SCHEMA" \
        dash-max-icon-size
)"

SHRINK="$(
    gsettings get \
        "$SCHEMA" \
        custom-theme-shrink
)"

TRANSPARENCY_MODE="$(
    gsettings get \
        "$SCHEMA" \
        transparency-mode
)"

BACKGROUND_OPACITY="$(
    gsettings get \
        "$SCHEMA" \
        background-opacity
)"


# ============================================================
# 6. Validações boolean/string
# ============================================================

VALID=true


if [[ "$MULTI_MONITOR" != "true" ]]; then

    echo "[ERRO] multi-monitor incorreto:"
    echo "       $MULTI_MONITOR"

    VALID=false

fi


if [[ "$POSITION" != "'LEFT'" ]]; then

    echo "[ERRO] dock-position incorreto:"
    echo "       $POSITION"

    VALID=false

fi


if [[ "$INTELLIHIDE" != "false" ]]; then

    echo "[ERRO] intellihide incorreto:"
    echo "       $INTELLIHIDE"

    VALID=false

fi


if [[ "$AUTOHIDE" != "false" ]]; then

    echo "[ERRO] autohide incorreto:"
    echo "       $AUTOHIDE"

    VALID=false

fi


if [[ "$DOCK_FIXED" != "true" ]]; then

    echo "[ERRO] dock-fixed incorreto:"
    echo "       $DOCK_FIXED"

    VALID=false

fi


if [[ "$EXTEND_HEIGHT" != "true" ]]; then

    echo "[ERRO] extend-height incorreto:"
    echo "       $EXTEND_HEIGHT"

    VALID=false

fi


if [[ "$ICON_SIZE" != "32" ]]; then

    echo "[ERRO] dash-max-icon-size incorreto:"
    echo "       $ICON_SIZE"

    VALID=false

fi


if [[ "$SHRINK" != "true" ]]; then

    echo "[ERRO] custom-theme-shrink incorreto:"
    echo "       $SHRINK"

    VALID=false

fi


if [[ "$TRANSPARENCY_MODE" != "'FIXED'" ]]; then

    echo "[ERRO] transparency-mode incorreto:"
    echo "       $TRANSPARENCY_MODE"

    VALID=false

fi


# ============================================================
# 7. Validar valores double com tolerância
# ============================================================

numeric_equal() {

    local expected="$1"
    local actual="$2"

    awk \
        -v expected="$expected" \
        -v actual="$actual" \
        'BEGIN {

            difference = expected - actual

            if (difference < 0)
                difference = -difference

            tolerance = 0.000000001

            exit !(difference <= tolerance)
        }'
}


if ! numeric_equal 0.72 "$HEIGHT"; then

    echo "[ERRO] height-fraction incorreto:"
    echo "       $HEIGHT"

    VALID=false

fi


if ! numeric_equal 0.0 "$BACKGROUND_OPACITY"; then

    echo "[ERRO] background-opacity incorreto:"
    echo "       $BACKGROUND_OPACITY"

    VALID=false

fi


# ============================================================
# 8. Resultado da validação
# ============================================================

if [[ "$VALID" != true ]]; then

    echo "[ERRO] Uma ou mais configurações não foram confirmadas."

    echo "[INFO] O autostart será mantido para uma nova tentativa."

    exit 1

fi


echo
echo "============================================================"
echo " Dash to Dock configurado com sucesso"
echo "============================================================"
echo

echo "Mostrar em todos os monitores : ${MULTI_MONITOR}"
echo "Posição                       : ${POSITION}"
echo "Ocultação inteligente         : ${INTELLIHIDE}"
echo "Ocultação automática          : ${AUTOHIDE}"
echo "Dock sempre visível           : ${DOCK_FIXED}"
echo "Tamanho limite                : ${HEIGHT}"
echo "Modo painel                   : ${EXTEND_HEIGHT}"
echo "Tamanho dos ícones            : ${ICON_SIZE}"
echo "Encolher Dash                 : ${SHRINK}"
echo "Transparência                 : ${TRANSPARENCY_MODE}"
echo "Opacidade                     : ${BACKGROUND_OPACITY}"
echo


# ============================================================
# 9. Remover autostart
# ============================================================

if [[ -f "$AUTOSTART_FILE" ]]; then

    rm -f "$AUTOSTART_FILE"

    echo "[OK] Autostart temporário removido."

fi


# ============================================================
# 10. Remover helper
#
# Não podemos apagar o próprio script antes do final.
# O rm é executado por último.
# ============================================================

echo "[OK] Configuração pós-login concluída."


rm -f "$HELPER_FILE" 2>/dev/null || true


exit 0
EOF


# ============================================================
# 9. Permissões do helper
# ============================================================

chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$USER_HELPER_FILE"

chmod 755 \
    "$USER_HELPER_FILE"


success "Helper pós-login criado:"
info "$USER_HELPER_FILE"


# ============================================================
# 10. Criar autostart one-shot
# ============================================================

info "Criando autostart temporário..."

cat > "$USER_AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Aplicar configuração do Dash to Dock
Comment=Aplica as preferências do Dash to Dock após o login GNOME
Exec=${USER_HELPER_FILE}
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;
EOF


chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$USER_AUTOSTART_FILE"

chmod 644 \
    "$USER_AUTOSTART_FILE"


success "Autostart temporário criado:"
info "$USER_AUTOSTART_FILE"


# ============================================================
# 11. Garantir propriedade dos diretórios criados
# ============================================================

chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$USER_HELPER_DIR"

chown \
    "${GNOME_USER}:${GNOME_USER}" \
    "$USER_AUTOSTART_DIR"


# ============================================================
# 12. Tentar configuração imediata
#
# Isso continua sendo útil quando o setup.sh é executado
# dentro de uma sessão GNOME já funcional.
#
# Entretanto, a configuração pós-login continuará existente
# como garantia.
# ============================================================

if gnome_session_available; then

    echo
    info "Sessão GNOME disponível."
    info "Tentando aplicar configurações imediatamente..."


    if gnome_schema_exists "$SCHEMA"; then

        # ----------------------------------------------------
        # Mostrar em todos os monitores
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "multi-monitor" \
            "true"


        # ----------------------------------------------------
        # Posição esquerda
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "dock-position" \
            "'LEFT'"


        # ----------------------------------------------------
        # Desabilitar ocultação inteligente
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "intellihide" \
            "false"


        # ----------------------------------------------------
        # Desabilitar autohide
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "autohide" \
            "false"


        # ----------------------------------------------------
        # Manter visível
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "dock-fixed" \
            "true"


        # ----------------------------------------------------
        # Tamanho limite: 72%
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "height-fraction" \
            "0.72"


        # ----------------------------------------------------
        # Modo painel
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "extend-height" \
            "true"


        # ----------------------------------------------------
        # Ícones: 32 px
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "dash-max-icon-size" \
            "32"


        # ----------------------------------------------------
        # Encolher Dash
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "custom-theme-shrink" \
            "true"


        # ----------------------------------------------------
        # Transparência fixa
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "transparency-mode" \
            "'FIXED'"


        # ----------------------------------------------------
        # Opacidade 0%
        # ----------------------------------------------------

        gnome_gsettings_set \
            "$SCHEMA" \
            "background-opacity" \
            "0.0"


        success "Preferências imediatas aplicadas."

    else

        warn "Schema ainda não disponível na sessão atual."
        warn "A configuração será reaplicada no próximo login."

    fi


else

    warn "Sessão GNOME não disponível neste momento."
    warn "A configuração será aplicada automaticamente no próximo login."

fi


# ============================================================
# 13. Tentar habilitar extensão imediatamente
# ============================================================

if gnome_session_available; then

    if gnome_extension_exists "$EXTENSION_UUID"; then

        if gnome_extension_enabled "$EXTENSION_UUID"; then

            success "Dash to Dock já está habilitado."

        else

            info "Tentando habilitar Dash to Dock..."

            if gnome_extension_enable "$EXTENSION_UUID"; then

                success "Dash to Dock habilitado."

            else

                warn "Não foi possível confirmar a ativação nesta sessão."
                warn "O helper pós-login tentará novamente."

            fi

        fi

    else

        warn "Dash to Dock ainda não aparece na sessão atual."
        warn "Isso é esperado imediatamente após instalar a extensão."
        warn "O helper pós-login tentará novamente."

    fi

fi


# ============================================================
# 14. Resultado
# ============================================================

echo
echo "============================================================"
echo " Dash to Dock preparado"
echo "============================================================"
echo

echo "Usuário:"
echo "  ${GNOME_USER}"
echo

echo "Configuração desejada:"
echo
echo "  Mostrar em todos os monitores : SIM"
echo "  Posição                       : ESQUERDA"
echo "  Ocultação inteligente         : NÃO"
echo "  Ocultação automática          : NÃO"
echo "  Dock sempre visível           : SIM"
echo "  Tamanho limite                : 72%"
echo "  Modo painel                   : SIM"
echo "  Tamanho máximo dos ícones     : 32 px"
echo "  Encolher Dash                 : SIM"
echo "  Transparência                 : FIXA"
echo "  Opacidade                     : 0%"
echo

info "Uma reaplicação automática foi preparada para"
info "o próximo login GNOME do usuário ${GNOME_USER}."

info "Depois de aplicar e validar as configurações,"
info "o autostart será removido automaticamente."


# ============================================================
# 15. Registrar componente
# ============================================================

record_component_status \
    "$COMPONENT_NAME" \
    "OK" \
    "Configurado; reaplicação pós-login preparada"


success "Módulo Dash to Dock finalizado."

exit 0