import AppKit
import UniformTypeIdentifiers
import WebKit

@MainActor
enum Exporter {
    static func exportHTML(markdown: String, title: String, baseURL: URL?) {
        runSavePanel(type: .html, suggestedName: title) { url in
            let host = MarkdownRenderer.hostHTML(markdown: markdown, title: title, baseURL: baseURL)
            WebExporter.export(hostHTML: host, job: .html(url, title: title)) { error in
                if let error { presentError(error) }
            }
        }
    }

    static func exportPDF(markdown: String, title: String, baseURL: URL?) {
        runSavePanel(type: .pdf, suggestedName: title) { url in
            let host = MarkdownRenderer.hostHTML(markdown: markdown, title: title, baseURL: baseURL)
            WebExporter.export(hostHTML: host, job: .pdf(url)) { error in
                if let error { presentError(error) }
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

/// Renders the host page in an offscreen web view, waits for markdown-it and
/// Mermaid to finish (polling the `__mdnessRenderComplete` flag app.js sets),
/// then either prints a paginated PDF or captures the rendered DOM as a
/// self-contained static HTML file.
@MainActor
final class WebExporter: NSObject, WKNavigationDelegate {
    enum Job {
        case pdf(URL)
        case html(URL, title: String)
    }

    private static var active = Set<WebExporter>()

    private let webView: WKWebView
    private let window: NSWindow
    private let job: Job
    private let completion: @MainActor (Error?) -> Void
    private let tempFile: URL
    private var pollCount = 0
    private let maxPolls = 300 // ~15s at 50ms; Mermaid's first init can be slow.

    static func export(hostHTML: String, job: Job, completion: @escaping @MainActor (Error?) -> Void) {
        let exporter = WebExporter(job: job, completion: completion)
        active.insert(exporter)
        exporter.start(hostHTML: hostHTML)
    }

    private init(job: Job, completion: @escaping @MainActor (Error?) -> Void) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()
        let frame = NSRect(origin: .zero, size: NSPrintInfo().paperSize)
        webView = WKWebView(frame: frame, configuration: configuration)
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        self.job = job
        self.completion = completion
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("MDnessExport-\(UUID().uuidString).html")
        super.init()
        webView.navigationDelegate = self
    }

    private func start(hostHTML: String) {
        do {
            try hostHTML.write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            finish(with: error)
            return
        }
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pollForRenderComplete()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(with: error)
    }

    private func pollForRenderComplete() {
        webView.evaluateJavaScript("window.__mdnessRenderComplete === true") { [weak self] result, _ in
            guard let self else { return }
            if (result as? Bool) == true {
                self.performJob()
            } else if self.pollCount >= self.maxPolls {
                self.performJob() // Proceed anyway rather than hang forever.
            } else {
                self.pollCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.pollForRenderComplete()
                }
            }
        }
    }

    private func performJob() {
        switch job {
        case .pdf(let url):
            printToPDF(destination: url)
        case .html(let url, let title):
            captureHTML(destination: url, title: title)
        }
    }

    private func captureHTML(destination: URL, title: String) {
        webView.evaluateJavaScript("document.getElementById('content').outerHTML") { [weak self] result, error in
            guard let self else { return }
            guard let content = result as? String else {
                self.finish(with: error ?? ExportError())
                return
            }
            let page = MarkdownRenderer.exportPage(contentHTML: content, title: title)
            do {
                try page.write(to: destination, atomically: true, encoding: .utf8)
                self.finish(with: nil)
            } catch {
                self.finish(with: error)
            }
        }
    }

    private func printToPDF(destination: URL) {
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
            self.finish(with: success ? nil : ExportError())
        }
    }

    private func finish(with error: Error?) {
        try? FileManager.default.removeItem(at: tempFile)
        completion(error)
        Self.active.remove(self)
    }
}

struct ExportError: LocalizedError {
    var errorDescription: String? { "The document could not be exported." }
}
