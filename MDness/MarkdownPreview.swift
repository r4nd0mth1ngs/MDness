import SwiftUI
import WebKit

/// The formatted view. The rendered page is written to a temp file and loaded
/// with `loadFileURL` (rather than `loadHTMLString`) so WKWebView is allowed to
/// read local images referenced by the document, resolved via the page's
/// `<base>` tag against the document's folder.
struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    let fileURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        // Local content only — nothing to persist, and a persistent store left
        // locked by a crashed instance can hang all subsequent page loads.
        configuration.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: configuration)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = MarkdownRenderer.page(
            for: markdown,
            title: fileURL?.lastPathComponent ?? "Preview",
            baseURL: fileURL?.deletingLastPathComponent()
        )
        context.coordinator.load(html, into: webView)
    }

    final class Coordinator {
        private var lastHTML = ""
        private var currentFile: URL?
        private var previousFile: URL?

        func load(_ html: String, into webView: WKWebView) {
            guard html != lastHTML else { return }
            lastHTML = html

            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("MDnessPreview-\(UUID().uuidString).html")
            do {
                try html.write(to: file, atomically: true, encoding: .utf8)
            } catch {
                webView.loadHTMLString(html, baseURL: nil)
                return
            }
            // Keep the file backing the in-flight load; delete the one before it.
            if let previousFile {
                try? FileManager.default.removeItem(at: previousFile)
            }
            previousFile = currentFile
            currentFile = file
            webView.loadFileURL(file, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }

        deinit {
            for file in [currentFile, previousFile].compactMap({ $0 }) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
