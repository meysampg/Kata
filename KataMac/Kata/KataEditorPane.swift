import AppKit
import KataCore
import KataEditor
import KataRun
import KataStore
import KataUI
import SwiftUI

/// File tabs, the editor (with an optional read-only twin beside it) and the status line.
struct KataEditorPane: View {
  @Bindable var session: KataSessionModel
  @Environment(MacAppModel.self) private var model
  @Environment(AppSettings.self) private var settings
  @Environment(\.colorScheme) private var scheme
  @State private var position = EditorPosition(line: 1, column: 1)
  @State private var isAddingFile = false
  @State private var newFileName = ""
  @State private var addFileError: String?
  @State private var asideFile: String?

  var body: some View {
    VStack(spacing: 0) {
      tabBar
      Divider()
      if session.mode == .ide { ideBanner }
      if session.aside == .revealed { revealedBanner }
      HStack(spacing: 0) {
        editor
        if session.aside != .none {
          Divider()
          asidePanel
        }
      }
      Divider()
      statusBar
    }
    .background(Color(nsColor: .textBackgroundColor))
  }

  private var theme: CodeTheme { .theme(for: scheme) }
  private var fontSize: CGFloat { CGFloat(model.macSettings.editorFontSize) }

  // MARK: Tabs

  private var tabBar: some View {
    HStack(spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 2) {
          ForEach(session.fileNames, id: \.self) { name in tab(name) }
        }
        .padding(.horizontal, 6)
      }
      if session.canAddFiles, session.mode == .builtIn {
        Button { newFileName = ""; addFileError = nil; isAddingFile = true } label: { Image(systemName: "plus") }
          .buttonStyle(.borderless)
          .help("Add a Java file")
          .popover(isPresented: $isAddingFile, arrowEdge: .bottom) { addFilePopover }
      }
      Spacer(minLength: 0)
      modePicker
    }
    .padding(.vertical, 6).padding(.trailing, 8)
    .background(.bar)
  }

  private func tab(_ name: String) -> some View {
    let selected = name == session.selectedFile
    return Button { session.selectedFile = name } label: {
      HStack(spacing: 5) {
        if session.isReadOnly(name) { Image(systemName: "lock.fill").font(.caption2) }
        Text(name).font(.subheadline.weight(selected ? .semibold : .regular))
        if !session.diagnostics(for: name).filter({ $0.severity == .error }).isEmpty {
          Circle().fill(.red).frame(width: 6, height: 6)
        }
      }
      .foregroundStyle(session.isReadOnly(name) ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
      .padding(.horizontal, 10).padding(.vertical, 4)
      .background(selected ? Color.primary.opacity(0.10) : .clear, in: .rect(cornerRadius: 7))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .contextMenu {
      if !session.kata.starter.contains(where: { $0.name == name }), session.mode == .builtIn {
        Button("Delete \(name)", role: .destructive) { session.removeFile(name) }
      }
    }
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var addFilePopover: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("New Java file").font(.headline)
      TextField("Discounts.java", text: $newFileName)
        .textFieldStyle(.roundedBorder).frame(width: 220)
        .onSubmit(addFile)
      if let addFileError { Text(addFileError).font(.caption).foregroundStyle(.red) }
      HStack {
        Spacer()
        Button("Add", action: addFile).keyboardShortcut(.defaultAction)
      }
    }
    .padding(14)
  }

  private func addFile() {
    if let error = session.addFile(named: newFileName) { addFileError = error } else { isAddingFile = false }
  }

  private var modePicker: some View {
    HStack(spacing: 6) {
      Text("Editing").font(.caption).foregroundStyle(.secondary)
      Picker("Editing", selection: Binding(get: { session.mode }, set: setMode)) {
        Text("Built-in").tag(KataSessionModel.EditMode.builtIn)
        Text("IDE").tag(KataSessionModel.EditMode.ide)
      }
      .pickerStyle(.segmented).labelsHidden().frame(width: 130)
      .help("Edit here, or in your IDE with checks re-run on save")
    }
  }

  private func setMode(_ new: KataSessionModel.EditMode) {
    switch new {
    case .builtIn:
      session.leaveIDEMode()
    case .ide:
      guard session.mode != .ide else { return }
      openInIDE(model.selectedIDE())
    }
  }

  private func openInIDE(_ ide: IDE?) {
    guard let ide else {
      session.reportIDEUnavailable()
      return
    }
    Task { await session.startIDEMode(ide: ide) }
  }

  // MARK: Banners

  private var ideBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.up.forward.app").foregroundStyle(.tint)
      Text("Editing in \(session.ide?.name ?? "your IDE") \u{00B7} watching for saves")
        .font(.subheadline)
      Spacer(minLength: 8)
      Button("Reveal workspace") { NSWorkspace.shared.activateFileViewerSelecting([session.workspaceDirectory]) }
      if let ide = session.ide {
        Button("Open again") { Task { await session.startIDEMode(ide: ide) } }
      }
      Button("Back to built-in editor") { session.leaveIDEMode() }
        .buttonStyle(.borderedProminent)
    }
    .controlSize(.small)
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(Color.accentColor.opacity(0.10))
  }

  private var revealedBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "eye").foregroundStyle(.orange)
      Text("Solution revealed. The suggested rating is Again.").font(.subheadline)
      Spacer(minLength: 8)
      Button("Copy into editor") { session.requestCopySolution() }
      Button("Close") { session.aside = .none }
    }
    .controlSize(.small)
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(Color.orange.opacity(0.12))
  }

  // MARK: Editor

  @ViewBuilder
  private var editor: some View {
    let file = session.selectedFile
    if file.isEmpty {
      ContentUnavailableView("No files", systemImage: "doc")
    } else {
      CodeEditorView(
        text: Binding(get: { session.files[file] ?? "" }, set: { session.setSource($0, for: file) }),
        isEditable: session.isEditable(file), fontSize: fontSize, showsLineNumbers: settings.showLineNumbers,
        theme: theme, diagnostics: session.diagnostics(for: file), reveal: session.reveal,
        autoFocus: session.isEditable(file),
        onSelectionChange: { position = $0 },
        onFontStep: { stepFont($0) }
      )
      .id("\(file)#\(session.mode.rawValue)")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel("Code editor, \(file)")
    }
  }

  private func stepFont(_ delta: Int) {
    model.macSettings.editorFontSize += delta
  }

  // MARK: Aside

  private var asideTitle: String {
    switch session.aside {
    case .reference: "Reference solution"
    case .previous: "Your previous solution"
    case .revealed: "Solution"
    case .none: ""
    }
  }

  private var asidePanel: some View {
    let files = session.asideFiles
    let current = files.first { $0.name == asideFile } ?? files.first { $0.name == session.selectedFile } ?? files.first
    return VStack(spacing: 0) {
      HStack(spacing: 6) {
        Text(asideTitle).font(.subheadline.weight(.semibold))
        Text("read-only").font(.caption).foregroundStyle(.secondary)
        Spacer()
        if files.count > 1 {
          Picker("File", selection: Binding(get: { current?.name ?? "" }, set: { asideFile = $0 })) {
            ForEach(files, id: \.name) { Text($0.name).tag($0.name) }
          }
          .labelsHidden().frame(width: 150)
        }
        Button { session.aside = .none } label: { Image(systemName: "xmark") }
          .buttonStyle(.borderless).help("Close")
      }
      .padding(.horizontal, 10).padding(.vertical, 6)
      .background(.bar)
      Divider()
      if let current {
        CodeEditorView(
          text: .constant(current.source), isEditable: false, fontSize: fontSize,
          showsLineNumbers: settings.showLineNumbers, theme: theme)
          .id("\(session.aside)#\(current.name)")
      } else {
        ContentUnavailableView("Nothing to show", systemImage: "doc")
      }
    }
    .frame(minWidth: 260, idealWidth: 380, maxWidth: .infinity)
    .frame(maxHeight: .infinity)
  }

  // MARK: Status

  private var statusBar: some View {
    HStack(spacing: 14) {
      Text("Ln \(position.line), Col \(position.column)").monospacedDigit()
      Text("Java")
      Text("4 spaces")
      if !session.isEditable(session.selectedFile) {
        Label(session.mode == .ide ? "Mirror of the IDE" : "Read-only", systemImage: "lock").labelStyle(.titleAndIcon)
      }
      Spacer()
      Text("\(Int(fontSize)) pt")
    }
    .font(.caption).foregroundStyle(.secondary)
    .padding(.horizontal, 12).padding(.vertical, 4)
    .background(.bar)
  }
}
