# MDness

A minimal, native macOS (Apple Silicon) Markdown viewer/editor. SwiftUI + WebKit,
no Electron, no configuration. Built on the YAGNI principle: one rendering
pipeline (Markdown → HTML → WKWebView) powers the formatted view, the HTML
export, and the PDF export.

## Features

- **File operations for free** — New, Open, Save, Save As, Rename, autosave and
  Recent Documents via the native document architecture (`DocumentGroup`).
- **Raw ⇄ Formatted toggle** — segmented control in the toolbar, or **⇧⌘P**.
  Existing documents open in the formatted view; new documents open in the editor.
- **GitHub-flavored rendering** — tables, strikethrough and task lists via
  Apple's [swift-markdown](https://github.com/swiftlang/swift-markdown).
  Relative image paths resolve against the document's folder.
- **Export** — File → *Export as HTML…* (self-contained page, light/dark aware)
  and *Export as PDF…* (paginated). Also available from the toolbar share menu.
- **Global hotkey** — summon MDness from anywhere with **fn + Space**. Enable it
  in MDness → Settings…; macOS will ask once for Accessibility access (required
  to listen for the key system-wide). Pair it with "Start MDness at login" so
  the shortcut always works.
- Dark mode supported throughout; smart quotes disabled in the editor so
  Markdown syntax stays intact.

## Install

Download the DMG from the [latest release](https://github.com/r4nd0mth1ngs/MDness/releases),
open it, and drag MDness into Applications. The app is ad-hoc signed (not
notarized), so on first launch right-click the app and choose **Open**.

## Build

```sh
xcodebuild -project MDness.xcodeproj -scheme MDness -configuration Release build
```

or open `MDness.xcodeproj` in Xcode and hit Run. Requires Xcode 16+ and
macOS 14+. `scripts/make-dmg.sh` builds the installer DMG into `dist/`;
`scripts/make-icon.sh` regenerates the app icon.

## License

MIT © 2026 David Feher — see [LICENSE](LICENSE).
