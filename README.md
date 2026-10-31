# Dotfiles

Guias para reproduzir configurações portáveis entre máquinas.

## Setup inicial

Em macOS com Homebrew, Arch Linux, Debian ou Ubuntu, clone o repositório e rode:

```sh
./setup.sh --dry-run  # confira os comandos primeiro
./setup.sh
```

O script instala ferramentas de linha de comando pelos gerenciadores nativos.
No Debian/Ubuntu, pacotes indisponíveis nas fontes APT configuradas são
reportados e ignorados. O script não altera o shell padrão nem sobrescreve
arquivos de configuração existentes.

## Guias

- `terminal-setup.md` — terminal, Fish, Yazi e paleta Everforest.
- `helix-setup.md` — tema e configuração do editor Helix.
- `useful-commands.md` — funções úteis de terminal e helpers portáveis de desenvolvimento para Fish, bash e zsh.
- `bluetooth-speaker.md` — caixa Bluetooth que reconecta sozinha (PBS45BT, BlueZ 5.87) e os scripts em `scripts/bluetooth/`.
- `setup.sh` — instalação inicial de ferramentas em macOS e Linux.

O script instala ferramentas, mas não altera nem copia configurações do usuário. Consulte os guias para aplicar preferências manualmente e ajuste os passos conforme o sistema operacional.
