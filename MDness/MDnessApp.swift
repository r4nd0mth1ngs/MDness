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
    /// Hidden automation hook: launching with MDNESS_EXPORT_PDF_INPUT/_OUTPUT set
    /// renders a PDF headlessly and exits. Used for end-to-end testing of the
    /// export pipeline. Environment variables rather than CLI arguments, because
    /// AppKit tries to open unrecognized arguments as documents and blocks on a
    /// modal error alert.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Restore the global hotkey silently; if Accessibility permission was
        // revoked the user can re-enable it from Settings.
        if UserDefaults.standard.bool(forKey: "globalHotkeyEnabled") {
            HotkeyManager.shared.enable()
        }

        let environment = ProcessInfo.processInfo.environment
        guard let inputPath = environment["MDNESS_EXPORT_PDF_INPUT"],
              let outputPath = environment["MDNESS_EXPORT_PDF_OUTPUT"] else { return }

        let input = URL(fileURLWithPath: inputPath)
        let output = URL(fileURLWithPath: outputPath)
        let markdown = (try? String(contentsOf: input, encoding: .utf8)) ?? ""
        let html = MarkdownRenderer.page(
            for: markdown,
            title: input.deletingPathExtension().lastPathComponent,
            baseURL: input.deletingLastPathComponent()
        )
        PDFRenderer.render(html: html, to: output) { error in
            exit(error == nil ? 0 : 1)
        }
    }
}
