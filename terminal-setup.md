# Terminal Setup (Linux & macOS)

## Terminal Emulator

### Option A: Ghostty

Config at `~/.config/ghostty/config`:

```ini
# Everforest Dark theme
background = #2d353b
foreground = #d3c6aa

palette = 0=#4f585e
palette = 1=#e67e80
palette = 2=#a7c080
palette = 3=#dbbc7f
palette = 4=#7fbbb3
palette = 5=#d699b6
palette = 6=#83c092
palette = 7=#9da9a0

palette = 8=#475258
palette = 9=#e67e80
palette = 10=#a7c080
palette = 11=#dbbc7f
palette = 12=#7fbbb3
palette = 13=#d699b6
palette = 14=#83c092
palette = 15=#d3c6aa
```

Install on macOS: `brew install --cask ghostty`
Install on Arch: `pacman -S ghostty`

### Option B: Alacritty (already configured)

Config at `~/.config/alacritty/alacritty.toml` with Nord theme.
Replace with Everforest if desired:

```toml
[colors.primary]
background = "0x2d353b"
foreground = "0xd3c6aa"

[colors.normal]
black = "0x4f585e"
red = "0xe67e80"
green = "0xa7c080"
yellow = "0xdbbc7b"
blue = "0x7fbbb3"
magenta = "0xd699b6"
cyan = "0x83c092"
white = "0x9da9a0"

[colors.bright]
black = "0x475258"
red = "0xe67e80"
green = "0xa7c080"
yellow = "0xdbbc7b"
blue = "0x7fbbb3"
magenta = "0xd699b6"
cyan = "0x83c092"
white = "0xd3c6aa"
```

Install on macOS: `brew install --cask alacritty`
Install on Arch: `pacman -S alacritty`

---

## Shell: Fish

Install: `pacman -S fish` (Arch) / `brew install fish` (macOS)

Set as default: `chsh -s /usr/bin/fish`

### Pure prompt (current setup)

Installed via `fisher install pure-fish/pure`. Colors are already configured in `fish_variables`. Main color values:

- `pure_color_success = magenta` — change to `green` if too vibrant
- `pure_color_primary = blue`
- `pure_color_info = cyan`
- `pure_color_mute = brblack`

### Replicate on another machine

```sh
# Install fish
# On macOS: brew install fish
# On Arch:   sudo pacman -S fish

# Set as default shell
chsh -s $(which fish)

# Install Fisher (plugin manager)
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

# Install Pure prompt
fish -c "fisher install pure-fish/pure"

# Copy config files
cp -r ~/.config/fish ~/.config/
```

---

## Terminal Multiplexer: Herdr

You already use Herdr (similar to tmux). It uses your terminal emulator's colors for its UI, so fixing the terminal emulator fixes Herdr too.

---

## TUI File Manager: Yazi

Install from official repos (safe — not AUR):
- **Arch Linux:** `sudo pacman -S yazi`
- **macOS:** `brew install yazi`

Config at `~/.config/yazi/` — three files:

### `yazi.toml` — general settings

```toml
[manager]
show_hidden = true
sort_dir_first = true
sort_by = "natural"
linemode = "size"

[preview]
tab_size = 2
wrap = "no"

[opener]
edit = [
  { run = "helix %s", block = true, for = "unix" },
]
```

### `theme.toml` — Everforest Dark (matches everything else)

```toml
[app]
overall = { bg = "#2d353b" }

[manager]
cwd = { fg = "#dbbc7f", bold = true }
border_style = { fg = "#4f585e" }
marker_selected = { fg = "#a7c080" }
marker_copied = { fg = "#7fbbb3" }
marker_cut = { fg = "#e67e80" }
marker_marked = { fg = "#d699b6" }

[tabs]
active = { fg = "#d3c6aa", bg = "#2d353b" }
inactive = { fg = "#7a8478", bg = "#343f44" }

[mode]
normal_main = { fg = "#2d353b", bg = "#a7c080" }
normal_alt = { fg = "#a7c080", bg = "#3d484d" }
select_main = { fg = "#2d353b", bg = "#7fbbb3" }
select_alt = { fg = "#7fbbb3", bg = "#3d484d" }
unset_main = { fg = "#2d353b", bg = "#e67e80" }
unset_alt = { fg = "#e67e80", bg = "#3d484d" }

[status]
overall = { fg = "#d3c6aa", bg = "#3d484d" }
progress_normal = { fg = "#2d353b", bg = "#a7c080" }
progress_error = { fg = "#2d353b", bg = "#e67e80" }

[which]
mask = { bg = "#2d353b" }
cand = { fg = "#dbbc7f" }

[filetype]
rules = [
  { mime = "image/*", fg = "#d699b6" },
  { mime = "{audio,video}/*", fg = "#83c092" },
  { mime = "text/*", fg = "#d3c6aa" },
  { mime = "application/*", fg = "#7fbbb3" },
  { url = "*/", fg = "#7fbbb3" },
  { url = "*", fg = "#d3c6aa" },
]
```

### Replicate

```sh
# Copy the whole config directory
cp -r ~/.config/yazi ~/.config/

# Install deps for previews (optional)
sudo pacman -S ffmpeg 7zip jq poppler fd ripgrep fzf
```

---

## Color Reference Table

| Role | Hex | Description |
|------|-----|-------------|
| bg0  | `#2d353b` | Background |
| fg   | `#d3c6aa` | Foreground |
| red  | `#e67e80` | Errors, keywords |
| green| `#a7c080` | Success, strings |
| yellow| `#dbbc7f` | Warnings |
| blue | `#7fbbb3` | Info |
| purple| `#d699b6` | Accents |
| aqua | `#83c092` | Cyan-ish |
| grey0| `#4f585e` | Muted text |
