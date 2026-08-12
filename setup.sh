#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"

check_root

mkdir -p "$BASE_DIR/logs"
LOG_FILE="$BASE_DIR/logs/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

info "Iniciando configuração do Debian"
info "Diretório base: $BASE_DIR"
info "Log: $LOG_FILE"

for script in "$BASE_DIR"/modules/*.sh; do
    info "Executando: $(basename "$script")"
    if bash "$script"; then
        info "Concluído: $(basename "$script")"
    else
        error "Falha em: $(basename "$script")"
        error "A execução foi interrompida. Consulte o log: $LOG_FILE"
        exit 1
    fi
    echo
done

info "Configuração finalizada."
warn "Reinicie o sistema para aplicar todas as alterações."
