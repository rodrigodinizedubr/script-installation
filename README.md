# Script Installation - Debian

Scripts modulares para preparar e configurar uma estação Debian com GNOME, incluindo repositórios, atualização do sistema, VirtualBox Guest Additions, ferramentas de rede e desenvolvimento, navegadores, Flatpak, Tilix, Wireshark, VS Code, pyenv, Docker, GitHub Desktop, Cisco Packet Tracer e automações da interface gráfica.

O projeto também automatiza configurações que antes dependiam de ajustes manuais no GNOME, como Dash to Dock, favoritos da barra de tarefas, bloqueio de tela, perfil do Tilix e integração do Flameshot com GNOME/Wayland. Também inclui Mission Center, Obsidian com suporte opcional ao Excalidraw e Zen Browser.

## Como usar

- Instale o Debian no VirtualBox e inicie a máquina virtual.
- No VirtualBox, clique em `Dispositivos` e depois em `Inserir imagem de CD dos Adicionais para Convidado`.
- No Debian, abra um terminal e confirme que a mídia está disponível, por exemplo:

```bash
ls /media/cdrom
```

ou:

```bash
ls /media/cdrom0
```

- Atualize a lista de pacotes:

```bash
apt update
```

- Instale o Git:

```bash
apt install git -y
```

- Clone o repositório:

```bash
git clone https://github.com/rodrigodinizedubr/script-installation.git
cd script-installation
```

- Atribua permissão de execução aos scripts:

```bash
chmod +x setup.sh
chmod +x modules/*.sh
chmod +x lib/*.sh
chmod +x scripts/*.sh
```

## Antes de executar

Edite `config.conf` e revise as opções de acordo com a máquina que será configurada. As principais configurações atuais são:

```bash
USUARIO="operador"
HOSTNAME_NOVO="workstation"

CONFIGURAR_IP=false
INSTALAR_GUEST_ADDITIONS=true

INSTALAR_CHROME=true
INSTALAR_OPERA=true
INSTALAR_ZEN_BROWSER=true

INSTALAR_PYTHON_COM_PYENV=false
PYTHON_VERSION="3.13.1"

CONFIGURAR_GRUB=false
INSTALAR_FONTES_ASSETS=false

INSTALAR_PACKET_TRACER=true

INSTALAR_DOCKER=true
INSTALAR_DOCKER_DESKTOP=true

INSTALAR_GITHUB_DESKTOP=true
INSTALAR_EXTENSOES_VSCODE=true

DESABILITAR_BLOQUEIO_TELA=true
CONFIGURAR_FAVORITOS_GNOME=true

INSTALAR_MISSION_CENTER=true

INSTALAR_OBSIDIAN=true
OBSIDIAN_VAULT="/home/operador/Documentos/Code/Obsidian"
INSTALAR_OBSIDIAN_EXCALIDRAW=true
```

A ordem dos aplicativos fixados no Dash/Dash to Dock é controlada pelo array `FAVORITOS_GNOME`. A ordem dos itens no array corresponde à ordem desejada na barra:

```bash
FAVORITOS_GNOME=(
    "firefox-esr.desktop"
    "opera.desktop"
    "google-chrome.desktop"
    "app.zen_browser.zen.desktop"
    "com.gexperts.Tilix.desktop"
    "code.desktop"
    "github-desktop.desktop"
    "md.obsidian.Obsidian.desktop"
    "org.wireshark.Wireshark.desktop"
    "org.flameshot.Flameshot.desktop"
    "com.obsproject.Studio.desktop"
    "org.shotcut.Shotcut.desktop"
    "io.missioncenter.MissionCenter.desktop"
    "CiscoPacketTracer-9.0.1.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.Software.desktop"
)
```

O módulo de favoritos procura lançadores `.desktop` instalados pelo sistema, pelo usuário e por Flatpak, incluindo:

```bash
/usr/share/applications
/usr/local/share/applications
~/.local/share/applications
~/.local/share/flatpak/exports/share/applications
/var/lib/flatpak/exports/share/applications
```
Para o Cisco Packet Tracer, o projeto aceita um arquivo `.deb` local ou pode localizar `CiscoPacketTracer_901_Ubuntu_64bit.deb` na pasta pública do Google Drive definida em `PACKET_TRACER_DRIVE_FOLDER_URL`.

## Execução do script

Execute o instalador como `root` a partir da raiz do projeto:

```bash
./setup.sh
```

O `setup.sh` executa automaticamente todos os arquivos `modules/*.sh` em ordem alfabética/numérica. Uma falha em um módulo é registrada, mas não interrompe imediatamente a execução dos módulos seguintes, permitindo que o relatório final apresente todos os problemas encontrados.

