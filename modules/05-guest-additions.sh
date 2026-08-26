#!/bin/bash

# ============================================================
# Instalação do VirtualBox Guest Additions
#
# Este módulo:
#   - instala dependências de compilação;
#   - localiza a mídia do Guest Additions;
#   - executa VBoxLinuxAdditions.run;
#   - interpreta corretamente os códigos de retorno;
#   - valida a instalação;
#   - informa quando uma reinicialização é necessária.
# ============================================================

set -e

# ------------------------------------------------------------
# Diretórios do projeto
# ------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ------------------------------------------------------------
# Bibliotecas
# ------------------------------------------------------------

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"

COMPONENT_NAME="VirtualBox Guest Additions"

echo
echo "============================================================"
echo " Instalando VirtualBox Guest Additions"
echo "============================================================"
echo


# ============================================================
# 1. Verificar se estamos dentro do VirtualBox
# ============================================================

info "Verificando ambiente de virtualização..."

VIRTUALIZATION=""

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRTUALIZATION="$(systemd-detect-virt 2>/dev/null || true)"
fi

if [[ "$VIRTUALIZATION" != "oracle" ]]; then

    warn "VirtualBox não foi detectado pelo systemd-detect-virt."

    # Segunda tentativa usando DMI
    if grep -qiE "VirtualBox|innotek|Oracle" \
        /sys/class/dmi/id/product_name \
        /sys/class/dmi/id/sys_vendor \
        2>/dev/null; then

        info "VirtualBox detectado através das informações DMI."

    else

        warn "Esta máquina não parece estar executando no VirtualBox."
        warn "O módulo Guest Additions será ignorado."

        record_component_status \
            "$COMPONENT_NAME" \
            "SKIPPED" \
            "VirtualBox não detectado"

        exit 0

    fi

else

    info "VirtualBox detectado."

fi


# ============================================================
# 2. Instalar dependências necessárias
# ============================================================

info "Instalando dependências necessárias..."

install_package build-essential
install_package dkms
install_package linux-headers-$(uname -r)

# Algumas versões também utilizam estes pacotes
install_package perl

success "Dependências instaladas."


# ============================================================
# 3. Verificar mídia do Guest Additions
# ============================================================

info "Localizando mídia do VirtualBox Guest Additions..."

VBOX_MOUNT=""

POSSIBLE_MOUNTS=(
    "/media/cdrom"
    "/media/cdrom0"
    "/mnt"
)

