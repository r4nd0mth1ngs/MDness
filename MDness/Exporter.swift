import AppKit
import UniformTypeIdentifiers
import WebKit

@MainActor
enum Exporter {
    static func exportHTML(markdown: String, title: String) {
        runSavePanel(type: .html, suggestedName: title) { url in
            let html = MarkdownRenderer.page(for: markdown, title: title)
            do {
                try html.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                presentError(error)
            }
        }
    }

    static func exportPDF(markdown: String, title: String, baseURL: URL?) {
        runSavePanel(type: .pdf, suggestedName: title) { url in
            let html = MarkdownRenderer.page(for: markdown, title: title, baseURL: baseURL)
            PDFRenderer.render(html: html, to: url) { error in
                if let error {
                    presentError(error)
                }
            }
        }
    }

    private static func runSavePanel(
        type: UTType,
        suggestedName: String,
        completion: @escaping @MainActor (URL) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    private static func presentError(_ error: Error) {
        NSAlert(error: error).runModal()
    }
}

/// Renders HTML in an offscreen web view and runs a windowless print operation
/// with a save-to-file job, producing a properly paginated PDF.
@MainActor
final class PDFRenderer: NSObject, WKNavigationDelegate {
    private static var active = Set<PDFRenderer>()

    private let webView: WKWebView
    private let window: NSWindow
    private let destination: URL
    private let completion: @MainActor (Error?) -> Void
    private let tempFile: URL

    static func render(html: String, to destination: URL, completion: @escaping @MainActor (Error?) -> Void) {
        let renderer = PDFRenderer(destination: destination, completion: completion)
        active.insert(renderer)
        renderer.start(html: html)
    }

    private init(destination: URL, completion: @escaping @MainActor (Error?) -> Void) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        let frame = NSRect(origin: .zero, size: NSPrintInfo().paperSize)
        webView = WKWebView(frame: frame, configuration: configuration)
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        self.destination = destination
        self.completion = completion
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("MDnessExport-\(UUID().uuidString).html")
        super.init()
        webView.navigationDelegate = self
    }

    private func start(html: String) {
        do {
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            finish(with: error)
            return
        }
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give WebKit a beat to finish layout and image decoding before printing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.printToPDF()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(with: error)
    }

    private func printToPDF() {
        let printInfo = NSPrintInfo()
        printInfo.jobDisposition = .save
        printInfo.dictionary().setValue(destination, forKey: NSPrintInfo.AttributeKey.jobSavingURL.rawValue)
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 40
        printInfo.bottomMargin = 40
        printInfo.leftMargin = 40
        printInfo.rightMargin = 40
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        // WKWebView's print view starts with a zero frame; without one the PDF is blank.
        operation.view?.frame = NSRect(origin: .zero, size: printInfo.paperSize)
        operation.runModal(
            for: window,
            delegate: self,
            didRun: #selector(printOperation(_:didRun:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func printOperation(_ operation: NSPrintOperation, didRun success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        // NSPrintOperation can deliver this on a background thread.
        DispatchQueue.main.async {
            self.finish(with: success ? nil : PDFExportError())
        }
    }

    private func finish(with error: Error?) {
        try? FileManager.default.removeItem(at: tempFile)
        completion(error)
        Self.active.remove(self)
    }
}

struct PDFExportError: LocalizedError {
    var errorDescription: String? { "The PDF could not be created." }
}
