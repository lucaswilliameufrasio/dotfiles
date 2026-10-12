# Comandos úteis de terminal

Funções pequenas para situações recorrentes. Cada uma tem versão para **fish** e para **bash/zsh** (o mesmo código funciona nos dois; testado em bash e zsh).

Como instalar:

- **fish**: salve cada bloco como `~/.config/fish/functions/<nome>.fish`. O fish carrega sob demanda.
- **bash**: cole os blocos em `~/.bashrc` (ou em um arquivo `~/.bash_functions` com `source` no `~/.bashrc`).
- **zsh**: cole os blocos em `~/.zshrc` (ou em um arquivo com `source`).

Nenhum comando abaixo contém senhas, tokens ou caminhos específicos de uma máquina.

## `revive-opencode`

Reinicia o serviço em background do opencode quando ele fica meio-subido: escuta na porta, mas responde 500/503, e a CLI mostra `Background service failed to start`. Uma causa comum é `SQLiteError: database is locked` no boot, quando o disco está saturado. O comando lê o pid em `$XDG_STATE_HOME/opencode/service.json` (padrão `~/.local/state/opencode`), confere que o processo é mesmo do opencode, encerra (SIGTERM e, se preciso, SIGKILL) e espera um novo serviço subir. As sessões ficam no banco local e voltam com `opencode -s <id>`. Terminais persistentes do serviço antigo são perdidos. Não imprime a senha que está no `service.json`.

_Requer `jq`._

### fish

```fish
function revive-opencode --description "Restart a stuck opencode background service (500/503, 'Background service failed to start')"
    set -l state_dir (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo $HOME/.local/state)/opencode
    set -l service_file $state_dir/service.json

    if not test -f $service_file
        echo "No service file at $service_file; nothing to revive. Just run opencode."
        return 1
    end

    set -l pid (jq -r '.pid // empty' $service_file 2>/dev/null)
    if test -z "$pid"; or not string match -q '*opencode*' (cat /proc/$pid/cmdline 2>/dev/null | string replace -a \0 ' ')
        echo "Recorded service (pid '$pid') is not running; opencode will start a new one."
        return 0
    end

    echo "Stopping opencode service (pid $pid)..."
    kill $pid
    for i in (seq 20)
        kill -0 $pid 2>/dev/null; or break
        sleep 0.5
    end
    if kill -0 $pid 2>/dev/null
        echo "Still alive, sending SIGKILL."
        kill -9 $pid
    end

    # Clients (and the next `opencode` run) respawn the service on demand.
    opencode --version >/dev/null 2>&1
    for i in (seq 20)
        set -l new_pid (jq -r '.pid // empty' $service_file 2>/dev/null)
        if test -n "$new_pid"; and test "$new_pid" != "$pid"; and kill -0 $new_pid 2>/dev/null
            echo "Service back up (pid $new_pid)."
            return 0
        end
        sleep 0.5
    end
    echo "Service not respawned yet; reopen opencode (sessions persist: opencode -s <id>)."
end
```

### bash e zsh

```bash
revive-opencode() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
  local service_file="$state_dir/service.json"
  [ -f "$service_file" ] || { echo "No service file at $service_file; just run opencode."; return 1; }

  local pid; pid=$(jq -r '.pid // empty' "$service_file" 2>/dev/null)
  if [ -z "$pid" ] || ! tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q opencode; then
    echo "Recorded service (pid '$pid') is not running; opencode will start a new one."
    return 0
  fi

  echo "Stopping opencode service (pid $pid)..."
  kill "$pid"
  for _ in $(seq 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
  kill -0 "$pid" 2>/dev/null && { echo "Still alive, sending SIGKILL."; kill -9 "$pid"; }

  # Clients (and the next `opencode` run) respawn the service on demand.
  opencode --version >/dev/null 2>&1
  local new_pid
  for _ in $(seq 20); do
    new_pid=$(jq -r '.pid // empty' "$service_file" 2>/dev/null)
    if [ -n "$new_pid" ] && [ "$new_pid" != "$pid" ] && kill -0 "$new_pid" 2>/dev/null; then
      echo "Service back up (pid $new_pid)."; return 0
    fi
    sleep 0.5
  done
  echo "Service not respawned yet; reopen opencode (sessions persist: opencode -s <id>)."
}
```

Exemplo de uso:

```sh
revive-opencode
opencode -s <id-da-sessão>
```

## `io-hogs`

Diagnostica lentidão geral causada por disco. Mostra o PSI (pressão de io/cpu/memória), os processos que mais leem/escrevem durante a amostra (em MB/s, via `/proc/<pid>/io`) e os processos em estado `D` (esperando I/O). CPU e RAM livres com `io` alto indicam que o gargalo é o disco. Sem root, só vê processos do próprio usuário. Argumento opcional: segundos de amostra (padrão 5).

_Linux apenas (`/proc`)._

### fish

