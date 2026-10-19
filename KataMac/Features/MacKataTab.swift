import KataCore
import KataStore
import KataUI
import SwiftUI

/// The Kata tab. The editor arrives in a later phase; this screen shows the task and applies the
/// soft gate: katas are recommended after the item's exercises, with an override.
struct MacKataTab: View {
  let key: ItemKey
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @State private var override = false

  var body: some View {
    if let kata = model.library.kata(key) {
      let studied = store.progress(for: key)?.studiedAt != nil
      MacPage {
        VStack(alignment: .leading, spacing: 20) {
          header(kata)
          if !studied && !override {
            gate
          } else {
            VStack(alignment: .leading, spacing: 12) {
              SectionCaption("Task")
              BlocksView(blocks: kata.task, codeFontSize: max(12, settings.codeFontPoints - 1))
                .cardSurface()
            }
            checks(kata)
            Label("The editor and the checks arrive in the next phase (P3).", systemImage: "hammer")
              .font(.subheadline).foregroundStyle(.secondary)
              .cardSurface()
          }
        }
      }
    } else {
      ContentUnavailableView(
        "No kata for this item yet", systemImage: "hammer",
        description: Text("Katas are being written pattern by pattern."))
    }
  }

  private func header(_ kata: Kata) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(kata.kind.rawValue.capitalized)
          .font(.caption2.weight(.semibold)).foregroundStyle(.tint)
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(.tint.opacity(0.14), in: .capsule)
        Text("about \(kata.minutes) min").font(.caption).foregroundStyle(.secondary)
      }
      Text(kata.title).font(.title2.weight(.semibold))
    }
  }

  private var gate: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Recommended after the cards", systemImage: "lightbulb")
        .font(.headline)
      Text("Practice this pattern's exercises first. The kata is easier once the vocabulary is fresh.")
        .font(.subheadline).foregroundStyle(.secondary)
      Button("Start the kata anyway") { override = true }
        .buttonStyle(.bordered)
    }
    .cardSurface()
  }

  private func checks(_ kata: Kata) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionCaption("What the checks look at")
      VStack(alignment: .leading, spacing: 8) {
        ForEach(kata.checks, id: \.id) { check in
          HStack(spacing: 8) {
            Image(systemName: check.kind == .design ? "square.grid.2x2" : "checkmark.circle")
              .foregroundStyle(.secondary).frame(width: 18)
            Text(check.title)
            Spacer(minLength: 0)
            Text(check.kind.rawValue).font(.caption).foregroundStyle(.tertiary)
          }
          .font(.subheadline)
        }
      }
      .cardSurface()
    }
  }
}
