#!/bin/bash

# Funções de apoio ao sistema de logs. Este arquivo é carregado pelo setup.sh
# e pode ser usado pelos módulos por meio de common.sh.

log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

record_module_status() {
    local status="$1"
    local module="$2"
    local detail="${3:-}"

    [ -n "${MODULE_LOG:-}" ] || return 0
    printf '%s\t%s\t%s\t%s\n' "$(log_timestamp)" "$status" "$module" "$detail" >> "$MODULE_LOG"
}

record_package_status() {
    local status="$1"
    local package="$2"
    local detail="${3:-}"

    [ -n "${PACKAGE_LOG:-}" ] || return 0
    printf '%s\t%s\t%s\t%s\n' "$(log_timestamp)" "$status" "$package" "$detail" >> "$PACKAGE_LOG"
}

record_component_status() {
    local status="$1"
    local component="$2"
    local detail="${3:-}"

    [ -n "${COMPONENT_LOG:-}" ] || return 0
    printf '%s\t%s\t%s\t%s\n' "$(log_timestamp)" "$status" "$component" "$detail" >> "$COMPONENT_LOG"
}

mark_skipped() {
    local reason="${1:-Sem motivo informado}"
    if [ -n "${MODULE_STATUS_FILE:-}" ]; then
        printf 'IGNORADO\t%s\n' "$reason" > "$MODULE_STATUS_FILE"
    fi
    warn "$reason"
}

mark_component_skipped() {
    local component="$1"
    local reason="${2:-Desabilitado pela configuração}"
    record_component_status "IGNORADO" "$component" "$reason"
}

generate_summary() {
    local summary_file="$1"
    local start_time="$2"
    local end_time="$3"
    local user_name="$4"
    local ok_count="$5"
    local fail_count="$6"
    local skip_count="$7"
    local package_fail_count="${8:-0}"
    local component_fail_count="${9:-0}"

    local os_name="desconhecido"
    if [ -r /etc/os-release ]; then
        os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-desconhecido}")"
    fi

    {
        echo "============================================================"
        echo "       RELATÓRIO DE INSTALAÇÃO - SCRIPT INSTALLATION"
        echo "============================================================"
        echo
        echo "Início:   $start_time"
        echo "Término:  $end_time"
        echo "Usuário:  $user_name"
        echo "Sistema:  $os_name"
        echo "Hostname: $(hostname 2>/dev/null || echo desconhecido)"
        echo
        echo "------------------------------------------------------------"
        echo "MÓDULOS"
        echo "------------------------------------------------------------"
        if [ -s "${MODULE_LOG:-}" ]; then
            awk -F '\t' '{printf "[%s] %s%s\n", $2, $3, ($4 != "" ? " - " $4 : "")}' "$MODULE_LOG"
        else
            echo "Nenhum módulo registrado."
        fi
        echo
        echo "------------------------------------------------------------"
        echo "PACOTES APT"
        echo "------------------------------------------------------------"
        if [ -s "${PACKAGE_LOG:-}" ]; then
            awk -F '\t' '{printf "[%s] %s%s\n", $2, $3, ($4 != "" ? " - " $4 : "")}' "$PACKAGE_LOG"
        else
            echo "Nenhum pacote registrado pela função install_package."
        fi
        echo
        echo "------------------------------------------------------------"
        echo "COMPONENTES / VERIFICAÇÕES"
        echo "------------------------------------------------------------"
        if [ -s "${COMPONENT_LOG:-}" ]; then
            awk -F '\t' '{printf "[%s] %s%s\n", $2, $3, ($4 != "" ? " - " $4 : "")}' "$COMPONENT_LOG"
        else
            echo "Nenhum componente adicional registrado."
        fi
        echo
        echo "------------------------------------------------------------"
        echo "RESULTADO"
        echo "------------------------------------------------------------"
        printf 'Executados com sucesso: %s\n' "$ok_count"
        printf 'Falhas:                %s\n' "$fail_count"
        printf 'Ignorados:             %s\n' "$skip_count"
        printf 'Falhas em pacotes:     %s\n' "$package_fail_count"
        printf 'Falhas em componentes: %s\n' "$component_fail_count"
        echo
        if [ "$fail_count" -gt 0 ] || [ "$package_fail_count" -gt 0 ] || [ "$component_fail_count" -gt 0 ]; then
            echo "Instalação concluída com falhas. Consulte o log detalhado."
        else
            echo "Instalação concluída sem falhas registradas."
        fi
    } > "$summary_file"
}