```fish
function io-hogs --description "Show I/O pressure and which processes are writing/reading right now (default sample: 5s)"
    set -l secs 5
    set -q argv[1]; and set secs $argv[1]
    set -l dir (mktemp -d)

    echo "== Pressure (PSI) =="
    for r in io cpu memory
        echo "$r: "(head -n1 /proc/pressure/$r)
    end

    function __io_snap
        for p in /proc/[0-9]*
            set -l pid (string replace /proc/ '' $p)
            set -l comm (string replace -a ' ' _ (cat $p/comm 2>/dev/null))
            awk -v pid=$pid -v c="$comm" '/^(read_bytes|write_bytes)/{a[$1]=$2} END{if (a["write_bytes:"] != "") print pid, c, a["read_bytes:"], a["write_bytes:"]}' $p/io 2>/dev/null
        end
    end

    __io_snap | sort >$dir/a
    sleep $secs
    __io_snap | sort >$dir/b
    functions -e __io_snap

    echo
    echo "== Top I/O over $secs""s (MB/s) =="
    join -j1 $dir/a $dir/b | awk -v s=$secs '{w=($7-$4)/s/1e6; r=($6-$3)/s/1e6; if (w+r > 1) printf "W %7.1f  R %7.1f  pid %s %s\n", w, r, $1, $2}' | sort -k2 -rn | head -10

    echo
    echo "== Processes stuck in D state (waiting on I/O) =="
    ps -eo pid,stat,comm | awk '$2 ~ /^D/'
    rm -f $dir/a $dir/b; rmdir $dir
end
```

### bash e zsh

```bash
__io_snap() {
  local p comm
  for p in /proc/[0-9]*; do
    comm=$(cat "$p/comm" 2>/dev/null | tr ' ' _)
    awk -v pid="${p#/proc/}" -v c="$comm" '/^(read_bytes|write_bytes)/{a[$1]=$2} END{if (a["write_bytes:"] != "") print pid, c, a["read_bytes:"], a["write_bytes:"]}' "$p/io" 2>/dev/null
  done
}

io-hogs() {
  local secs="${1:-5}" dir r
  dir=$(mktemp -d) || return 1
  echo "== Pressure (PSI) =="
  for r in io cpu memory; do echo "$r: $(head -n1 /proc/pressure/$r)"; done

  __io_snap | sort > "$dir/a"; sleep "$secs"; __io_snap | sort > "$dir/b"

  echo; echo "== Top I/O over ${secs}s (MB/s) =="
  join -j1 "$dir/a" "$dir/b" | awk -v s="$secs" '{w=($7-$4)/s/1e6; r=($6-$3)/s/1e6; if (w+r > 1) printf "W %7.1f  R %7.1f  pid %s %s\n", w, r, $1, $2}' | sort -k2 -rn | head -10

  echo; echo "== Processes stuck in D state (waiting on I/O) =="
  ps -eo pid,stat,comm | awk '$2 ~ /^D/'
  rm -f "$dir/a" "$dir/b"; rmdir "$dir"
}
```

Exemplo de uso:

```sh
io-hogs        # amostra de 5s
io-hogs 10     # amostra de 10s
```

## `stop-rust-build`

Encerra builds Rust descontrolados, por exemplo dezenas de linkers `rust-lld` em paralelo saturando o disco. Mata por nome exato (`pkill -x`) `cargo`, `rustc`, `rust-lld` e `collect2`, primeiro com SIGTERM e depois com SIGKILL. Nunca use `pkill -f` para isso: ele casa com a linha de comando e pode matar o próprio shell que a contém. Afeta todos os builds Rust do usuário, então confirme que não há um build seu legítimo em andamento.

_Linux apenas._

### fish

```fish
function stop-rust-build --description "Kill runaway Rust builds (cargo/rustc/linkers) by exact process name"
    set -l names cargo rustc rust-lld collect2
    for n in $names
        set -l c (pgrep -xc $n)
        test "$c" -gt 0; and echo "Stopping $c x $n"
        pkill -x $n
    end
    sleep 2
    # Anything that ignored SIGTERM
    for n in $names
        pgrep -x $n >/dev/null; and pkill -9 -x $n
    end
    echo "PSI io: "(head -n1 /proc/pressure/io)
end
```

### bash e zsh

```bash
stop-rust-build() {
  local n c
  for n in cargo rustc rust-lld collect2; do
    c=$(pgrep -xc "$n"); [ "$c" -gt 0 ] && echo "Stopping $c x $n"
    pkill -x "$n"
  done
  sleep 2
  for n in cargo rustc rust-lld collect2; do pgrep -x "$n" >/dev/null && pkill -9 -x "$n"; done
  echo "PSI io: $(head -n1 /proc/pressure/io)"
}
```

Exemplo de uso:

```sh
io-hogs && stop-rust-build
```

Para evitar o problema na origem, reduza o volume de debug info escrito no link em `Cargo.toml`:

```toml
[profile.dev]
debug = "line-tables-only"
```

E rode testes com menos paralelismo e prioridade baixa de CPU e disco: `nice -n19 ionice -c3 cargo test -j4`.
