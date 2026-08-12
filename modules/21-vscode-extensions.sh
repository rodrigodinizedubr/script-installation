#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

# ============================================================
# Verificar configuração
# ============================================================

if [ "${INSTALAR_EXTENSOES_VSCODE:-true}" != true ]; then
    info "Instalação das extensões do VS Code desabilitada."
    exit 0
fi

info "Configurando extensões do Visual Studio Code"

# ============================================================
# Verificar usuário
# ============================================================

if ! id "$USUARIO" >/dev/null 2>&1; then
    error "Usuário $USUARIO não encontrado."
    exit 1
fi

# ============================================================
# Verificar VS Code
# ============================================================

if ! command -v code >/dev/null 2>&1; then
    error "Visual Studio Code não está instalado."
    error "Execute primeiro o módulo responsável pela instalação do VS Code."
    exit 1
fi

info "VS Code encontrado:"
code --version | head -n 1

# ============================================================
# Lista de extensões
# ============================================================

EXTENSOES=(
    "aaron-bond.better-comments"
    "alefragnani.bookmarks"
    "atomicconcepts.atomicviz"
    "bierner.markdown-mermaid"
    "bpruitt-goddard.mermaid-markdown-syntax-highlighting"
    "dracula-theme.theme-dracula"
    "mebrahtom.plantumlpreviewer"
    "mechatroner.rainbow-csv"
    "mhutchie.git-graph"
    "monish.regexsnippets"
    "ms-azuretools.vscode-containers"
    "ms-python.autopep8"
    "ms-python.debugpy"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.vscode-python-envs"
    "ms-vscode-remote.remote-containers"
    "openai.chatgpt"
    "pnp.polacode"
    "qwtel.sqlite-viewer"
    "redhat.ansible"
    "redhat.vscode-yaml"
    "ritwickdey.liveserver"
    "ubw.mermaidlens"
    "vscode-icons-team.vscode-icons"
)

# ============================================================
# Instalar extensões
# ============================================================

TOTAL=${#EXTENSOES[@]}
ATUAL=0

info "Total de extensões a processar: $TOTAL"

for EXTENSAO in "${EXTENSOES[@]}"; do

    ATUAL=$((ATUAL + 1))

    echo
    info "[$ATUAL/$TOTAL] Verificando: $EXTENSAO"

    # --------------------------------------------------------
    # Verificar se já está instalada
    # --------------------------------------------------------

    if sudo -u "$USUARIO" \
        code --list-extensions \
        | grep -Fxqi "$EXTENSAO"; then

        info "Extensão já instalada: $EXTENSAO"
        continue

    fi

    # --------------------------------------------------------
    # Instalar
    # --------------------------------------------------------

    info "Instalando: $EXTENSAO"

    if sudo -u "$USUARIO" \
        code --install-extension "$EXTENSAO" \
        --force; then

        info "Instalada com sucesso: $EXTENSAO"

    else

        warn "Falha ao instalar: $EXTENSAO"

    fi

done

# ============================================================
# Verificação final
# ============================================================

echo
info "Extensões atualmente instaladas para $USUARIO:"

sudo -u "$USUARIO" code --list-extensions | sort

echo
info "Configuração das extensões do VS Code concluída."
