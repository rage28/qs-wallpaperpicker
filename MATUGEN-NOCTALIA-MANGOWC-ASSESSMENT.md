# Matugen, Noctalia, and MangoWC compatibility assessment

Date: 2026-10-12

> Historical assessment: the migration described here has now been implemented
> in this working tree. Matugen and file-video wallpaper support were removed;
> current setup instructions are in `README.md`.

## Scope and assumptions

This is a read-only design assessment of the current repository. No application,
installer, or configuration code was changed. The only repository change is this
report.

"Noctalia" below means the current native Noctalia v5+, not the archived
Quickshell-based Noctalia Shell v4. That distinction matters: v5 uses the
`noctalia msg ...` CLI and has its own theme generator. Its upstream documentation
says that v4 and v5 are separate installations.

## Conclusion

Matugen can be removed, but it is not a one-line dependency deletion if the
picker's defining swatch-card behavior is to be preserved.

Today Matugen has two independent responsibilities:

1. It generates a Material palette for every local wallpaper so that cards,
   color sorting, and the spectrum ribbon reflect the theme that wallpaper would
   produce.
2. After a wallpaper is selected, it runs the user's Matugen templates to recolor
   the rest of the desktop and, optionally, this picker itself.

Neither responsibility is inherently compositor-specific. Matugen has no direct
role in Hyprland, MangoWC, layer-shell, wallpaper drawing, transitions, IPC,
favorites, Wallhaven, or video-frame extraction.

For a Noctalia v5 + MangoWC desktop, Noctalia can replace both Matugen roles:

- `noctalia msg wallpaper-set <path>` can own static wallpaper selection,
  persistence, and wallpaper-derived theme updates.
- `noctalia theme <image> --scheme <scheme> --dark` can generate palette JSON
  without applying the wallpaper, making it a viable source for per-card previews.
- Noctalia user templates can generate this project's `colors/Colors.json`.
- Noctalia ships a Mango compositor theme template, so Mango's colors can follow
  the same palette without Matugen.

The recommended end state is therefore **Noctalia owns wallpaper state and
desktop theming; this project remains the picker UI**. Static-image support is a
straightforward integration. Animated/video wallpapers need a deliberate policy:
Noctalia's normal wallpaper IPC is documented for images, while video support is
provided separately by its official `mpvpaper` plugin. The current picker cannot
transparently send its video selections to that plugin with the same command used
for images.

## Where Matugen is used

