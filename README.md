# Debian Setup

Scripts modulares para configurar uma VM Debian com interface gráfica, ferramentas de rede, desenvolvimento, navegadores, Tilix, Wireshark, VSCode, pyenv, fontes e configurações opcionais.

## Como usar

```bash
chmod +x setup.sh
chmod +x modules/*.sh
chmod +x lib/*.sh
sudo ./setup.sh
```

## Antes de executar

Edite o arquivo `config.conf` e ajuste principalmente:

- `USUARIO="operador"`
- `HOSTNAME_NOVO="workstation"`
- `CONFIGURAR_IP=false`
- `INSTALAR_CHROME=true`
- `INSTALAR_PYTHON_COM_PYENV=false`
- `CONFIGURAR_GRUB=false`

## Estrutura

```text
debian-setup/
├── setup.sh
├── config.conf
├── lib/
│   └── common.sh
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
│   ├── 11-browsers.sh
│   ├── 12-wireshark.sh
│   ├── 13-tilix.sh
│   ├── 14-vscode.sh
│   ├── 15-pyenv.sh
│   ├── 16-fonts.sh
│   ├── 17-packet-tracer.sh
│   └── 18-grub.sh
├── assets/
│   ├── fonts/
│   └── grub/
└── logs/
```

## Observações

Algumas etapas dos PDFs continuam dependendo da interface gráfica, como:

- Fixar ícones na barra lateral.
- Configurar visualmente o Dash to Dock.
- Instalar extensões no Firefox, como uBlock Origin.
- Selecionar manualmente o tema Dracula no Tilix.
- Inserir a imagem dos Adicionais para Convidado pelo menu do VirtualBox.

## tealdeer

O pacote `tldr` foi substituído por `tealdeer`. Após a instalação, o comando normalmente usado continua sendo:

```bash
tldr comando
```

## Wireshark

O módulo `12-wireshark.sh` contém a linha solicitada:

```bash
groupadd wireshark || true
```

Ela foi escrita com `|| true` para evitar falha caso o grupo já exista.
