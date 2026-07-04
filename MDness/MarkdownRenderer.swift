import Foundation
import Markdown

/// Single rendering pipeline: Markdown → standalone HTML page. The formatted
/// view, the HTML export, and the PDF export all consume this same output.
enum MarkdownRenderer {
    /// Converts Markdown to an HTML fragment (GitHub-flavored: tables,
    /// strikethrough, task lists) using Apple's swift-markdown.
    static func htmlBody(from markdown: String) -> String {
        HTMLFormatter.format(Document(parsing: markdown))
    }

    /// Wraps the rendered fragment in a complete, self-contained HTML page.
    /// `baseURL` (the document's folder) makes relative image paths resolve.
    static func page(for markdown: String, title: String, baseURL: URL? = nil) -> String {
        let base = baseURL.map { "<base href=\"\($0.absoluteString)\">" } ?? ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(base)
        <title>\(escape(title))</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <article>
        \(htmlBody(from: markdown))
        </article>
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let css = """
    :root { color-scheme: light dark; }
    body { font: 15px/1.6 -apple-system, system-ui, sans-serif; margin: 0; }
    article { max-width: 46rem; margin: 0 auto; padding: 2.5rem 1.5rem 4rem; }
    h1, h2 { border-bottom: 1px solid rgba(128, 128, 128, 0.3); padding-bottom: 0.3em; }
    a { color: rgb(9, 105, 218); }
    @media (prefers-color-scheme: dark) { a { color: rgb(82, 156, 255); } }
    code, pre { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.88em; }
    code { background: rgba(128, 128, 128, 0.16); border-radius: 4px; padding: 0.15em 0.35em; }
    pre { background: rgba(128, 128, 128, 0.12); border-radius: 8px; padding: 0.9em 1.1em; overflow-x: auto; line-height: 1.45; }
    pre code { background: none; padding: 0; }
    blockquote { margin: 0 0 1em; padding: 0 1em; border-left: 3px solid rgba(128, 128, 128, 0.4); color: rgb(110, 119, 129); }
    @media (prefers-color-scheme: dark) { blockquote { color: rgb(139, 148, 158); } }
    table { border-collapse: collapse; margin-bottom: 1em; display: block; overflow-x: auto; }
    th, td { border: 1px solid rgba(128, 128, 128, 0.35); padding: 0.35em 0.7em; }
    th { background: rgba(128, 128, 128, 0.12); }
    img { max-width: 100%; }
    hr { border: none; border-top: 1px solid rgba(128, 128, 128, 0.3); margin: 2em 0; }
    li > p { margin: 0.25em 0; }
    li:has(> input[type="checkbox"]) { list-style: none; margin-left: -1.3em; }
    li > input[type="checkbox"] { margin-right: 0.4em; }
    li > input[type="checkbox"] + p { display: inline; }
    @media print {
        :root { color-scheme: light; }
        article { max-width: none; padding: 0; }
        pre { white-space: pre-wrap; }
        a { color: inherit; }
    }
    """
}
