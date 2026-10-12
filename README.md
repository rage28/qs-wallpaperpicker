# qs-wallpaperpicker

A standalone swatch-deck wallpaper picker for
[Quickshell](https://quickshell.org), adapted for Noctalia and MangoWC.

This is a personal fork of the wallpaper picker originally created by
[dhrruvsharma](https://github.com/dhrruvsharma) as part of
[dhrruvsharma/shell](https://github.com/dhrruvsharma/shell). Many thanks to the
original author for the design, interaction model and implementation this project is
built on.

> This fork has diverged from the original shell and is not supported by its author.
> It is maintained for personal use, provided as-is, and comes with no guarantee of
> support, compatibility or continued maintenance.

## Features

Every wallpaper is a paint-chip card in the colour scheme it would give your desktop
(read with Noctalia's theme generator without applying it). The cards are fanned out
like a hand along the bottom of the screen, and the screen behind them previews the
card in front at full size. The picker's own colours change to match as you browse.

- **Local:** the wallpapers in your wallpaper folder, sorted by name, colour (round the
  hue wheel, so the deck becomes a spectrum) or newest first.
- **Favourites:** the ones you've hearted.
- **Wallhaven:** search [wallhaven.cc](https://wallhaven.cc) and download a wallpaper
  into your folder as you set it.
- Static images and animated GIF/WebP. With the live preview on (the play button, or
  `V`), animated images play in the preview too.
- The card you set comes slowly to the middle of the screen, lights up, and grows into
  the wallpaper (a switch in the settings turns this off: the wallpaper then changes
  straight away and the picker stays open).
- Keyboard, mouse and IPC control, including a `toggle` command that starts the picker
  automatically when it is not already running.
- Wallpaper-command support for Noctalia, `swww`, `hyprpaper`, `swaybg` and other
  Wayland wallpaper tools.

By default the picker sends static wallpapers to Noctalia v5, which owns the wallpaper
surface, persistence, transitions and wallpaper-derived desktop theme. You can use
another Wayland wallpaper tool through the **wallpaper command** setting, or empty that
setting to use the picker's built-in image layer. See [Settings](#settings).

## Differences from the original

This repository is intentionally focused on the picker rather than the complete rice:

- Runs as a standalone Quickshell configuration alongside an existing shell.
- Replaces the original Matugen integration with Noctalia v5 wallpaper palettes and
  templates.
- Supports Noctalia and MangoWC, including Noctalia's built-in Mango template.
- Removes video wallpaper support and its FFmpeg, Qt Multimedia and compositor-specific
  video lifecycle code. Static images and animated GIF/WebP previews remain.
- Includes a Nix flake with a runnable app, installable package and Home Manager module.
- Keeps mutable settings and generated colours outside the read-only Nix store.
- Includes headless Qt Quick logic tests through `nix flake check`.
- Retains the legacy `install.sh` path for non-Nix systems.

## Requirements

- A Wayland compositor with layer-shell. MangoWC is supported; the Noctalia Mango
  template requires Mango 0.18.0 or newer.
- `quickshell` (0.2 or newer), `python3`, `curl`
- [Noctalia v5](https://docs.noctalia.dev/getting-started/installation/), for wallpaper
  display, desktop theming and the cards' generated colour schemes
- The Material Symbols Rounded font

## Install with Nix

The repository includes a flake that packages Quickshell, Noctalia, Python, the
Material Symbols font and the command-line tools used by the picker.

Run the latest GitHub revision directly without installing it:

```sh
nix run github:rage28/qs-wallpaperpicker
```

Or run the current checkout while developing:

```sh
nix run .
```

Or install it into your profile:

```sh
nix profile install github:rage28/qs-wallpaperpicker
```

Bind `qs-wallpaperpicker toggle` in your compositor; it starts the picker automatically
when needed. The application code stays in the Nix store; mutable settings, generated
colours and Noctalia template assets live in
`$XDG_CONFIG_HOME/qs-wallpaperpicker` (normally `~/.config/qs-wallpaperpicker`).

### Home Manager module

Add the repository to your flake inputs:

```nix
inputs.qs-wallpaperpicker = {
  url = "github:rage28/qs-wallpaperpicker";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then import and enable it in your Home Manager configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.qs-wallpaperpicker.homeManagerModules.default ];
  programs.qs-wallpaperpicker.enable = true;
}
```

The module installs the package and declaratively creates Noctalia's configuration, so
no manual `cp` is needed. Noctalia integration is enabled by default. Set
`programs.qs-wallpaperpicker.noctaliaIntegration.enable = false` if you manage that
configuration yourself.

If you only want the package from a flake without the Home Manager module, add this to
your NixOS packages:

```nix
environment.systemPackages = [
  inputs.qs-wallpaperpicker.packages.${pkgs.system}.default
];
```

## Legacy installer

For non-Nix systems, the existing installer remains available:

```sh
git clone <this repo> ~/.config/qs-wallpaperpicker
~/.config/qs-wallpaperpicker/install.sh
```

It lives in its own folder, `~/.config/qs-wallpaperpicker`, outside `~/.config/quickshell`,
so it runs next to your own Quickshell config (or none) without touching it.

`install.sh` does the following:

- installs what the picker needs with your package manager: Quickshell, Noctalia, curl,
  Python and Qt image formats (pacman on Arch; apt on Debian/Ubuntu and dnf on Fedora
  install what they package and tell you where to get Quickshell and Noctalia)
- downloads the Material Symbols Rounded font into `~/.local/share/fonts` if it's missing
- links the folder to `~/.config/qs-wallpaperpicker` if you cloned it elsewhere
- puts the `qs-wallpaperpicker` command on your `PATH`: in `~/.local/bin` if that's on it, otherwise
  (after asking) in `/usr/local/bin`, so it works in every shell and in keybinds right away, and makes `~/Pictures/wallpapers`

Options: `--no-deps` (skip packages and the font), `--copy` (copy the folder instead of
linking it), `--yes` (don't ask).

Start Noctalia at login and bind a key to open the picker. The toggle command starts
the picker automatically when it is not already running.

Hyprland:

```ini
bind = SUPER, W, exec, qs-wallpaperpicker toggle
```

Sway:

```
bindsym $mod+w exec qs-wallpaperpicker toggle
```

Mango:

```ini
exec-once=noctalia
bind=SUPER,w,spawn,qs-wallpaperpicker toggle
```

All its commands:

```sh
qs-wallpaperpicker              # start it
qs-wallpaperpicker toggle       # open/close the picker
qs-wallpaperpicker wallhaven    # open the picker on Wallhaven
qs-wallpaperpicker set <file>   # a name in the wallpaper folder, or a path
qs-wallpaperpicker current      # the wallpaper's path
qs-wallpaperpicker stop         # quit it
qs-wallpaperpicker log          # its log
```

The wrapper runs `qs -p` against the packaged or source config, with the IPC target
`wallpaper` (`toggle`, `wallhaven`, `set`, `current`).

## Updating

For a Nix profile installation, update it with:

```sh
nix profile upgrade qs-wallpaperpicker
```

For a source installation, pull the new version in the folder you cloned. A running
picker reloads itself when its files change:

```sh
cd ~/.config/qs-wallpaperpicker   # or wherever you cloned it
git pull
```

If you used the legacy installer with `--copy`, the copy doesn't follow the clone: after `git pull`, run the
installer again to refresh it. It keeps your settings and colours:

```sh
./install.sh --copy --no-deps
```

Your `settings.json` is kept, and settings that are new start at their defaults. If the
picker doesn't reload by itself, restart it: `qs-wallpaperpicker stop`, then start it again
(`setsid -f qs-wallpaperpicker`, or log out and back in).

## Tests

Run the headless Qt Quick logic tests and the other flake checks with:

```sh
nix flake check
```

The QML suite covers deterministic wallpaper sorting, filtering, formatting, file
classification, path handling, command quoting and settings migration. It deliberately
does not instantiate the layer-shell window, so it runs without a Wayland compositor.

## Using it

| | |
|---|---|
| `←` `→`, wheel, drag | browse |
| `Enter`, click the front card | set it (the card grows into the wallpaper and the picker closes, unless that's switched off in the settings) |
| `F` | favourite |
| `S` | sort: name, colour, newest |
| `R` | a random card |
| `Space` | peek: hold, or tap to keep (the deck steps aside) |
| `V` | live preview: animated GIF/WebP play in the preview |
| `Tab` | next source |
| `/` | search (Wallhaven) |
| `Esc` | close |

## Settings

The gear at the top right opens them. Each field is applied when you press Enter, the
switch as you click it.

- **Wallpaper folder:** where your wallpapers are, and where Wallhaven downloads go.
  `~/Pictures/wallpapers` by default. If the folder you type doesn't exist yet,
  you can create it there.
- **Wallpaper command:** `noctalia msg wallpaper-set {}` by default. This sets the
  static image on all monitors and lets Noctalia persist it and refresh its theme.
  Set another command to use a different tool; `{}` stands for the wallpaper's path and is
  quoted for you wherever it stands (with no `{}`, the path goes at the end). Pressing Enter tries it on the wallpaper on screen
  and tells you whether it worked. Non-Noctalia commands also run once when the picker
  starts, so tools that don't remember the last wallpaper show it again after login. A command that
  keeps running (like `swaybg`) is left running in the background.

  | Tool | Command |
  |---|---|
  | swww | `swww img {}` (add options like `--transition-type grow`) |
  | hyprpaper 0.8+ | `hyprctl hyprpaper wallpaper ",{}"` |
  | older hyprpaper | `hyprctl hyprpaper reload ",{}"` |
  | swaybg | `pkill -x swaybg; swaybg -m fill -i {}` |
  | feh / other X11 tools | not supported: this is Wayland only |

  Start the tool's daemon yourself (e.g. `swww-daemon`) as you do now.
- **Wallhaven API key:** optional. It unlocks NSFW results and your account's
  filters. Find it at [wallhaven.cc/settings/account](https://wallhaven.cc/settings/account).
  Wallhaven is asked to confirm the key works.
- **Setting a wallpaper:** on by default, the card you set grows into the wallpaper and
  the picker closes. Off, the wallpaper changes straight away and the picker stays open,
  so you can keep browsing.

They're kept in `$XDG_CONFIG_HOME/qs-wallpaperpicker/settings.json`, along with the
Wallhaven filters you pick in the picker. The source-tree copy is git-ignored, so your
key stays out of the repo.

## Noctalia colours and MangoWC

Configure Noctalia to derive its palette from the wallpaper, render the picker's
`colors/Colors.json`, and enable its built-in Mango template. The Home Manager module
above does this automatically. For `nix run`, profile, or legacy installations, copy
the bundled example into Noctalia's config directory once:

```sh
qs-wallpaperpicker --help
cp ~/.config/qs-wallpaperpicker/noctalia/qs-wallpaperpicker.toml \
   ~/.config/noctalia/qs-wallpaperpicker.toml
noctalia msg config-reload
```

The example selects `m3-content`, enables Noctalia's `mango` template, and makes the
picker follow the active wallpaper. Noctalia adds its generated Mango include to a
writable `~/.config/mango/config.conf`; if your Mango config is declaratively managed,
source `~/.config/mango/noctalia.conf` yourself.

Mango's layer blur does not filter by a layer surface's transparent pixels. For this
full-screen transparent picker, Noctalia recommends `blur_layer=0` and
`layer_shadows=0` in Mango's config to avoid blurring the whole overlay.

The picker asks a running Noctalia instance which wallpaper scheme it uses, and caches
card palettes by that scheme. If Noctalia is unavailable it falls back to
`m3-content`; wallpaper selection will report the command failure, while the picker UI
continues to work.

## Files it uses

- `~/.cache/current_wallpaper_source` and `~/.cache/current_wallpaper` → the selected
  image, for lock screens and existing scripts
- `~/.cache/quickshell/wallpaper-palettes.json`: the cards' colour schemes
- `~/.cache/quickshell/wallpaper-favorites.json`

## AI-assisted development and support

This fork has been developed and refactored with the assistance of generative AI,
including parts of its code, tests and documentation. AI-assisted changes can contain
mistakes even when automated checks pass; review the source and configuration before
depending on it.

The repository is published primarily to share the maintainer's personal setup. It is
not a supported product: bug fixes, compatibility updates, issue responses and feature
requests are not guaranteed. Please do not ask the original author to support behaviour
specific to this fork.

## License

GPL-3.0-or-later, matching the original project. See `LICENSE`.
