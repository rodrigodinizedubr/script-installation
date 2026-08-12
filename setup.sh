#!/bin/bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$BASE_DIR/config.conf"
source "$BASE_DIR/lib/common.sh"
source "$BASE_DIR/lib/logging.sh"

check_root

RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$BASE_DIR/logs"
STATUS_DIR="$LOG_DIR/.status-$RUN_ID"

mkdir -p "$LOG_DIR" "$STATUS_DIR"

export MODULE_LOG="$LOG_DIR/setup-$RUN_ID-modules.tsv"
export PACKAGE_LOG="$LOG_DIR/setup-$RUN_ID-packages.tsv"
export COMPONENT_LOG="$LOG_DIR/setup-$RUN_ID-components.tsv"
LOG_FILE="$LOG_DIR/setup-$RUN_ID.log"
SUMMARY_FILE="$LOG_DIR/setup-$RUN_ID-summary.log"

: > "$MODULE_LOG"
: > "$PACKAGE_LOG"
: > "$COMPONENT_LOG"

exec > >(tee -a "$LOG_FILE") 2>&1

START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

info "Iniciando configuração do Debian"
info "Diretório base: $BASE_DIR"
info "Log detalhado: $LOG_FILE"
info "Resumo final: $SUMMARY_FILE"

for script in "$BASE_DIR"/modules/*.sh; do
    [ -e "$script" ] || continue

    MODULE_NAME="$(basename "$script")"
    export MODULE_STATUS_FILE="$STATUS_DIR/$MODULE_NAME.status"
    rm -f "$MODULE_STATUS_FILE"

    echo
    info "Executando: $MODULE_NAME"

    if bash "$script"; then
        if [ -s "$MODULE_STATUS_FILE" ] && grep -q '^IGNORADO' "$MODULE_STATUS_FILE"; then
            REASON="$(cut -f2- "$MODULE_STATUS_FILE")"
            record_module_status "IGNORADO" "$MODULE_NAME" "$REASON"
            SKIP_COUNT=$((SKIP_COUNT + 1))
            warn "Ignorado: $MODULE_NAME"
        else
            record_module_status "OK" "$MODULE_NAME" "Concluído"
            OK_COUNT=$((OK_COUNT + 1))
            success "Concluído: $MODULE_NAME"
        fi
    else
        RC=$?
        record_module_status "FALHA" "$MODULE_NAME" "Código de saída $RC"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        error "Falha em: $MODULE_NAME (código $RC)"
        warn "A execução continuará para permitir o diagnóstico dos demais módulos."
    fi

done

END_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
PACKAGE_FAIL_COUNT="$(awk -F '\t' '$2 == "FALHA" {c++} END {print c+0}' "$PACKAGE_LOG")"
COMPONENT_FAIL_COUNT="$(awk -F '\t' '$2 == "FALHA" {c++} END {print c+0}' "$COMPONENT_LOG")"
generate_summary "$SUMMARY_FILE" "$START_TIME" "$END_TIME" "${USUARIO:-desconhecido}" "$OK_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$PACKAGE_FAIL_COUNT" "$COMPONENT_FAIL_COUNT"

rm -rf "$STATUS_DIR"

cat "$SUMMARY_FILE"

echo
info "Log detalhado: $LOG_FILE"
info "Resumo final: $SUMMARY_FILE"

if [ "$FAIL_COUNT" -gt 0 ] || [ "$PACKAGE_FAIL_COUNT" -gt 0 ] || [ "$COMPONENT_FAIL_COUNT" -gt 0 ]; then
    error "Configuração finalizada com falhas registradas."
    error "Módulos: $FAIL_COUNT | Pacotes: $PACKAGE_FAIL_COUNT | Componentes: $COMPONENT_FAIL_COUNT"
    exit 1
fi

info "Configuração finalizada sem falhas registradas."
warn "Reinicie o sistema quando necessário para aplicar todas as alterações."
