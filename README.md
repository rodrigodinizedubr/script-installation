# Script Installation - Debian

Scripts modulares para configurar uma VM Debian com interface gráfica, ferramentas de rede, desenvolvimento, navegadores, Tilix, Wireshark, VS Code, pyenv, Docker e outras configurações opcionais.

## Como usar

```bash
chmod +x setup.sh
chmod +x modules/*.sh
chmod +x lib/*.sh
sudo ./setup.sh
```

## Antes de executar

Edite `config.conf` e revise principalmente:

- `USUARIO="operador"`
- `HOSTNAME_NOVO="workstation"`
- `CONFIGURAR_IP=false`
- `INSTALAR_CHROME=true`
- `INSTALAR_PYTHON_COM_PYENV=false`
- `CONFIGURAR_GRUB=false`
- `INSTALAR_DOCKER=true`
- `INSTALAR_DOCKER_DESKTOP=true`
- `INSTALAR_GITHUB_DESKTOP=true`
- `INSTALAR_EXTENSOES_VSCODE=true`
- `DESABILITAR_BLOQUEIO_TELA=true`

## Estrutura

```text
script-installation/
├── setup.sh
├── config.conf
├── lib/
│   ├── common.sh
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
│   ├── 23-gnome-favorites.sh
│   └── 24-dash-to-dock.sh
└── logs/
```

## Logs

Cada execução recebe um identificador baseado em data e hora. O instalador gera:

- `setup-AAAAMMDD-HHMMSS.log`: saída completa mostrada no terminal.
- `setup-AAAAMMDD-HHMMSS-summary.log`: relatório resumido de módulos, pacotes e componentes.
- `setup-AAAAMMDD-HHMMSS-modules.tsv`: estado estruturado de cada módulo.
- `setup-AAAAMMDD-HHMMSS-packages.tsv`: pacotes processados por `install_package`.
- `setup-AAAAMMDD-HHMMSS-components.tsv`: componentes adicionais e verificações.

Estados usados no resumo:

- `OK`: módulo executado corretamente.
- `FALHA`: módulo retornou erro.
- `IGNORADO`: módulo opcional foi desabilitado em `config.conf`.
- `INSTALADO`: pacote/componente instalado durante a execução.
- `JA_EXISTIA`: já estava instalado antes da execução.

O módulo `14-vscode.sh` instala o aplicativo VS Code; as extensões ficam exclusivamente no `21-vscode-extensions.sh`, evitando instalação duplicada.

Uma falha em um módulo não interrompe imediatamente os módulos seguintes. O `setup.sh` registra a falha, continua a execução e retorna código diferente de zero no final se alguma etapa tiver falhado.

## Observações

Algumas etapas continuam dependendo da interface gráfica, como fixar ícones na barra lateral, configurar visualmente o Dash to Dock, instalar extensões no Firefox, selecionar manualmente o tema Dracula no Tilix e inserir a imagem dos Adicionais para Convidado pelo menu do VirtualBox.

O pacote `tldr` foi substituído por `tealdeer`; o comando de uso continua sendo `tldr`.