Após a execução, algumas alterações de sessão — especialmente extensões GNOME, grupos `docker`/`kvm`, Dash to Dock e AppIndicator — podem exigir logout/login ou reinicialização do sistema.

## Estrutura

```text
script-installation/
├── setup.sh
├── config.conf
├── lib/
│   ├── common.sh
│   ├── gnome.sh
│   └── logging.sh
├── modules/
│   ├── 01-repositories.sh
│   ├── 02-update.sh
│   ├── 03-users.sh
│   ├── 04-system.sh
│   ├── 05-guest-additions.sh
│   ├── 06-keyboard.sh
│   ├── 07-root-bashrc.sh
│   ├── 08-network.sh
│   ├── 09-flatpak.sh
│   ├── 10-tools.sh
│   ├── 11-wireshark.sh
│   ├── 12-browsers.sh
│   ├── 13-tilix.sh
│   ├── 14-vscode.sh
│   ├── 15-pyenv.sh
│   ├── 16-fonts.sh
│   ├── 17-packet-tracer.sh
│   ├── 18-grub.sh
│   ├── 19-docker.sh
│   ├── 20-githubdesktop.sh
│   ├── 21-vscode-extensions.sh
│   ├── 22-disable-screen-lock.sh
│   ├── 23-dash-to-dock.sh
│   ├── 24-tilix-config.sh
│   ├── 25-flameshot.sh
│   ├── 26-mission-center.sh
│   ├── 27-obsidian.sh
│   └── 28-gnome-favorites.sh
├── scripts/
│   └── apply-dash-to-dock.sh
├── assets/
│   ├── fonts/
│   └── packettracer/
└── logs/
```



## Logs

Cada execução recebe um identificador baseado em data e hora. O instalador gera:

- `setup-AAAAMMDD-HHMMSS.log`: saída completa mostrada no terminal.
- `setup-AAAAMMDD-HHMMSS-summary.log`: relatório resumido de módulos, pacotes e componentes.
- `setup-AAAAMMDD-HHMMSS-modules.tsv`: estado estruturado de cada módulo.
- `setup-AAAAMMDD-HHMMSS-packages.tsv`: pacotes processados por `install_package`.
- `setup-AAAAMMDD-HHMMSS-components.tsv`: componentes adicionais e verificações.

Estados usados no resumo incluem:

- `OK`: módulo executado corretamente.
- `FALHA`: módulo retornou erro.
- `IGNORADO`: módulo opcional foi desabilitado em `config.conf`.
- `INSTALADO`: pacote/componente instalado durante a execução.
- `JA_EXISTIA`: pacote/componente já estava instalado antes da execução.

O módulo `14-vscode.sh` instala o VS Code; as extensões ficam exclusivamente no `21-vscode-extensions.sh`, evitando instalação duplicada.

Uma falha em um módulo não interrompe imediatamente os módulos seguintes. Ao final, `setup.sh` retorna código diferente de zero se houver falhas registradas em módulos, pacotes ou componentes.

## Observações

Algumas ações continuam necessariamente interativas ou dependentes da sessão gráfica:

- a imagem dos VirtualBox Guest Additions deve estar inserida na unidade óptica virtual para que `05-guest-additions.sh` encontre `VBoxLinuxAdditions.run`;
- a EULA do Cisco Packet Tracer deve ser revisada e aceita pelo próprio usuário na primeira execução; o script não aceita a licença automaticamente e o Packet Tracer não deve ser iniciado como `root`;
- alterações de extensões GNOME instaladas durante uma sessão podem exigir logout/login para serem reconhecidas pelo GNOME Shell;
- Docker Desktop requer suporte a KVM; após inclusão do usuário nos grupos `docker` e `kvm`, é necessário encerrar e iniciar novamente a sessão;
- o Dash to Dock utiliza uma reaplicação automática pós-login para garantir que as preferências sejam aplicadas quando o GNOME Shell já estiver carregado;
- o Flameshot possui tratamento específico para GNOME/Wayland. Para diagnóstico manual, o comando que força o backend Wayland é:

```bash
/usr/bin/env QT_QPA_PLATFORM=wayland /usr/bin/flameshot gui
```

- Mission Center e Zen Browser são instalados como Flatpaks de sistema e seus arquivos `.desktop` são considerados pelo módulo de favoritos;
- o Vault padrão do Obsidian é configurável por `OBSIDIAN_VAULT`; o Excalidraw é instalado dentro do Vault, pois plugins do Obsidian são específicos de cada Vault;
- o pacote `tldr` foi substituído por `tealdeer`; o comando de uso continua sendo `tldr`.

Antes de uma nova instalação completa, recomenda-se revisar `config.conf`, validar a sintaxe dos scripts alterados com `bash -n` e manter apenas as versões atuais dos módulos dentro de `modules/`, pois `setup.sh` executa todos os arquivos `.sh` existentes nesse diretório.
