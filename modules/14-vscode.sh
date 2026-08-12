#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Instalando Visual Studio Code"
ensure_user_exists "$USUARIO"

if command_exists code; then
    info "VSCode já está instalado."
    record_component_status "JA_EXISTIA" "Visual Studio Code" "Executável code encontrado"
else
    wget -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    if dpkg -i /tmp/vscode.deb || apt --fix-broken install -y; then
        record_component_status "INSTALADO" "Visual Studio Code" "Instalação concluída"
    else
        record_component_status "FALHA" "Visual Studio Code" "dpkg/apt retornou erro"
        exit 1
    fi
fi

info "Extensões do VS Code serão tratadas pelo módulo 21-vscode-extensions.sh."

mkdir -p "/home/$USUARIO/Documentos/Code"
cat > "/home/$USUARIO/Documentos/Code/main.py" <<'EOF_MAINPY'
print("***********************************************************")
print("*********** O Python foi instalado com sucesso! ***********")
print("***********************************************************")
EOF_MAINPY

chown -R "$USUARIO:$USUARIO" "/home/$USUARIO/Documentos/Code"
info "VSCode configurado. Algumas preferências visuais ainda podem ser ajustadas pela interface."