| Location | Role | Required at runtime? | Effect if absent today |
|---|---|---:|---|
| [`install.sh`](install.sh#L16) | Pacman package/manual dependency and post-install warning | Installer-level requirement | Installation warns; on Arch it attempts to install Matugen |
| [`scripts/wallpaper-palettes.py`](scripts/wallpaper-palettes.py#L108) | Runs `matugen image ... --dry-run -j` once per uncached wallpaper | Yes, for local card palettes | Each scan result is stored as an error entry; cards lose generated schemes and color sorting degrades |
| [`services/WallpaperSwatches.qml`](services/WallpaperSwatches.qml#L7) | Starts the palette scanner, caches its output, and exposes scheme/sort helpers | Indirectly | Picker itself still opens; affected cards fall back to the global picker palette |
| [`scripts/wallpaper-apply`](scripts/wallpaper-apply#L20) | Runs `matugen image` after selection to execute the user's Matugen templates | No; explicitly optional | Wallpaper links are still updated, but external desktop recoloring does not happen |
| [`extras/matugen/quickshell.json.hbs`](extras/matugen/quickshell.json.hbs#L1) | Optional template that emits `colors/Colors.json` | No | Picker uses the built-in dark fallback colors |
| [`README.md`](README.md#L32) | Documents Matugen as a requirement and explains the template | Documentation only | Documentation becomes inaccurate after a replacement |
| [`scripts/install-common.sh`](scripts/install-common.sh#L156) | Preserves generated `colors/Colors.json` during copy-mode updates | No | This behavior remains useful regardless of which theme engine writes the file |

There are no other executable Matugen calls in the repository.

## Current data flows

### 1. Per-wallpaper card palettes

When the local wallpaper list changes, [`Wallpaper.qml`](modules/wallpaper/Wallpaper.qml#L256)
asks `WallpaperSwatches` to ensure that every wallpaper has a cached entry.
`WallpaperSwatches` starts [`wallpaper-palettes.py`](services/WallpaperSwatches.qml#L145),
which:

- reads image dimensions directly;
- calls `wallpaper-still` first for a video, so palette extraction sees a cached
  video frame;
- runs up to three Matugen processes concurrently;
- retains the Material roles used by the UI; and
- streams JSON records back to QML, where they are cached by filename and mtime in
  `~/.cache/quickshell/wallpaper-palettes.json`.

Those results drive three visible features:

- the card surface, text, outline, and accent colors;
- the five named chips on each local wallpaper card; and
- color sorting and the spectrum ribbon.

The relevant UI fallback is already graceful. [`SwatchCard.qml`](modules/wallpaper/SwatchCard.qml#L77)
uses the generated scheme when present, Wallhaven-provided image colors for online
results, and the picker's global `Colors` palette otherwise. Consequently Matugen
is a **feature dependency**, not a launch dependency.

One subtle coupling is important: the current scanner uses Matugen's
`--source-color-index 0`, and `wallpaper-apply` uses the same option. That is why a
card is intended to preview the exact theme that selecting it will apply. A
replacement should keep palette generation and actual desktop theming on the same
Noctalia scheme (for example `m3-content`), or the card preview will be misleading.

### 2. Applying a selected wallpaper

[`WallpaperEngine.set()`](services/WallpaperEngine.qml#L86) performs three actions:

1. updates in-memory current-wallpaper state;
2. runs the configured external wallpaper command when one is present; and
3. always runs `scripts/wallpaper-apply`.

`wallpaper-apply` creates these compatibility links before it invokes Matugen:

- `~/.cache/current_wallpaper_source` -> the selected source file;
- `~/.cache/current_wallpaper` -> the source image or a cached still frame for a
  video.

Those links are independent of Matugen and should remain. They are useful to lock
screens and other consumers even after Noctalia becomes the wallpaper owner.

The Matugen invocation at the end of this script is already optional:
[`command -v matugen ... || exit 0`](scripts/wallpaper-apply#L23). Removing it does
not prevent wallpaper selection or link persistence.

### 3. Coloring the picker itself

[`colors/Colors.qml`](colors/Colors.qml#L9) watches `colors/Colors.json`, parses it,
and supplies defaults for every missing role. The JSON file is not tracked. The
bundled Matugen template is only one producer of that file; nothing in `Colors.qml`
cares which program generated it.

This is an especially clean replacement point for Noctalia. The existing template
uses direct expressions such as `{{ colors.primary.default.hex }}`, which Noctalia
v5 also supports. It contains no Matugen-only control-flow blocks, so it can be
adapted as a Noctalia user template with little or no body change. Noctalia's
template configuration can point its output at this repository's
`colors/Colors.json`; the existing file watcher will reload it live.

## Noctalia v5 replacement design

### Recommended ownership model

Use a single wallpaper owner:

| Concern | Recommended owner |
|---|---|
| Picker overlay, favorites, Wallhaven browsing, card animation | `qs-wallpaperpicker` |
| Static desktop wallpaper surface and transition | Noctalia |
| Persisted default/per-monitor wallpaper state | Noctalia |
| Active wallpaper-derived palette | Noctalia |
| App and Mango template rendering | Noctalia |
| Per-card dry-run palette generation | Noctalia CLI, called by this project |
| Current-wallpaper compatibility symlinks | This project's `wallpaper-apply` |

The current settings already have the basic handoff mechanism: any nonempty
`wallpaperCommand` makes `WallpaperEngine.external` true, so
[`WallpaperLayer.qml`](modules/wallpaper/WallpaperLayer.qml#L23) creates no
background surfaces. For Noctalia v5 the command would conceptually be:

```sh
noctalia msg wallpaper-set {}
```

The settings code safely substitutes the selected path for `{}` and quotes it
according to the command's surrounding shell quotes.

This is preferable to allowing both projects to create background-layer wallpaper
surfaces. Competing owners can produce undefined stacking, duplicated transitions,
and disagreement over the persisted current wallpaper.

### Replacing global Matugen application

After Noctalia owns the wallpaper, `wallpaper-apply` should no longer run Matugen.
Noctalia's theme source should be configured as `wallpaper`, with a chosen
`wallpaper_scheme`. Noctalia documents that wallpaper-derived palettes are
re-resolved automatically when its default wallpaper changes.

Conceptual Noctalia configuration:

```toml
[theme]
source = "wallpaper"
wallpaper_scheme = "m3-content"

[theme.templates]
enable_builtin_templates = true
builtin_ids = ["mango"]

[theme.templates.user.qs_wallpaperpicker]
input_path = "/absolute/path/to/qs-wallpaperpicker/extras/noctalia/quickshell.json"
output_path = "/absolute/path/to/qs-wallpaperpicker/colors/Colors.json"
```

The paths and template location above are a proposed layout, not files that exist
in this repository today. The Mango built-in template requires Mango 0.18.0 or
newer according to Noctalia's documentation.

### Replacing per-card Matugen dry runs

Noctalia v5's theme CLI can generate a palette from an image and print JSON without
changing the active wallpaper:

```sh
noctalia theme "/path/to/image" --scheme m3-content --dark
```

Upstream implementation confirms that, when no output file or template work is
requested, the generated JSON is written to standard output. This makes the CLI a
direct conceptual replacement for the Matugen subprocess in
`wallpaper-palettes.py`.

This replacement still needs code work later:

- change the command and adapt parsing from Matugen's JSON shape to Noctalia's;
- choose the same scheme Noctalia uses for the active wallpaper;
- include the palette provider and scheme in the cache version/key, otherwise old
  Matugen entries can survive the migration and scheme changes can leave stale
  cards;
- decide how to discover the scheme (`noctalia msg color-scheme-get`, a picker
  setting, or a documented fixed default);
- retain the current still-frame path for videos; and
- handle Noctalia being unavailable without repeatedly rescanning every failed
  item.

If exact Material role previews are not considered essential, the lower-complexity
alternative is to remove generated schemes entirely and derive a small card dress
from dominant image colors, as the existing Wallhaven fallback already does.
That would remove both Matugen and the Noctalia CLI from scanning, but it would no
longer promise that a card shows the exact desktop theme produced by that image.

## MangoWC compatibility

### What is already compositor-neutral

- The picker is a full-screen `WlrLayerShell` overlay with its own namespace and
  exclusive keyboard focus ([`shell.qml`](shell.qml#L30)).
- The wallpaper surface is a standard background-layer surface
  ([`WallpaperLayer.qml`](modules/wallpaper/WallpaperLayer.qml#L103)).
- Noctalia upstream explicitly lists Mango among its supported compositor
  integrations.
- Mango itself documents Quickshell as a supported status-bar/shell option and
  recommends layer-shell wallpaper tools such as `swww` and `swaybg`.

Therefore there is no Matugen-versus-Mango problem. The compositor integration and
the palette generator are separate concerns.

### Hyprland-specific code that remains

The only direct compositor-specific implementation in this repository is the
video pause optimization:

- [`WallpaperLayer.qml`](modules/wallpaper/WallpaperLayer.qml#L5) imports
  `Quickshell.Hyprland` and types a property as `HyprlandWorkspace`;
- [`services/Hyprland.qml`](services/Hyprland.qml#L13) checks
  `HYPRLAND_INSTANCE_SIGNATURE`, calls `hyprctl clients -j`, and listens for
  Hyprland events.

On Mango, `services/Hyprland.qml` does not start `hyprctl`, and the covered-window
state remains false, so wallpapers play continuously. This is documented behavior
for non-Hyprland compositors, not a Matugen issue.

For true Mango portability, a later implementation should remove the compile-time
Hyprland type from the generic wallpaper layer and put coverage detection behind a
compositor-neutral service. If Noctalia owns the wallpaper surface, however, this
code path creates no wallpaper windows and the limitation is mostly irrelevant.

### Mango layer blur caveat

Noctalia's Mango guide warns that Mango's SceneFX layer blur does not filter by
surface opacity. This project uses a transparent full-screen overlay, so enabling
Mango's layer blur can blur more of the screen than intended while the picker is
open. The upstream-recommended Mango configuration disables `blur_layer` and
`layer_shadows` (or otherwise uses Noctalia-rendered shadows). This is a visual
compatibility setting, not a code failure.

### Static versus animated/video wallpapers

| Wallpaper type | Noctalia-owned static integration | Current picker-owned renderer |
|---|---:|---:|
| PNG/JPEG/WebP and other static images | Recommended | Supported |
| Animated GIF/WebP | Verify against the installed Noctalia version | Supported by Qt |
| MP4/WebM/MKV/MOV/M4V | Not through ordinary `wallpaper-set`; use Noctalia's official `mpvpaper` plugin | Supported by Qt Multimedia |

Noctalia's official video-wallpaper plugin works on Mango and supports `mp4`,
`webm`, `mkv`, `mov`, and `gif`, but its documented IPC controls playback rather
than exposing the same arbitrary-path setter as `wallpaper-set`. Preserving this
picker's unified image/video selection UX would therefore require one of these
explicit choices:

1. support static images first and hand video selection to Noctalia's plugin UI;
2. add a small Noctalia plugin/API bridge that accepts a video path from this
   picker; or
3. keep this project's renderer, disable Noctalia's wallpaper surface, and
   decouple the current `wallpaperCommand` setting into separate renderer and
   after-selection/theme hooks.

Option 1 is the smallest reliable integration. Option 2 preserves the best user
experience. Option 3 preserves this project's Qt video transitions but creates
more lifecycle and theme-state coordination work.

## Proposed future change sequence

No changes in this sequence were made during this assessment.

1. Add an explicit integration mode rather than silently assuming every external
   wallpaper command is equivalent. A `Noctalia v5` preset can supply the correct
   command and explain static/video behavior.
2. Make Noctalia the static wallpaper owner and verify that the picker creates no
   `quickshell:wallpaper` layer surfaces in external mode.
3. Replace Matugen in `wallpaper-palettes.py` with the Noctalia theme CLI, bump the
   cache format, and test several schemes and grayscale images.
4. Add a Noctalia user-template asset for `Colors.json`; keep `Colors.qml` and its
   fallback behavior unchanged.
5. Remove the Matugen call from `wallpaper-apply`, but retain both current-wallpaper
   symlinks and still extraction.
6. Remove Matugen from installer package lists, warnings, README requirements, and
   the old `extras/matugen` documentation only after the replacement works.
7. Document and test Mango's layer blur/shadow settings and Mango >=0.18.0 for the
   Noctalia Mango template.
8. Decide and implement the video policy separately; do not make it an accidental
   regression in the static integration.

## Acceptance checks for a later implementation

- The picker starts on Mango with Noctalia running and Matugen absent.
- Opening/closing the overlay works, keyboard focus returns correctly, and the
  transparent background is not unexpectedly blurred.
- Selecting a static image updates all intended monitors through Noctalia and
  survives logout/login.
- Exactly one wallpaper owner has a background-layer surface.
- `~/.cache/current_wallpaper_source` and `~/.cache/current_wallpaper` point to the
  expected files.
- Noctalia's shell palette, enabled app templates, Mango colors, and
  `colors/Colors.json` update once per wallpaper selection.
- Card palette generation does not modify the active wallpaper or active theme.
- A card's roles match the configured Noctalia wallpaper scheme.
- Name, newest, and color sorting still work after clearing the palette cache.
- Grayscale and corrupt images fall back cleanly.
- Paths containing spaces and quotes survive the external command substitution.
- Multi-monitor behavior is explicitly tested; Noctalia supports both all-monitor
  and connector-specific wallpaper commands, while this picker currently models
  one global `current` path.
- Animated/video behavior matches the chosen policy and is documented.

## Risks and open decisions

1. **Noctalia versioning:** this assessment targets the current v5 CLI. Legacy v4
   uses different Quickshell IPC commands and should be treated as a separate
   adapter, not hidden compatibility.
2. **Multi-monitor semantics:** the picker assumes one current wallpaper, while
   Noctalia supports per-monitor paths. The initial integration should deliberately
   set all monitors or extend the picker model; it should not ambiguously mix both.
3. **Palette scheme drift:** Noctalia supports multiple Material and custom
   generators. Hardcoding a scanner scheme while users change Noctalia's scheme
   will make previews inaccurate.
4. **Cache migration:** provider/scheme/version must be part of cache invalidation.
5. **Startup replay:** `WallpaperEngine` reruns external commands for the prior
   symlink target at startup. Noctalia already persists its wallpaper, so this is
   redundant and could cause an unnecessary transition/theme regeneration.
6. **Performance:** the current scanner launches three palette generators in
   parallel. The Noctalia CLI loads and resizes each image per invocation; its
   behavior should be benchmarked before retaining the same worker count.
7. **Fallback behavior:** absence of Noctalia should be reported once and should
   not poison the cache permanently as if every image were corrupt.

## External references consulted

- [Noctalia v5 wallpaper and theme IPC](https://docs.noctalia.dev/noctalia/ipc/media-and-ui/)
- [Noctalia v5 theme sources and wallpaper schemes](https://docs.noctalia.dev/noctalia/theming/)
- [Noctalia app/user templates](https://docs.noctalia.dev/noctalia/theming/app-theming/)
- [Noctalia template syntax and CLI](https://docs.noctalia.dev/noctalia/theming/templates/)
- [Noctalia Mango compositor setup](https://docs.noctalia.dev/noctalia/compositor-settings/mango/)
- [Noctalia Mango template](https://docs.noctalia.dev/noctalia/templates/official/mango/)
- [Noctalia official video-wallpaper plugin](https://docs.noctalia.dev/noctalia/plugins/official-plugins/)
- [Noctalia v5 repository and supported compositors](https://github.com/noctalia-dev/noctalia)
- [MangoWC repository](https://github.com/israellevin/mangowc)

These upstream interfaces are time-sensitive. The exact CLI and template schema
should be rechecked against the installed Noctalia release when implementation
begins.
