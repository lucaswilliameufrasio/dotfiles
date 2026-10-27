# Helpers de desenvolvimento

Funções portáveis, sem informações de máquinas ou infraestrutura. Nada é
executado ao carregar as definições. Requerem Git e bash; operações específicas
também precisam de CocoaPods, asdf ou curl.

## Instalação

Na raiz deste repositório:

```sh
bash shell/install.sh zsh
# Ou, conforme a shell usada:
bash shell/install.sh fish
bash shell/install.sh bash
```

O instalador copia os helpers para `~/.config/development-helpers/` e adiciona
uma linha ao arquivo de inicialização correspondente. Não troca a shell padrão.
As definições anteriores permanecem intactas, mas as novas definições de mesmo
nome têm precedência ao carregar o módulo. Arquivos anteriores são copiados
para `~/.config/development-helpers/backups/`. Execute novamente para atualizar;
a linha de carregamento não é duplicada.

Abra uma nova sessão para carregar as funções. Em zsh/bash, também é possível
carregar apenas o módulo, sem reexecutar toda a configuração:

```sh
source "$HOME/.config/development-helpers/development.sh"
```

Em Fish:

```fish
source "$HOME/.config/development-helpers/development.fish"
```

As funções Fish usam `$argv` e delegam a implementação compartilhada ao bash.
Argumentos não são interpolados em código; espaços são preservados. Comandos
Git operam no repositório atual, inclusive checkout de branches. Nenhum helper
precisa mudar o diretório da shell chamadora. Plugins asdf precisam estar
disponíveis pelo executável `asdf` no `PATH`.

## Git

O remote padrão é `o`, mantendo a convenção dos helpers originais. Passe outro
remote quando necessário. O módulo não renomeia remotes automaticamente.

| Função | Argumentos | Comportamento |
| --- | --- | --- |
| `checkout-to-branch-and-pull-changes` | `<branch> [remote]` | Troca de branch e faz pull com rebase. |
| `pull-branch` | `<branch> [remote]` | Atualiza a branch e volta à branch original após sucesso. |
| `merge-and-push-to-branch` | `<branch> [remote]` | Atualiza o destino, integra a branch atual, publica e volta após sucesso. |
| `rebase-to-branch` | `<branch> [remote]` | Atualiza o destino e inicia rebase interativo na branch original. |
| `set-upstream-to-current-branch` | `[remote]` | Define upstream usando o remote informado. Não publica commits. |
| `create-release-branch` | — | Cria `release` a partir de HEAD. Confirma antes de apagar uma `release` existente. |
| `create-release-and-push` | `[remote]` | Atualiza `develop`, cria `release` e publica. |
| `create-release-branch-from-tag` | `<tag>` | Cria `release` a partir de uma tag local. |
| `create-release-from-tag-and-push` | `<remote> <tag>` | Busca tags, cria `release` a partir da tag e publica. |
| `reset-and-push-to-branch` | `<branch> [remote]` | Substitui destino local/remoto pela branch atual, com confirmação e lease explícito. |
| `delete-current-branch-from-local-and-go-to-branch` | `<branch>` | Troca de branch e tenta remover a anterior com `git branch -d`. |
| `clean-git-branches` | `[branch-protegida]` | Remove somente branches integradas em HEAD, com `-d`; preserva a atual e `main`, `master`, `develop`, `dev`, `release`. |
| `rename-origin-to-o` | — | Renomeia o remote `origin` para `o`. |
| `commit-with-friendly-message` | `<mensagem>` | Cria commit apenas com arquivos já selecionados no staging. |
| `commit-with-random-message` | — | Busca uma mensagem pública via curl e cria commit do staging; evite em projetos profissionais. |
| `integrate-to-branch` | `[branch=dev-test] [remote]` | Integra e publica por worktree persistente sem trocar a branch da sessão original. |
| `check-repositories-with-pending-changes` | `[diretório=.]` | Lista alterações sem commit e commits à frente do upstream, incluindo worktrees e submódulos. |

Exemplos:

```sh
pull-branch develop origin
set-upstream-to-current-branch origin
create-release-from-tag-and-push origin v1.2.3
check-repositories-with-pending-changes ~/projects
```

### Segurança e diferenças em relação a helpers sem validação

- Comandos compostos param no primeiro erro. Conflitos de merge/rebase ficam
  disponíveis para resolução manual; o helper não esconde o erro nem troca
  de branch por cima de uma operação interrompida.
- Atualizações e integrações exigem árvore limpa e HEAD em uma branch.
- Recriar uma `release` existente apaga essa referência local com `-D` e exige
  confirmação `yes` em terminal interativo. A branch não pode estar em uso em
  outro worktree. Verifique antes se há commits exclusivos a preservar.
- Reset remoto também exige `yes` e usa `--force-with-lease` com o commit
  remoto observado no fetch, nunca `--force`. Continua sendo destrutivo; se o
  push falhar, a branch local pode já ter sido alterada. Revise o reflog.
- Limpeza e remoção comum não usam `-D`: Git recusa remover branches não
  integradas conforme suas verificações habituais.
- Os helpers de commit **não** fazem `git add .`. Selecione os arquivos antes.
- Integração usa `~/git-worktrees/`, atualiza o destino com fast-forward e não
  oferece sobrescrita forçada. Em conflito ou falha de push, preserva o
  worktree e informa seu caminho. Resolva e remova-o manualmente depois.
- Verificação de pendências não executa fetch: a comparação usa o upstream
  disponível localmente. Branch sem upstream não tem seus commits contados
  como pendentes de push.

## Ambiente e diagnóstico

| Função | Argumentos | Observações |
| --- | --- | --- |
| `flutter-update-pods` | — | Executa `pod install --repo-update` em `ios`, preservando `Podfile.lock` e o diretório atual. Requer CocoaPods e projeto iOS. |
| `install-new-version-using-asdf` | `<plugin> <versão>` | Instala a versão; plugin precisa estar configurado. |
| `make-version-global-using-asdf` | `<plugin> <versão>` | Usa `asdf set -u`; aceita `asdf global` em versões antigas. |
| `install-new-version-and-make-global-using-asdf` | `<plugin> <versão>` | Instala e só define a versão global após sucesso. |
| `vmrss` | `<pid>` | Mostra `VmRSS` a cada segundo em Linux; Ctrl-C interrompe. Não funciona em macOS. |

Não instale dependências só para disponibilizar um helper sem uso. A presença
das definições é inerte; funções sem suas dependências falham quando chamadas.

## Verificação

```sh
bash -n setup.sh shell/install.sh shell/development.sh
zsh -n shell/development.sh
fish -n shell/development.fish
python3 -m unittest discover -s shell/tests -v
git diff --check
```

Os testes usam repositórios Git locais isolados, sem acessar remotes externos,
e verificam carregamento, argumentos, prevenção de operações destrutivas,
upstream, tags, falhas intermediárias e instalação idempotente. Não há etapa de
build ou dependências de banco de dados neste repositório.
