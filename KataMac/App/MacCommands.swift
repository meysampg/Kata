import KataRun
import SwiftUI

/// Menu commands and their shortcuts (MAC_PLAN §5.5, the part that exists before the kata screen).
struct MacCommands: Commands {
  let model: MacAppModel
  @FocusedValue(\.itemNavigation) private var item
  @FocusedValue(\.kataSession) private var kata

  var body: some Commands {
    CommandGroup(replacing: .newItem) {}  // one main window
    CommandMenu("Go") {
      Button("Today") { model.show(.today) }.keyboardShortcut("1", modifiers: .command)
      Button("Path") { model.show(.path) }.keyboardShortcut("2", modifiers: .command)
      Button("Library") { model.show(.library) }.keyboardShortcut("3", modifiers: .command)
      Button("Search") { model.focusSearch() }.keyboardShortcut("4", modifiers: .command)
      Button("Bookmarks") { model.show(.bookmarks) }
      Divider()
      Button("Find") { model.focusSearch() }.keyboardShortcut("f", modifiers: .command)
      Divider()
      Button("Start Review") { model.startReview() }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(model.practice != nil)
    }
    CommandMenu("Card") {
      Button("Next Card") { item?.next() }
        .keyboardShortcut("]", modifiers: .command)
        .disabled(!(item?.isCards ?? false) || !(item?.canGoNext ?? false))
      Button("Previous Card") { item?.previous() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(!(item?.isCards ?? false) || !(item?.canGoPrevious ?? false))
      Divider()
      ForEach(1...7, id: \.self) { n in
        Button("Card \(n)") { item?.jump(n - 1) }
          .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: [.option, .command])
          .disabled(!(item?.isCards ?? false) || n > (item?.pageCount ?? 0))
      }
    }
    CommandMenu("Kata") {
      Button("Run Checks") { kata?.startRun() }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(kata == nil || kata?.isRunning == true)
      Button("Show Next Hint") { kata?.requestHint() }
        .keyboardShortcut("h", modifiers: [.command, .shift])
        .disabled(kata == nil || (kata?.hintsRemaining ?? 0) == 0)
      Button("Reveal Solution") { kata?.requestReveal() }
        .keyboardShortcut("s", modifiers: [.command, .option])
        .disabled(kata == nil)
      Button("Reset to Starter") { kata?.confirmation = .reset }
        .keyboardShortcut(.delete, modifiers: [.command, .shift])
        .disabled(kata == nil)
      Divider()
      Button("Open in IDE") { openInIDE(model.selectedIDE()) }
        .keyboardShortcut("o", modifiers: .command)
        .disabled(kata == nil)
      Menu("Open in") {
        ForEach(model.ides) { ide in
          Button(ide.name) { openInIDE(ide) }
        }
      }
      .disabled(kata == nil || model.ides.isEmpty)
      Button("Back to Built-in Editor") { kata?.leaveIDEMode() }
        .disabled(kata?.mode != .ide)
      Divider()
      Button("Jump to Next Diagnostic") { kata?.jumpToNextDiagnostic() }
        .keyboardShortcut("'", modifiers: .command)
        .disabled(kata == nil)
    }
  }

  private func openInIDE(_ ide: IDE?) {
    guard let kata else { return }
    guard let ide else { kata.reportIDEUnavailable(); return }
    Task { await kata.startIDEMode(ide: ide) }
  }
}
