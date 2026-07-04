import SwiftUI
import AppKit

@main
struct MDnessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Smart quotes/dashes silently corrupt Markdown syntax in the raw editor.
        UserDefaults.standard.register(defaults: [
            "NSAutomaticQuoteSubstitutionEnabled": false,
            "NSAutomaticDashSubstitutionEnabled": false,
            "NSAutomaticTextReplacementEnabled": false,
        ])
    }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Divider()
                ExportCommands()
            }
            CommandGroup(after: .toolbar) {
                PreviewToggleCommand()
                Divider()
            }
        }

        Settings {
            SettingsView()
        }
    }
}

/// File > Export as HTML… / Export as PDF…, wired to the focused document window.
private struct ExportCommands: View {
    @FocusedValue(\.exportActions) private var actions

    var body: some View {
        Button("Export as HTML…") { actions?.html() }
            .disabled(actions == nil)
        Button("Export as PDF…") { actions?.pdf() }
            .disabled(actions == nil)
    }
}

/// View > toggle between raw Markdown and the formatted view (⇧⌘P).
private struct PreviewToggleCommand: View {
    @FocusedBinding(\.isPreviewing) private var isPreviewing

    var body: some View {
        Button(isPreviewing == true ? "Show Raw Markdown" : "Show Formatted View") {
            isPreviewing?.toggle()
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(isPreviewing == nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Hidden automation hook: launching with MDNESS_EXPORT_PDF_INPUT set (plus
    /// MDNESS_EXPORT_PDF_OUTPUT and/or MDNESS_EXPORT_HTML_OUTPUT) renders
    /// headlessly and exits. Used for end-to-end testing of the export pipeline.
    /// Environment variables rather than CLI arguments, because AppKit tries to
    /// open unrecognized arguments as documents and blocks on a modal alert.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore the global hotkey silently; if Accessibility permission was
        // revoked the user can re-enable it from Settings.
        if UserDefaults.standard.bool(forKey: "globalHotkeyEnabled") {
            HotkeyManager.shared.enable()
        }

        let environment = ProcessInfo.processInfo.environment
        guard let inputPath = environment["MDNESS_EXPORT_PDF_INPUT"] else { return }

        let input = URL(fileURLWithPath: inputPath)
        let title = input.deletingPathExtension().lastPathComponent
        let markdown = (try? String(contentsOf: input, encoding: .utf8)) ?? ""
        let host = MarkdownRenderer.hostHTML(
            markdown: markdown,
            title: title,
            baseURL: input.deletingLastPathComponent()
        )

        var jobs: [WebExporter.Job] = []
        if let pdf = environment["MDNESS_EXPORT_PDF_OUTPUT"] {
            jobs.append(.pdf(URL(fileURLWithPath: pdf)))
        }
        if let htmlPath = environment["MDNESS_EXPORT_HTML_OUTPUT"] {
            jobs.append(.html(URL(fileURLWithPath: htmlPath), title: title))
        }
        guard !jobs.isEmpty else { exit(2) }
        runJobs(jobs, hostHTML: host, failed: false)
    }

    /// Runs the export jobs sequentially (a single offscreen renderer at a time)
    /// and exits non-zero if any failed.
    @MainActor
    private func runJobs(_ jobs: [WebExporter.Job], hostHTML: String, failed: Bool) {
        guard let job = jobs.first else {
            exit(failed ? 1 : 0)
        }
        WebExporter.export(hostHTML: hostHTML, job: job) { [weak self] error in
            self?.runJobs(Array(jobs.dropFirst()), hostHTML: hostHTML, failed: failed || error != nil)
        }
    }
}
