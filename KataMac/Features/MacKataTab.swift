import KataCore
import KataStore
import KataUI
import SwiftUI

/// The Kata tab. The soft gate comes first (katas are recommended after the item's exercises, with
/// an override); then the kata screen.
struct MacKataTab: View {
  let key: ItemKey
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store

  var body: some View {
    if let kata = model.library.kata(key) {
      let studied = store.progress(for: key)?.studiedAt != nil
      if let session = model.kataSessions[key] {
        KataView(session: session).id(ObjectIdentifier(session))
      } else if !studied && !model.kataGateOverrides.contains(key) {
        MacPage {
          VStack(alignment: .leading, spacing: 20) {
            header(kata)
            gate
          }
        }
      } else {
        ProgressView().task { model.ensureKataSession(key) }
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
      Button("Start the kata anyway") { model.overrideKataGate(key) }
        .buttonStyle(.bordered)
    }
    .cardSurface()
  }
}
