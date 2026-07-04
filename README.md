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
- Dark mode supported throughout; smart quotes disabled in the editor so
  Markdown syntax stays intact.

## Build

```sh
xcodebuild -project MDness.xcodeproj -scheme MDness -configuration Release build
```

or open `MDness.xcodeproj` in Xcode and hit Run. Requires Xcode 16+ and
macOS 14+.
