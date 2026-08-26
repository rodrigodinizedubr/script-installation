#!/bin/bash

set -e

SCHEMA="org.gnome.shell.extensions.dash-to-dock"
EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"

AUTOSTART_FILE="${HOME}/.config/autostart/apply-dash-to-dock.desktop"

echo "[INFO] Aplicando configuração do Dash to Dock..."

# ------------------------------------------------------------
# Aguardar GNOME disponibilizar o schema
# ------------------------------------------------------------

for tentativa in $(seq 1 30); do

    if gsettings list-schemas |
        grep -Fxq "$SCHEMA"; then

        break
    fi

    sleep 1

done


if ! gsettings list-schemas |
    grep -Fxq "$SCHEMA"; then

    echo "[ERRO] Schema do Dash to Dock não disponível."
    exit 1

fi


# ------------------------------------------------------------
# Aplicar configurações
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Habilitar extensão
# ------------------------------------------------------------

if command -v gnome-extensions >/dev/null 2>&1; then

    if gnome-extensions list |
        grep -Fxq "$EXTENSION_UUID"; then

        gnome-extensions enable "$EXTENSION_UUID" || true

    fi

fi


# ------------------------------------------------------------
# Validar configurações principais
# ------------------------------------------------------------

POSITION="$(
    gsettings get "$SCHEMA" dock-position
)"

ICON_SIZE="$(
    gsettings get "$SCHEMA" dash-max-icon-size
)"

MULTI_MONITOR="$(
    gsettings get "$SCHEMA" multi-monitor
)"


if [[ "$POSITION" != "'LEFT'" ]]; then

    echo "[ERRO] Posição do dock não foi aplicada."
    exit 1

fi


if [[ "$ICON_SIZE" != "32" ]]; then

    echo "[ERRO] Tamanho dos ícones não foi aplicado."
    exit 1

fi


if [[ "$MULTI_MONITOR" != "true" ]]; then

    echo "[ERRO] Configuração multi-monitor não foi aplicada."
    exit 1

fi


echo "[OK] Dash to Dock configurado."


# ------------------------------------------------------------
# Remover autostart
#
# Só removemos depois de sucesso.
# ------------------------------------------------------------

if [[ -f "$AUTOSTART_FILE" ]]; then

    rm -f "$AUTOSTART_FILE"

    echo "[OK] Autostart temporário removido."

fi

exit 0