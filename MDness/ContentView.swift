import SwiftUI

struct ExportActions {
    let html: () -> Void
    let pdf: () -> Void
}

extension FocusedValues {
    @Entry var exportActions: ExportActions?
    @Entry var isPreviewing: Binding<Bool>?
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @State private var isPreviewing: Bool

    init(document: Binding<MarkdownDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        // Existing documents open straight into the formatted view; new ones into the editor.
        _isPreviewing = State(initialValue: !document.wrappedValue.text.isEmpty)
    }

    var body: some View {
        Group {
            if isPreviewing {
                MarkdownPreview(markdown: document.text, fileURL: fileURL)
            } else {
                TextEditor(text: $document.text)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $isPreviewing) {
                    Text("Raw").tag(false)
                    Text("Formatted").tag(true)
                }
                .pickerStyle(.segmented)
                .help("Switch between raw Markdown and the formatted view (⇧⌘P)")
            }
            ToolbarItem {
                Menu {
                    Button("Export as HTML…", action: exportHTML)
                    Button("Export as PDF…", action: exportPDF)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export the document")
            }
        }
        .focusedSceneValue(\.isPreviewing, $isPreviewing)
        .focusedSceneValue(\.exportActions, ExportActions(html: exportHTML, pdf: exportPDF))
    }

    private var documentTitle: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }

    private func exportHTML() {
        Exporter.exportHTML(
            markdown: document.text,
            title: documentTitle,
            baseURL: fileURL?.deletingLastPathComponent()
        )
    }

    private func exportPDF() {
        Exporter.exportPDF(
            markdown: document.text,
            title: documentTitle,
            baseURL: fileURL?.deletingLastPathComponent()
        )
    }
}
