#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Instalando Visual Studio Code"
ensure_user_exists "$USUARIO"

if command_exists code; then
    info "VSCode já está instalado."
else
    wget -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    dpkg -i /tmp/vscode.deb || apt --fix-broken install -y
fi

info "Instalando extensões do VSCode para o usuário $USUARIO"

EXTENSOES=(
    ms-python.python
    ms-python.vscode-pylance
    ms-python.debugpy
    ms-python.autopep8
    dracula-theme.theme-dracula
    VisualStudioExptTeam.vscodeintellicode
    vscode-icons-team.vscode-icons
    redhat.ansible
    ritwickdey.LiveServer
    Monish.regexsnippets
    pnp.polacode
    alexcvzz.vscode-sqlite
    alefragnani.Bookmarks
    aaron-bond.better-comments
)

for ext in "${EXTENSOES[@]}"; do
    sudo -u "$USUARIO" code --install-extension "$ext" || warn "Falha ao instalar extensão: $ext"
done

mkdir -p "/home/$USUARIO/Documentos/Code"
cat > "/home/$USUARIO/Documentos/Code/main.py" <<'EOF_MAINPY'
print("***********************************************************")
print("*********** O Python foi instalado com sucesso! ***********")
print("***********************************************************")
EOF_MAINPY

chown -R "$USUARIO:$USUARIO" "/home/$USUARIO/Documentos/Code"
info "VSCode configurado. Algumas preferências visuais ainda podem ser ajustadas pela interface."
