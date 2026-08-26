#!/bin/bash

# ============================================================
# Instalação do VirtualBox Guest Additions
#
# Este módulo:
#   - verifica se a máquina está rodando no VirtualBox;
#   - instala dependências de compilação;
#   - localiza a mídia do Guest Additions;
#   - executa VBoxLinuxAdditions.run diretamente via shell;
#   - trata corretamente códigos de retorno 0 e 2;
#   - verifica VBoxClient, módulos e serviços;
#   - informa quando uma reinicialização é necessária.
#
# IMPORTANTE:
#
# A mídia do Guest Additions normalmente é uma ISO/CD-ROM
# montada como somente leitura.
#
# Portanto, NÃO deve ser executado:
#
#   chmod +x VBoxLinuxAdditions.run
#
# O instalador é chamado diretamente com:
#
#   sh VBoxLinuxAdditions.run
#
# ============================================================

set -e


# ============================================================
# 1. Diretórios do projeto
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"


# ============================================================
# 2. Bibliotecas
# ============================================================

source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/lib/logging.sh"


# ============================================================
# 3. Identificação
# ============================================================

COMPONENT_NAME="VirtualBox Guest Additions"

REBOOT_REQUIRED=false
MOUNT_CREATED_BY_SCRIPT=false

VBOX_MOUNT=""
VBOX_INSTALLER=""


echo
echo "============================================================"
echo " Instalando VirtualBox Guest Additions"
echo "============================================================"
echo


# ============================================================
# 4. Verificar se estamos executando como root
# ============================================================

if [[ "$EUID" -ne 0 ]]; then

    error "Este módulo precisa ser executado como root."

    echo
    error "Execute:"
    echo
    echo "    sudo bash modules/05-guest-additions.sh"
    echo

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Execução sem privilégios de root"

    exit 1

fi


# ============================================================
# 5. Verificar ambiente de virtualização
# ============================================================

info "Verificando ambiente de virtualização..."

VIRTUALIZATION=""

if command -v systemd-detect-virt >/dev/null 2>&1; then

    VIRTUALIZATION="$(
        systemd-detect-virt 2>/dev/null ||
        true
    )"

fi


if [[ "$VIRTUALIZATION" == "oracle" ]]; then

    success "VirtualBox detectado."

else

    # --------------------------------------------------------
    # Segunda tentativa usando DMI
    # --------------------------------------------------------

    if grep -qiE \
        "VirtualBox|innotek|Oracle" \
        /sys/class/dmi/id/product_name \
        /sys/class/dmi/id/sys_vendor \
        2>/dev/null; then

        success "VirtualBox detectado através das informações DMI."

    else

        warn "Esta máquina não parece estar executando no VirtualBox."
        warn "O módulo Guest Additions será ignorado."

        record_component_status \
            "$COMPONENT_NAME" \
            "SKIPPED" \
            "VirtualBox não detectado"

        exit 0

    fi

fi


# ============================================================
# 6. Exibir kernel em execução
# ============================================================

CURRENT_KERNEL="$(uname -r)"

info "Kernel em execução:"
info "$CURRENT_KERNEL"


# ============================================================
# 7. Instalar dependências
# ============================================================

info "Instalando dependências necessárias..."

install_package build-essential
install_package dkms
install_package perl


# ------------------------------------------------------------
# Headers correspondentes ao kernel atual
# ------------------------------------------------------------

KERNEL_HEADERS="linux-headers-${CURRENT_KERNEL}"

info "Verificando headers do kernel:"
info "$KERNEL_HEADERS"

if apt-cache show "$KERNEL_HEADERS" >/dev/null 2>&1; then

    install_package "$KERNEL_HEADERS"

else

    error "Headers correspondentes ao kernel atual não foram encontrados:"
    error "$KERNEL_HEADERS"

    echo
    error "Kernel atual:"
    error "$CURRENT_KERNEL"

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Headers do kernel não encontrados"

    exit 1

fi


success "Dependências instaladas."


# ============================================================
# 8. Procurar mídia já montada
# ============================================================

info "Localizando mídia do VirtualBox Guest Additions..."

POSSIBLE_MOUNTS=(
    "/media/cdrom"
    "/media/cdrom0"
    "/mnt/cdrom"
    "/mnt/vboxadditions"
)


# ------------------------------------------------------------
# Diretórios VBox_GAs_* conhecidos
# ------------------------------------------------------------

for path in /media/VBox_GAs_*; do

    if [[ -d "$path" ]]; then
        POSSIBLE_MOUNTS+=("$path")
    fi

done


