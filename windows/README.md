# MDness for Windows (Tauri + WebView2)

A native Windows build of MDness. Like the Linux app it is a thin native shell
around the shared `web/` rendering pipeline (markdown-it + Mermaid) — here the
shell is [Tauri](https://tauri.app) v2 and the WebView is **WebView2** (the Edge
runtime, preinstalled on Windows 10 21H2+ and Windows 11). No Electron, no
bundled browser.

The `web/` assets are reused byte-for-byte: `src-tauri/build.rs` copies
`app.js`, `markdown-it.min.js`, `mermaid.min.js` and `mdness.css` into
`ui/vendor/` at build time, so nothing is duplicated in git.

## Prerequisites

- **Rust** (stable): https://rustup.rs
- **Tauri CLI**: `cargo install tauri-cli --version "^2"`
- **WebView2 runtime** — already present on Win10 21H2+/Win11. On older builds:
  https://developer.microsoft.com/microsoft-edge/webview2/
- Microsoft C++ Build Tools (installed with the "Desktop development with C++"
  workload) for linking.

## Build / run

From the `windows/` directory:

```powershell
# One-time: generate app + installer icons from the shared PNG.
cargo tauri icon ..\linux\mdness.png       # writes src-tauri/icons/

cargo tauri dev                            # run in a dev window
cargo tauri build                          # produce installers
```

Installers land in `src-tauri/target/release/bundle/` (`nsis/*-setup.exe` and
`msi/*.msi`).

## What works

- New / Open / Save / Save As, with `Ctrl+N/O/S`, `Ctrl+Shift+S`.
- Raw ⇄ Formatted toggle (`Ctrl+Shift+P`), live preview with 250 ms debounce.
- GitHub-flavored rendering + Mermaid diagrams (the shared pipeline).
- **Export as HTML…** — self-contained static page, identical shape to the other
  platforms (inlined CSS, baked-in SVG diagrams, no scripts).
- **Export as PDF…** — routes through WebView2's print dialog; choose
  "Microsoft Print to PDF" / "Save as PDF".

## Known gaps vs. macOS/Linux (v1)

- **PDF export is not silent** — it opens the print dialog rather than writing
  the file directly. Wire WebView2 `PrintToPdfAsync` via a Rust command to match.
- **Relative image paths** in the preview don't resolve yet (Tauri asset-protocol
  scoping). HTML/PDF export of absolute paths is unaffected.
- **No global summon hotkey** or file-association / CLI-open. Add via
  `tauri-plugin-global-shortcut` and the Tauri CLI-args plugin if wanted.

Tauri is cross-platform, so this same shell also builds on macOS/Linux — but the
native SwiftUI and GTK shells remain the primary apps there.
