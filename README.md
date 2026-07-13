# MDness

A minimal, native Markdown viewer/editor for **macOS, Linux and Windows**. No
Electron, no configuration. Built on the YAGNI principle: a single rendering
pipeline (Markdown → HTML → WebView) powers the formatted view, the HTML export
and the PDF export — and it is shared byte-for-byte across every platform.

- **macOS** — SwiftUI + WKWebView (Apple Silicon + Intel universal).
- **Linux** — one ~500-line Python file on GTK4 + WebKitGTK. No bundled runtime;
  depends only on system libraries. Targets Ubuntu 24.04+ and Arch.
- **Windows** — a thin [Tauri](https://tauri.app) v2 shell over WebView2 (the
  preinstalled Edge runtime). No bundled browser. See [`windows/`](windows/).

All share the same web assets (`web/`): [markdown-it](https://github.com/markdown-it/markdown-it)
for GitHub-flavored rendering and [Mermaid](https://mermaid.js.org/) for diagrams.

## Features

- **File operations** — New, Open, Save, Save As (plus Rename, autosave and
  Recent Documents on macOS via `DocumentGroup`).
- **Raw ⇄ Formatted toggle** — segmented control in the toolbar, or **⇧⌘P** /
  **Ctrl+Shift+P**.
- **GitHub-flavored rendering** — tables, strikethrough, task lists, autolinks.
  Relative image paths resolve against the document's folder.
- **Mermaid diagrams** — fenced ```` ```mermaid ```` blocks render as diagrams in
  the preview and in both exports (as baked-in SVG).
- **Export** — *Export as HTML…* (self-contained static page — inlined CSS,
  diagrams as SVG, no scripts) and *Export as PDF…* (paginated).
- **Global shortcut** — summon MDness from anywhere. On macOS: **fn + Space**
  (enable in Settings…; needs Accessibility access). On Linux: bind a shortcut
  to `mdness --summon` (helper: `mdness --install-shortcut`, see below).
- Dark mode aware throughout.

## Install

### macOS

Download the DMG from the [latest release](https://github.com/r4nd0mth1ngs/MDness/releases),
open it, and drag MDness into Applications. The app is ad-hoc signed (not
notarized), so on first launch right-click the app and choose **Open**.

### Linux (Ubuntu / Arch)

```sh
git clone https://github.com/r4nd0mth1ngs/MDness.git
cd MDness
./linux/install.sh          # installs deps (apt/pacman) + the app under /usr/local
```

Arch users can instead build a package with the provided `linux/PKGBUILD`
(`cd linux && makepkg -si`).

Runtime dependencies (installed automatically by `install.sh`):

| Distro  | Packages                                            |
| ------- | --------------------------------------------------- |
| Ubuntu  | `python3-gi gir1.2-gtk-4.0 gir1.2-webkit-6.0`       |
| Arch    | `python-gobject gtk4 webkitgtk-6.0`                 |

**Global shortcut on Linux.** Wayland (and good X11 practice) leaves global
hotkeys to the desktop, so MDness is single-instance and raises its window on
`mdness --summon`. On GNOME, run `mdness --install-shortcut` to bind it (default
`Ctrl+Alt+Space`; pass another accelerator as an argument). On KDE/others, add a
custom shortcut that runs `mdness --summon` in your keyboard settings. (There is
no portable "fn+Space" on Linux — `fn` is a hardware key the compositor doesn't
see.)

### Windows

Requires the WebView2 runtime (preinstalled on Win10 21H2+/Win11). Build from
source with the Tauri toolchain — see [`windows/README.md`](windows/README.md).
Installers (`.exe` / `.msi`) land in `windows/src-tauri/target/release/bundle/`.

## Build (macOS)

```sh
xcodebuild -project MDness.xcodeproj -scheme MDness -configuration Release build
```

or open `MDness.xcodeproj` in Xcode and hit Run. Requires Xcode 16+ and
macOS 14+. `scripts/make-dmg.sh` builds the installer DMG into `dist/`;
`scripts/make-icon.sh` regenerates the app icon.

## Repository layout

```
web/            Shared rendering assets (markdown-it, mermaid, CSS, glue) — used by every app
MDness/         macOS SwiftUI sources
linux/          Linux app (single-file Python), packaging, icon
windows/        Windows app (Tauri v2 + WebView2): src-tauri/ (Rust) + ui/ (shell)
scripts/        macOS DMG + icon build scripts
```

## License

MIT © 2026 David Feher — see [LICENSE](LICENSE).
