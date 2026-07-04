import Foundation

/// Builds the HTML that the WebKit view renders. Markdown → HTML and Mermaid
/// diagrams are produced in-page by the shared web assets (markdown-it +
/// mermaid); this type just assembles the host page and, for export, the
/// self-contained static output. The same pipeline backs the preview, the HTML
/// export and the PDF export — and is byte-identical to the Linux app's.
enum MarkdownRenderer {
    /// Folder inside the app bundle holding the shared web assets (index.html,
    /// mdness.css, markdown-it.min.js, mermaid.min.js, app.js).
    static var assetsURL: URL {
        Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)
    }

    /// Host page for the preview and the export renderers: the Markdown source
    /// is baked into `#md-source` and rendered on load. `baseURL` (the
    /// document's folder) lets relative image paths resolve.
    static func hostHTML(markdown: String, title: String, baseURL: URL?) -> String {
        let template = (try? String(contentsOf: assetsURL.appendingPathComponent("index.html"), encoding: .utf8)) ?? ""
        let assets = assetsURL.absoluteString
        let assetsPath = assets.hasSuffix("/") ? String(assets.dropLast()) : assets
        let base = baseURL.map { "<base href=\"\($0.absoluteString)\">" } ?? ""
        return template
            .replacingOccurrences(of: "{{BASE}}", with: base)
            .replacingOccurrences(of: "{{TITLE}}", with: escape(title))
            .replacingOccurrences(of: "{{ASSETS}}", with: assetsPath)
            .replacingOccurrences(of: "{{SOURCE}}", with: jsonSource(markdown))
    }

    /// Wraps already-rendered article HTML (captured from the web view, so
    /// Mermaid diagrams are baked-in SVGs) into a self-contained, static page
    /// with inlined CSS — no scripts, opens anywhere.
    static func exportPage(contentHTML: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        \(cssText)
        </style>
        </head>
        <body>
        \(contentHTML)
        </body>
        </html>
        """
    }

    static var cssText: String {
        (try? String(contentsOf: assetsURL.appendingPathComponent("mdness.css"), encoding: .utf8)) ?? ""
    }

    /// JSON-encodes the Markdown for embedding in a `<script>` element, escaping
    /// `<` so a literal `</script>` in the source can't close the tag early.
    private static func jsonSource(_ markdown: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: markdown, options: [.fragmentsAllowed])) ?? Data("\"\"".utf8)
        let json = String(data: data, encoding: .utf8) ?? "\"\""
        return json.replacingOccurrences(of: "<", with: "\\u003c")
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
