import SwiftUI

struct ScriptEditorView: View {
    @Bindable var app: AppCoordinator
    @FocusState private var editing: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("SCRIPT STUDIO", systemImage: "doc.text").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Button { app.draft.isPinned.toggle(); app.edited() } label: { Image(systemName: app.draft.isPinned ? "pin.fill" : "pin") }.buttonStyle(.plain).help("Pin script")
                Menu {
                    Button("Duplicate") { app.duplicate() }
                    Button("Export…") { app.exportScript() }
                    Divider()
                    Button("Delete…", role: .destructive) { app.confirmDelete = true }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24)
            }.padding(.bottom, 24)
            TextField("Script title", text: Binding(get: { app.draft.title }, set: { app.beginEditing(); app.draft.title = $0; app.edited() }))
                .font(.system(size: 28, weight: .semibold)).textFieldStyle(.plain)
            HStack {
                Text("\(app.draft.wordCount) words")
                Text("·")
                Text("\(max(1, Int(ceil(Double(app.draft.wordCount) / Double(app.preferences.scrollSpeedWPM))))) min read")
                Spacer()
                Button { app.splitCue() } label: { Label("Add cue", systemImage: "number") }.buttonStyle(.plain).help("⌘K · Add a section heading")
            }.font(.caption).foregroundStyle(.secondary).padding(.top, 10).padding(.bottom, 22)
            TextField("Tags, separated by commas", text: Binding(get: { app.draft.tags.joined(separator: ", ") }, set: { app.beginEditing(); app.draft.tags = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }; app.edited() }))
                .font(.caption).foregroundStyle(.secondary).textFieldStyle(.plain).padding(.bottom, 16)
            Rectangle().fill(LinearGradient(colors: [DesignTokens.periwinkle, DesignTokens.violet, .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            TextEditor(text: Binding(get: { app.draft.body }, set: { app.beginEditing(); app.draft.body = $0; app.edited() }))
                .font(.system(size: 16, design: .monospaced)).lineSpacing(8).scrollContentBackground(.hidden).padding(.top, 20)
                .focused($editing)
                .onChange(of: editing) { _, focused in if focused { app.beginEditing() } }
                .accessibilityLabel("Script body; use Markdown headings to create cues")
            HStack {
                Circle().fill(app.saveStatus == "All changes saved" ? Color.green : Color.orange).frame(width: 5, height: 5)
                Text(app.saveStatus)
                Spacer()
                Text("# Heading creates a cue").foregroundStyle(.tertiary)
            }.font(.caption2).foregroundStyle(.secondary).padding(.top, 14)
        }.padding(30).background(Color(hex: "#141419"))
    }
}
