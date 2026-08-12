#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

info "Instalando dependências do pyenv"
ensure_user_exists "$USUARIO"

PACOTES=(
    build-essential
    libssl-dev
    zlib1g-dev
    libbz2-dev
    libreadline-dev
    libsqlite3-dev
    curl
    git
    libncursesw5-dev
    xz-utils
    tk-dev
    libxml2-dev
    libxmlsec1-dev
    libffi-dev
    liblzma-dev
)

for pacote in "${PACOTES[@]}"; do
    install_package "$pacote"
done

if [ ! -d "/home/$USUARIO/.pyenv" ]; then
    info "Instalando pyenv para $USUARIO"
    sudo -u "$USUARIO" bash -c 'curl https://pyenv.run | bash'
else
    info "pyenv já está instalado."
fi

BASHRC="/home/$USUARIO/.bashrc"
touch "$BASHRC"

if ! grep -q "PYENV_ROOT" "$BASHRC"; then
cat >> "$BASHRC" <<'EOF_PYENV'

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
EOF_PYENV
fi

chown "$USUARIO:$USUARIO" "$BASHRC"

if [ "$INSTALAR_PYTHON_COM_PYENV" = true ]; then
    info "Instalando Python $PYTHON_VERSION com pyenv. Isso pode demorar."
    if sudo -u "$USUARIO" bash -lc "pyenv install -s $PYTHON_VERSION && pyenv global $PYTHON_VERSION"; then
        record_component_status "INSTALADO" "Python $PYTHON_VERSION via pyenv" "Versão global configurada"
    else
        record_component_status "FALHA" "Python $PYTHON_VERSION via pyenv" "Falha na instalação/configuração"
        exit 1
    fi
else
    warn "Python pelo pyenv não será instalado automaticamente."
    warn "Para instalar depois: pyenv install $PYTHON_VERSION && pyenv global $PYTHON_VERSION"
    mark_component_skipped "Python $PYTHON_VERSION via pyenv" "INSTALAR_PYTHON_COM_PYENV=false"
fi