# Adicionar mounts dentro de /media/<usuario>
for path in /media/*/VBox_GAs_*; do
    [[ -d "$path" ]] && POSSIBLE_MOUNTS+=("$path")
done

for path in /media/VBox_GAs_*; do
    [[ -d "$path" ]] && POSSIBLE_MOUNTS+=("$path")
done


# ------------------------------------------------------------
# Procurar VBoxLinuxAdditions.run
# ------------------------------------------------------------

for mount_point in "${POSSIBLE_MOUNTS[@]}"; do

    if [[ -f "${mount_point}/VBoxLinuxAdditions.run" ]]; then
        VBOX_MOUNT="$mount_point"
        break
    fi

done


# ============================================================
# 4. Tentar montar o CD caso ainda não tenha sido encontrado
# ============================================================

if [[ -z "$VBOX_MOUNT" ]]; then

    info "Mídia ainda não localizada."
    info "Tentando montar o CD do Guest Additions..."

    mkdir -p /mnt/vboxadditions

    DEVICE=""

    # Procurar unidade óptica
    for candidate in /dev/sr0 /dev/cdrom /dev/dvd; do

        if [[ -e "$candidate" ]]; then
            DEVICE="$candidate"
            break
        fi

    done

    if [[ -n "$DEVICE" ]]; then

        mount "$DEVICE" /mnt/vboxadditions 2>/dev/null || true

        if [[ -f /mnt/vboxadditions/VBoxLinuxAdditions.run ]]; then
            VBOX_MOUNT="/mnt/vboxadditions"
        fi

    fi

fi


# ============================================================
# 5. Validar mídia
# ============================================================

if [[ -z "$VBOX_MOUNT" ]]; then

    error "Não foi possível localizar VBoxLinuxAdditions.run."

    echo
    error "No VirtualBox, selecione:"
    error "Dispositivos -> Inserir imagem de CD dos Adicionais para Convidado"
    echo
    error "Depois execute novamente este módulo."

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Mídia Guest Additions não encontrada"

    exit 1

fi


VBOX_INSTALLER="${VBOX_MOUNT}/VBoxLinuxAdditions.run"

info "Mídia localizada:"
info "$VBOX_MOUNT"

info "Instalador:"
info "$VBOX_INSTALLER"


# ============================================================
# 6. Tornar instalador executável
# ============================================================

chmod +x "$VBOX_INSTALLER"


# ============================================================
# 7. Executar instalador
# ============================================================

echo
info "Executando VBoxLinuxAdditions.run..."
echo

# O instalador da Oracle utiliza códigos de retorno próprios.
#
# Código 0:
#   instalação concluída e módulos carregados.
#
# Código 2:
#   instalação concluída, porém os módulos atualmente carregados
#   não puderam ser substituídos nesta sessão.
#
# Neste caso, reiniciar a VM normalmente resolve.

set +e

sh "$VBOX_INSTALLER"

VBOX_EXIT_CODE=$?

set -e


# ============================================================
# 8. Interpretar resultado
# ============================================================

REBOOT_REQUIRED=false

case "$VBOX_EXIT_CODE" in

    0)

        success "VirtualBox Guest Additions instalado com sucesso."

        ;;

    2)

        warn "VirtualBox Guest Additions foi instalado,"
        warn "mas os módulos carregados atualmente não puderam"
        warn "ser substituídos nesta sessão."

        echo

        warn "Isso pode acontecer quando módulos antigos do"
        warn "VirtualBox ainda estão em uso."

        echo

        warn "Será necessário reiniciar a máquina virtual"
        warn "para carregar os novos módulos."

        REBOOT_REQUIRED=true

        ;;

    *)

        error "Falha durante a instalação do Guest Additions."
        error "Código retornado pelo instalador: ${VBOX_EXIT_CODE}"

        if [[ -f /var/log/vboxadd-install.log ]]; then

            echo
            error "Consulte o log:"
            error "/var/log/vboxadd-install.log"

        fi

        if [[ -f /var/log/vboxadd-setup.log ]]; then

            echo
            error "Consulte também:"
            error "/var/log/vboxadd-setup.log"

        fi

        record_component_status \
            "$COMPONENT_NAME" \
            "FAIL" \
            "VBoxLinuxAdditions.run retornou ${VBOX_EXIT_CODE}"

        exit "$VBOX_EXIT_CODE"

        ;;

esac


# ============================================================
# 9. Verificar VBoxClient
# ============================================================

echo
info "Verificando VBoxClient..."

if command -v VBoxClient >/dev/null 2>&1; then

    VBOXCLIENT_PATH="$(command -v VBoxClient)"

    success "VBoxClient encontrado:"
    info "$VBOXCLIENT_PATH"

else

    warn "VBoxClient não foi encontrado no PATH."

fi


# ============================================================
# 10. Verificar módulos instalados
# ============================================================

echo
info "Verificando módulos do VirtualBox..."

MODULES_FOUND=false

for module in vboxguest vboxsf vboxvideo; do

    if modinfo "$module" >/dev/null 2>&1; then

        VERSION="$(
            modinfo -F version "$module" 2>/dev/null |
            head -n 1
        )"

        if [[ -n "$VERSION" ]]; then
            success "${module}: ${VERSION}"
        else
            success "${module}: instalado"
        fi

        MODULES_FOUND=true

    else

        warn "Módulo ${module} não encontrado."

    fi

done


# ============================================================
# 11. Verificar módulos carregados
# ============================================================

echo
info "Módulos atualmente carregados:"

LOADED_MODULES="$(
    lsmod |
    awk '/^vbox/ {print $1}' |
    sort
)"

if [[ -n "$LOADED_MODULES" ]]; then

    while read -r module; do
        info "$module"
    done <<< "$LOADED_MODULES"

else

    warn "Nenhum módulo vbox está carregado atualmente."

fi


# ============================================================
# 12. Verificar serviço rcvboxadd
# ============================================================

if command -v rcvboxadd >/dev/null 2>&1; then

    echo
    info "Verificando estado dos drivers Guest Additions..."

    set +e

    rcvboxadd status-kernel

    STATUS_KERNEL=$?

    set -e

    if [[ "$STATUS_KERNEL" -eq 0 ]]; then

        success "Drivers Guest Additions estão ativos."

    else

        warn "Os drivers ainda não estão completamente ativos."
        warn "Uma reinicialização pode ser necessária."

        REBOOT_REQUIRED=true

    fi

fi


# ============================================================
# 13. Verificar compartilhamento de pastas
# ============================================================

echo
info "Verificando suporte ao módulo vboxsf..."

if modinfo vboxsf >/dev/null 2>&1; then
    success "Suporte a pastas compartilhadas disponível."
else
    warn "Módulo vboxsf não encontrado."
fi


# ============================================================
# 14. Registrar resultado
# ============================================================

echo
echo "============================================================"
echo " VirtualBox Guest Additions"
echo "============================================================"
echo

if [[ "$REBOOT_REQUIRED" == true ]]; then

    warn "Instalação concluída."
    warn "É necessário reiniciar a máquina virtual."

    echo
    echo "Execute:"
    echo
    echo "    reboot"
    echo

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Instalado; reinicialização necessária"

else

    success "Guest Additions instalado e validado."

    record_component_status \
        "$COMPONENT_NAME" \
        "OK" \
        "Instalado e validado"

fi


# ============================================================
# 15. Desmontar mídia montada pelo script
# ============================================================

if mountpoint -q /mnt/vboxadditions 2>/dev/null; then

    info "Desmontando mídia temporária..."

    umount /mnt/vboxadditions 2>/dev/null || true

fi


success "Módulo Guest Additions finalizado."

exit 0