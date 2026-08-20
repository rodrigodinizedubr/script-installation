#!/bin/bash

# ============================================================
# Instalação e configuração do Dash to Dock
# ============================================================

set -e

EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"
SCHEMA="org.gnome.shell.extensions.dash-to-dock"

echo
echo "============================================================"
echo " Instalando e configurando Dash to Dock"
echo "============================================================"
echo

# ------------------------------------------------------------
# 1. Verificar ambiente GNOME
# ------------------------------------------------------------

if ! command -v gnome-shell >/dev/null 2>&1; then
    echo "[ERRO] GNOME Shell não foi encontrado."
    echo "Este script deve ser executado em um sistema com GNOME."
    exit 1
fi

echo "[INFO] GNOME detectado:"
gnome-shell --version

# ------------------------------------------------------------
# 2. Instalar Dash to Dock
# ------------------------------------------------------------

echo
echo "[INFO] Instalando Dash to Dock..."

sudo apt update
sudo apt install -y \
    gnome-shell-extension-dashtodock \
    gnome-shell-extension-prefs

echo "[OK] Dash to Dock instalado."

# ------------------------------------------------------------
# 3. Habilitar extensão
# ------------------------------------------------------------

echo
echo "[INFO] Habilitando Dash to Dock..."

if command -v gnome-extensions >/dev/null 2>&1; then
    gnome-extensions enable "${EXTENSION_UUID}" 2>/dev/null || true
else
    echo "[AVISO] O comando gnome-extensions não está disponível."
fi

# ------------------------------------------------------------
# 4. Verificar schema
# ------------------------------------------------------------

echo
echo "[INFO] Verificando schema do Dash to Dock..."

if ! gsettings list-schemas | grep -qx "${SCHEMA}"; then
    echo
    echo "[AVISO] O schema ${SCHEMA} ainda não está disponível."
    echo
    echo "Pode ser necessário:"
    echo "  - encerrar a sessão do GNOME;"
    echo "  - entrar novamente;"
    echo "  - executar este script novamente."
    echo
    exit 0
fi

# ------------------------------------------------------------
# 5. Posição e tamanho
# ------------------------------------------------------------

echo
echo "[INFO] Configurando posição e tamanho..."

# Mostrar em todos os monitores
gsettings set "${SCHEMA}" multi-monitor true

# Posição na tela: esquerda
gsettings set "${SCHEMA}" dock-position 'LEFT'

# Desabilitar ocultação inteligente
gsettings set "${SCHEMA}" intellihide false

# Desabilitar ocultação automática
gsettings set "${SCHEMA}" autohide false

# Manter dock visível
gsettings set "${SCHEMA}" dock-fixed true

# Tamanho limite do dock: 72%
gsettings set "${SCHEMA}" height-fraction 0.72

# Modo do painel:
# estender até a borda da tela
gsettings set "${SCHEMA}" extend-height true

# Tamanho máximo dos ícones: 32 px
gsettings set "${SCHEMA}" dash-max-icon-size 32

# ------------------------------------------------------------
# 6. Pré-visualização das janelas
# ------------------------------------------------------------

# O valor não foi especificado no procedimento original.
#
# A configuração correspondente é:
#
# gsettings set "${SCHEMA}" preview-size-scale VALOR
#
# Faixa suportada:
# 0.0 a 1.0
#
# Exemplo para 50%:
#
# gsettings set "${SCHEMA}" preview-size-scale 0.5

# ------------------------------------------------------------
# 7. Aparência
# ------------------------------------------------------------

echo "[INFO] Configurando aparência..."

# Encolher o Dash
gsettings set "${SCHEMA}" custom-theme-shrink true

# Opacidade personalizada em modo fixo
gsettings set "${SCHEMA}" transparency-mode 'FIXED'

# Opacidade: 0%
gsettings set "${SCHEMA}" background-opacity 0.0

# ------------------------------------------------------------
# 8. Resultado
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Configuração concluída"
echo "============================================================"
echo

echo "Configurações aplicadas:"
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

echo "[IMPORTANTE]"
echo "Caso alguma alteração ainda não apareça, encerre a sessão"
echo "do GNOME e faça login novamente."
echo
