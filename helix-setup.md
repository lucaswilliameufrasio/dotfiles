# Helix Editor Setup

## Theme: Everforest Dark

Set in `~/.config/helix/config.toml`:

```toml
theme = "everforest_dark"
```

This references the built-in theme at `/usr/lib/helix/runtime/themes/everforest_dark.toml`.

### Key visual improvements over a purple-only scheme:

| Aspect | Before (all-purple) | After (Everforest Dark) |
|---|---|---|
| Background | Uniform dark purple | Muted warm dark (`#2d353b`) |
| Keywords | Purple | Red (`#e67e80`) |
| Strings | Purple | Aqua (`#83c092`) |
| Functions | Purple | Green (`#a7c080`) |
| Types | Purple | Yellow (`#dbbc7f`) |
| Line numbers | Purple | Dim grey |
| Statusline | Purple | Contextual colors per mode |
| Selection | Purple highlight | Subtle grey highlight |
| Diagnostics | Purple | Green/blue/yellow/red by severity |

### Replicate on another machine

1. Install Helix (or copy the `hx` binary)
2. Create `~/.config/helix/config.toml` with `theme = "everforest_dark"`
3. The theme ships with Helix — no extra files needed

### Alternative themes to try (all ship with Helix)

- `catppuccin_mocha` — muted purple/pink/blue
- `dracula` — vibrant purple/pink/cyan
- `tokyo_night` — deep blue/purple night vibe
- `ayu_dark` — warm orange/blue
