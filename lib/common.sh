#!/bin/bash

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[AVISO]\e[0m $1"
}

error() {
    echo -e "\e[31m[ERRO]\e[0m $1"
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
    else
        info "Instalando $package..."
        apt install -y "$package"
    fi
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
