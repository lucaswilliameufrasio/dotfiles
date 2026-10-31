# Caixa Bluetooth que fica caindo

Anotado em 31/10/2026 na máquina `ursoc`, com a caixa **PBS45BT**, PipeWire 1.6, WirePlumber 0.5.18 e BlueZ 5.87.

A caixa parecia desligar e ligar sozinha a cada 14 segundos. O adaptador Bluetooth não reiniciava. Eram dois problemas empilhados.

## 1. Viva-voz que não completa

A PBS45BT anuncia música (A2DP) e viva-voz (HFP, "Hands-Free Voice gateway"). O viva-voz expira. Enquanto essa tentativa está aberta, o perfil de música falha com `Device or resource busy`. O KDE procura `bluez_output.<endereço>.1`, o nó some, e a caixa parece desconectar.

O BlueZ registra o viva-voz uma vez para o adaptador inteiro. Uma regra só no aparelho não impede essa tentativa. O que corta o ciclo é tirar `hsp` e `hfp` de `bluez5.roles`.

Efeito colateral: o microfone de outros fones Bluetooth fica desligado até apagar o arquivo gerado e reiniciar o WirePlumber.

## 2. BlueZ 5.87 não relê o codec salvo

Mesmo depois de desligar o viva-voz, o log continua assim:

```text
profiles/audio/a2dp.c:load_remote_sep() Unable to load LastUsed: rseid 1 not found
src/service.c:btd_service_connect() a2dp-sink profile connect failed: Device or resource busy
plugins/policy.c:reconnect_timeout() Reconnecting services failed
```

O BlueZ 5.87 descarta os endpoints A2DP gravados em cache. O commit [`912f5ef`](https://github.com/bluez/bluez/commit/912f5efb0dd9) faz o laço que lê essa cache começar em zero e exigir `i >= 2`, então o corpo nunca roda. Cada reconexão perde o codec e entra numa disputa com a própria caixa. A correção é o commit [`b7d71e5`](https://github.com/bluez/bluez/commit/b7d71e5067856b0daf2f1f73b3fc95483236610e), prevista para o BlueZ 5.88 ([bluez#2285](https://github.com/bluez/bluez/issues/2285)).

Em 31/10/2026 os repositórios CachyOS e Arch ainda ofereciam `bluez` e `bluez-utils` **5.87-2.1**, a mesma versão já instalada. `sudo pacman -S bluez` não troca o pacote.

A cache quebrada fica em:

```text
/var/lib/bluetooth/<adaptador>/cache/<caixa>
```

O diretório é do root. O `sudo` pede a senha no terminal, na linha `[sudo] senha para <usuário>:`. Nada aparece enquanto se digita. A senha não entra no chat nem nestes scripts.

## Aplicar

Na raiz deste repositório:

```sh
./scripts/bluetooth/apply-a2dp-only.sh --dry-run
./scripts/bluetooth/apply-a2dp-only.sh
```

O nome padrão é `PBS45BT`. Para outra caixa pareada:

```sh
./scripts/bluetooth/apply-a2dp-only.sh "Nome Da Caixa"
./scripts/bluetooth/apply-a2dp-only.sh AA:BB:CC:DD:EE:FF
```

O script descobre o endereço com `bluetoothctl`, grava `~/.config/wireplumber/wireplumber.conf.d/51-a2dp-only.conf`, apaga a memória `saved-headset-profile:` dessa caixa em `~/.local/state/wireplumber/bluetooth-autoswitch` e reinicia o WirePlumber do usuário. Se existir `51-pbs45bt-a2dp.conf` deixado pela primeira correção, o script remove esse arquivo para não haver duas definições de `monitor.bluez.properties`.

## Limpar a cache e reconectar

```sh
./scripts/bluetooth/reset-speaker-cache.sh --dry-run
./scripts/bluetooth/reset-speaker-cache.sh
```

O script desconecta a caixa, apaga só o arquivo de cache dela, reinicia o serviço `bluetooth` e conecta de novo. Teclado e controle em USB não passam por esse serviço. Outros aparelhos Bluetooth caem durante a reinicialização e o BlueZ volta a conectar os que estiverem marcados como confiáveis.

Quando o BlueZ 5.88 ou mais novo aparecer no repositório:

```sh
sudo pacman -S --needed bluez bluez-utils
sudo systemctl restart bluetooth
```

Aí dá para apagar `51-a2dp-only.conf` e devolver o microfone dos fones, se quiser.

## Conferir

```sh
bluetoothctl devices | rg PBS45BT
pactl list cards | rg 'PBS45|headset-head-unit|Active Profile'
journalctl -u bluetooth --since "2 min ago" -o cat | rg 'Hands-Free|LastUsed|reconnect_timeout'
```

O perfil ativo da caixa fica em `a2dp-sink`. `headset-head-unit` deixa de aparecer na lista dela. Uma janela quieta no `journalctl` significa que o ciclo parou.

## Desfazer o viva-voz

```sh
rm -f ~/.config/wireplumber/wireplumber.conf.d/51-a2dp-only.conf
systemctl --user restart wireplumber
```
