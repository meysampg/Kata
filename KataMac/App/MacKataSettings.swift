import AppKit
import KataEditor
import KataRun
import KataStore
import KataUI
import SwiftUI

// MARK: - Editor

struct EditorSettingsView: View {
  @Environment(MacAppModel.self) private var model
  @Environment(AppSettings.self) private var settings
  @Environment(\.colorScheme) private var scheme

  private static let sample = """
    final class Checkout {
        private final DiscountPolicy policy;

        // Delegates the promotion to a strategy.
        BigDecimal total(List<BigDecimal> prices) {
            return policy.apply(sum(prices)).setScale(2);
        }
    }
    """

  var body: some View {
    @Bindable var settings = settings
    @Bindable var mac = model.macSettings
    Form {
      Section("Kata editor") {
        Stepper(value: $mac.editorFontSize, in: MacSettings.editorFontRange) {
          LabeledContent("Font size", value: "\(mac.editorFontSize) pt")
        }
        Toggle("Line numbers", isOn: $settings.showLineNumbers)
        Toggle("Re-check when an IDE saves", isOn: $mac.recheckOnSave)
      }
      Section("Preview") {
        CodeEditorView(
          text: .constant(Self.sample), isEditable: false, fontSize: CGFloat(mac.editorFontSize),
          showsLineNumbers: settings.showLineNumbers, theme: .theme(for: scheme))
          .frame(height: 150)
          .clipShape(.rect(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
          .accessibilityLabel("Editor preview")
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Java

struct JavaSettingsView: View {
  @Environment(MacAppModel.self) private var model
  @State private var result: JavaTestResult?
  @State private var testing = false

  var body: some View {
    @Bindable var mac = model.macSettings
    let toolchain = model.toolchain
    Form {
      if toolchain.isMissing {
        Section {
          NoJDKView()
        }
      } else {
        Section {
          Picker("JDK", selection: $mac.jdkHome) {
            Text(defaultLabel).tag(String?.none)
            ForEach(toolchain.installed) { jdk in
              Text("\(jdk.displayName) (\(jdk.major))").tag(String?.some(jdk.home.path))
            }
          }
          if let jdk = toolchain.currentJDK {
            LabeledContent("Using", value: jdk.home.path).textSelection(.enabled)
              .font(.footnote)
          }
        } footer: {
          Text("Katas are compiled with --release 21 on any JDK from 21 up. Unit checks run in a separate process that is stopped after the kata's time limit.")
        }
        Section {
          HStack {
            Button("Test") { runTest() }.disabled(testing || toolchain.currentJDK == nil)
            if testing { ProgressView().controlSize(.small) }
            Button("Look again") { Task { await toolchain.refresh() } }
            Spacer()
          }
          if let result {
            Label(result.summary, systemImage: result.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
              .foregroundStyle(result.ok ? .green : .red)
            if !result.detail.isEmpty {
              Text(result.detail).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
          }
        } header: {
          Text("Check the toolchain")
        } footer: {
          Text("Runs javac -version, builds the check harness and runs a tiny sample kata.")
        }
      }
    }
    .formStyle(.grouped)
    .task { if !toolchain.didSearch { await toolchain.refresh() } }
  }

  private var defaultLabel: String {
    if let d = model.toolchain.defaultJDK { return "Default (java_home -v 21+) \u{2014} \(d.displayName)" }
    return "Default (java_home -v 21+)"
  }

  private func runTest() {
    testing = true
    result = nil
    Task {
      result = await model.toolchain.test()
      testing = false
    }
  }
}

// MARK: - IDE

struct IDESettingsView: View {
  @Environment(MacAppModel.self) private var model
  @State private var confirmClean = false
  @State private var cleaned: String?

  private enum Choice: Hashable {
    case automatic
    case known(String)
    case other
  }

  var body: some View {
    @Bindable var mac = model.macSettings
    Form {
      Section {
        Picker("Open katas in", selection: Binding(get: { choice }, set: select)) {
          Text(automaticLabel).tag(Choice.automatic)
          ForEach(model.ides) { ide in Text(ide.name).tag(Choice.known(ide.bundleID)) }
          if let path = mac.ideAppPath, let custom = IDELauncher.ide(at: URL(fileURLWithPath: path)),
            !model.ides.contains(where: { $0.bundleID == custom.bundleID })
          {
            Text(custom.name).tag(Choice.known(custom.bundleID))
          }
          Text("Other\u{2026}").tag(Choice.other)
        }
        if model.ides.isEmpty {
          Text("IntelliJ IDEA, Zed and Cursor were not found. Choose another editor with Other\u{2026}, or edit in the built-in editor.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      } footer: {
        Text("The built-in editor is always available. In IDE mode, saving a file re-runs the checks and the results appear here.")
      }

      Section("Workspaces") {
        LabeledContent("Folder") {
          Text(mac.workspaceRoot.path).font(.callout).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
        }
        HStack {
          Button("Choose\u{2026}", action: chooseRoot)
          Button("Reveal in Finder") {
            let dir = mac.workspaceRoot
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([dir])
          }
          if mac.workspaceRootPath != nil { Button("Use ~/Kata") { mac.workspaceRootPath = nil } }
          Spacer()
          Button("Clean workspaces\u{2026}", role: .destructive) { confirmClean = true }
        }
        if let cleaned { Text(cleaned).font(.footnote).foregroundStyle(.secondary) }
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshIDEs() }
    .confirmationDialog("Delete the kata workspaces?", isPresented: $confirmClean, titleVisibility: .visible) {
      Button("Delete workspaces", role: .destructive, action: clean)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Removes \(model.macSettings.workspaceRoot.appendingPathComponent("workspaces").path). Your saved drafts in Kata are not affected.")
    }
  }

  private var automaticLabel: String {
    model.ides.first.map { "Automatic (\($0.name))" } ?? "Automatic"
  }

  private var choice: Choice {
    let mac = model.macSettings
    if let id = mac.ideBundleID { return .known(id) }
    return .automatic
  }

  private func select(_ new: Choice) {
    let mac = model.macSettings
    switch new {
    case .automatic:
      mac.ideBundleID = nil
      mac.ideAppPath = nil
    case .known(let id):
      mac.ideBundleID = id
      if model.ides.contains(where: { $0.bundleID == id }) { mac.ideAppPath = nil }
    case .other:
      let panel = NSOpenPanel()
      panel.allowedContentTypes = [.application]
      panel.directoryURL = URL(fileURLWithPath: "/Applications")
      panel.prompt = "Choose"
      if panel.runModal() == .OK, let url = panel.url, let ide = IDELauncher.ide(at: url) {
        mac.ideBundleID = ide.bundleID
        mac.ideAppPath = url.path
      }
    }
  }

  private func chooseRoot() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.prompt = "Choose"
    if panel.runModal() == .OK, let url = panel.url { model.macSettings.workspaceRootPath = url.path }
  }

  private func clean() {
    let dir = model.macSettings.workspaceRoot.appendingPathComponent("workspaces", isDirectory: true)
    for key in model.kataSessions.keys { model.kataSessions[key]?.leaveIDEMode() }
    let fm = FileManager.default
    // Read-only files (provided interfaces) block removal until made writable again.
    if let e = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
      for case let url as URL in e { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
    }
    do {
      if fm.fileExists(atPath: dir.path) { try fm.removeItem(at: dir) }
      cleaned = "Workspaces deleted."
    } catch {
      cleaned = "Could not delete: \(error.localizedDescription)"
    }
  }
}
