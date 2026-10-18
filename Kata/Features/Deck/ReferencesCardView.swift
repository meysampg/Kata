import KataCore
import KataUI
import SwiftUI

struct ReferencesCardView: View {
  let entries: [Reference]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
        VStack(alignment: .leading, spacing: 6) {
          Text(entry.origin)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(.tint.opacity(0.12), in: .capsule)
          Text(entry.name).font(.system(.callout, design: .monospaced).weight(.semibold))
          Text(InlineMarkdown.attributed(entry.detail))
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
      }
    }
  }
}
