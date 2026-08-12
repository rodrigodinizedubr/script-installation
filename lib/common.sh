#!/bin/bash

# Carrega o suporte a logs quando disponível.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$COMMON_DIR/logging.sh" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_DIR/logging.sh"
fi

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[AVISO]\e[0m $1"
}

error() {
    echo -e "\e[31m[ERRO]\e[0m $1"
}

success() {
    echo -e "\e[32m[OK]\e[0m $1"
}

check_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        error "Execute como root: sudo ./setup.sh"
        exit 1
    fi
}

package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

install_package() {
    local package="$1"

    if package_installed "$package"; then
        info "$package já está instalado."
        if declare -F record_package_status >/dev/null 2>&1; then
            record_package_status "JA_EXISTIA" "$package" "Pacote já presente antes desta execução"
        fi
        return 0
    fi

    info "Instalando $package..."
    if apt install -y "$package"; then
        success "$package instalado com sucesso."
        if declare -F record_package_status >/dev/null 2>&1; then
            record_package_status "INSTALADO" "$package" "Instalação concluída"
        fi
        return 0
    fi

    error "Falha ao instalar $package."
    if declare -F record_package_status >/dev/null 2>&1; then
        record_package_status "FALHA" "$package" "apt install retornou erro"
    fi
    return 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

backup_file() {
    local file="$1"

    if [ -f "$file" ] && [ ! -f "$file.bak" ]; then
        cp "$file" "$file.bak"
        info "Backup criado: $file.bak"
    fi
}

ensure_user_exists() {
    local user="$1"

    if ! id "$user" >/dev/null 2>&1; then
        error "Usuário não encontrado: $user"
        exit 1
    fi
}