for path in /media/*/VBox_GAs_*; do

    if [[ -d "$path" ]]; then
        POSSIBLE_MOUNTS+=("$path")
    fi

done


# ------------------------------------------------------------
# Procurar instalador
# ------------------------------------------------------------

for mount_point in "${POSSIBLE_MOUNTS[@]}"; do

    if [[ -f "${mount_point}/VBoxLinuxAdditions.run" ]]; then

        VBOX_MOUNT="$mount_point"
        VBOX_INSTALLER="${mount_point}/VBoxLinuxAdditions.run"

        break

    fi

done


# ============================================================
# 9. Caso não esteja montado, tentar montar a unidade óptica
# ============================================================

if [[ -z "$VBOX_INSTALLER" ]]; then

    info "Mídia ainda não localizada."
    info "Tentando montar a unidade óptica..."

    mkdir -p /mnt/vboxadditions

    DEVICE=""

    for candidate in \
        /dev/sr0 \
        /dev/cdrom \
        /dev/dvd; do

        if [[ -e "$candidate" ]]; then

            DEVICE="$candidate"
            break

        fi

    done


    if [[ -n "$DEVICE" ]]; then

        info "Unidade óptica localizada:"
        info "$DEVICE"


        if mount "$DEVICE" /mnt/vboxadditions 2>/dev/null; then

            MOUNT_CREATED_BY_SCRIPT=true

        else

            # ------------------------------------------------
            # Pode já estar montado.
            # ------------------------------------------------

            info "A unidade pode já estar montada."

        fi


        if [[ -f /mnt/vboxadditions/VBoxLinuxAdditions.run ]]; then

            VBOX_MOUNT="/mnt/vboxadditions"
            VBOX_INSTALLER="/mnt/vboxadditions/VBoxLinuxAdditions.run"

        fi

    fi

fi


# ============================================================
# 10. Validar mídia
# ============================================================

if [[ -z "$VBOX_INSTALLER" ||
      ! -f "$VBOX_INSTALLER" ]]; then

    error "Não foi possível localizar VBoxLinuxAdditions.run."

    echo
    error "No menu da máquina virtual VirtualBox, selecione:"
    echo
    error "    Dispositivos"
    error "        -> Inserir imagem de CD dos Adicionais para Convidado"
    echo
    error "Depois execute este módulo novamente."
    echo

    record_component_status \
        "$COMPONENT_NAME" \
        "FAIL" \
        "Mídia Guest Additions não encontrada"

    exit 1

fi


success "Mídia localizada:"
info "$VBOX_MOUNT"

info "Instalador:"
info "$VBOX_INSTALLER"


# ============================================================
# 11. NÃO alterar permissões do instalador
# ============================================================

# ------------------------------------------------------------
# NÃO usar:
#
#   chmod +x "$VBOX_INSTALLER"
#
# A ISO do Guest Additions é normalmente montada como
# somente leitura.
#
# O shell consegue executar o arquivo diretamente:
#
#   sh "$VBOX_INSTALLER"
# ------------------------------------------------------------


# ============================================================
# 12. Executar instalador
# ============================================================

echo
info "Executando VBoxLinuxAdditions.run..."
echo


# ------------------------------------------------------------
# O instalador da Oracle possui códigos próprios.
#
# 0:
#   instalação concluída normalmente.
#
# 2:
#   instalação concluída, porém módulos antigos continuam
#   carregados e será necessário reiniciar a VM.
#
# Outros valores:
#   falha real.
#
# Como o script global utiliza "set -e", desabilitamos
# temporariamente essa opção para interpretar o retorno.
# ------------------------------------------------------------

set +e

sh "$VBOX_INSTALLER"

VBOX_EXIT_CODE=$?

set -e


echo
info "Código retornado por VBoxLinuxAdditions.run:"
info "$VBOX_EXIT_CODE"


# ============================================================
# 13. Interpretar código de retorno
# ============================================================

case "$VBOX_EXIT_CODE" in

    0)

        success "VirtualBox Guest Additions instalado com sucesso."

        ;;


    2)

        warn "VirtualBox Guest Additions foi instalado,"
        warn "mas os módulos atualmente carregados não puderam"
        warn "ser substituídos nesta sessão."

        echo

        warn "Isso pode acontecer quando módulos antigos"
        warn "do VirtualBox ainda estão em uso."

        echo

        warn "Será necessário reiniciar a máquina virtual"
        warn "para carregar os módulos recém-instalados."

        REBOOT_REQUIRED=true

        ;;


    *)

        error "Falha durante a instalação do Guest Additions."

        error \
            "VBoxLinuxAdditions.run retornou código ${VBOX_EXIT_CODE}."

        echo


        if [[ -f /var/log/vboxadd-install.log ]]; then

            error "Consulte:"
            error "/var/log/vboxadd-install.log"

        fi


        if [[ -f /var/log/vboxadd-setup.log ]]; then

            error "Consulte também:"
            error "/var/log/vboxadd-setup.log"

        fi


        record_component_status \
            "$COMPONENT_NAME" \
            "FAIL" \
            "VBoxLinuxAdditions.run retornou ${VBOX_EXIT_CODE}"

        # ----------------------------------------------------
        # Desmontar somente se este script fez a montagem
        # ----------------------------------------------------

        if [[ "$MOUNT_CREATED_BY_SCRIPT" == true ]]; then

            umount /mnt/vboxadditions \
                2>/dev/null ||
                true

        fi

        exit "$VBOX_EXIT_CODE"

        ;;

esac


# ============================================================
# 14. Verificar VBoxClient
# ============================================================

echo
info "Verificando VBoxClient..."

if command -v VBoxClient >/dev/null 2>&1; then

    VBOXCLIENT_PATH="$(command -v VBoxClient)"

    success "VBoxClient encontrado:"
    info "$VBOXCLIENT_PATH"


    VBOXCLIENT_VERSION="$(
        VBoxClient --version \
        2>/dev/null ||
        true
    )"

    if [[ -n "$VBOXCLIENT_VERSION" ]]; then

        info "Versão:"
        info "$VBOXCLIENT_VERSION"

    fi

else

    warn "VBoxClient não foi encontrado no PATH."

fi


# ============================================================
# 15. Verificar módulos instalados
# ============================================================

echo
info "Verificando módulos do VirtualBox..."

for module in \
    vboxguest \
    vboxsf \
    vboxvideo; do

    if modinfo "$module" >/dev/null 2>&1; then

        MODULE_VERSION="$(
            modinfo \
                -F version \
                "$module" \
                2>/dev/null |
            head -n 1
        )"

        if [[ -n "$MODULE_VERSION" ]]; then

            success \
                "${module}: ${MODULE_VERSION}"

        else

            success \
                "${module}: instalado"

        fi

    else

        warn \
            "Módulo ${module} não encontrado."

    fi

done


# ============================================================
# 16. Verificar módulos atualmente carregados
# ============================================================

echo
info "Verificando módulos VirtualBox carregados..."

LOADED_MODULES="$(
    lsmod |
    awk '/^vbox/ {print $1}' |
    sort
)"


if [[ -n "$LOADED_MODULES" ]]; then

    while read -r module; do

        [[ -z "$module" ]] && continue

        info "$module"

    done <<< "$LOADED_MODULES"

else

    warn "Nenhum módulo VirtualBox está carregado atualmente."

    REBOOT_REQUIRED=true

fi


# ============================================================
# 17. Verificar rcvboxadd
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

        warn "Os drivers Guest Additions ainda não estão"
        warn "completamente ativos."

        REBOOT_REQUIRED=true

    fi


    # --------------------------------------------------------
    # Serviço de usuário
    # --------------------------------------------------------

    set +e

    rcvboxadd status-user >/dev/null 2>&1

    STATUS_USER=$?

    set -e


    if [[ "$STATUS_USER" -eq 0 ]]; then

        success "Serviços de usuário Guest Additions estão ativos."

    else

        warn "Serviços de usuário Guest Additions"
        warn "ainda não estão completamente ativos."

    fi

fi


# ============================================================
# 18. Verificar suporte a pastas compartilhadas
# ============================================================

echo
info "Verificando suporte a pastas compartilhadas..."

if modinfo vboxsf >/dev/null 2>&1; then

    success "Módulo vboxsf disponível."

else

    warn "Módulo vboxsf não encontrado."

    REBOOT_REQUIRED=true

fi


# ============================================================
# 19. Verificar diretório de instalação
# ============================================================

if [[ -d /opt/VBoxGuestAdditions-* ]]; then

    info "Diretório Guest Additions localizado:"

    find /opt \
        -maxdepth 1 \
        -type d \
        -name 'VBoxGuestAdditions-*' \
        -print |
    while read -r directory; do

        info "$directory"

    done

fi


# ============================================================
# 20. Desmontar mídia somente se o script a montou
# ============================================================

if [[ "$MOUNT_CREATED_BY_SCRIPT" == true ]]; then

    echo
    info "Desmontando mídia temporária..."

    if mountpoint -q /mnt/vboxadditions 2>/dev/null; then

        umount /mnt/vboxadditions \
            2>/dev/null ||
            true

    fi

fi


# ============================================================
# 21. Resultado
# ============================================================

echo
echo "============================================================"
echo " VirtualBox Guest Additions"
echo "============================================================"
echo


if [[ "$REBOOT_REQUIRED" == true ]]; then

    success "Instalação do Guest Additions concluída."

    echo

    warn "É necessário reiniciar a máquina virtual"
    warn "para carregar completamente os novos módulos."

    echo
    info "Depois que o setup terminar, execute:"
    echo
    echo "    sudo reboot"
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
# 22. Finalização
# ============================================================

success "Módulo Guest Additions finalizado."

exit 0