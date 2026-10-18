import KataCore
import KataUI
import SwiftUI

/// One item in a list: mastery ring, title, intent or note, bookmark glyph.
/// Items without a body are dimmed and marked "Coming soon".
struct ItemRow: View {
  let meta: ItemMeta
  let mastery: ItemMastery?
  let hasContent: Bool
  var isBookmarked = false
  var note = ""
  var isNext = false
  var showsCategory: String?

  var body: some View {
    HStack(spacing: 14) {
      MasteryRing(level: mastery?.level ?? .notStarted, fraction: mastery?.fraction ?? 0)
        .frame(width: 26, height: 26)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 8) {
          Text(meta.title).font(.body.weight(.medium))
          if isNext {
            Text("Next")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.tint)
              .padding(.horizontal, 7).padding(.vertical, 2)
              .background(.tint.opacity(0.14), in: .capsule)
          }
          if !hasContent { ComingSoonBadge() }
        }
        Text(note.isEmpty ? meta.intent : note)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .italic(!note.isEmpty)
          .lineLimit(2)
        if let showsCategory {
          Text(showsCategory).font(.caption).foregroundStyle(.tertiary)
        }
      }
      Spacer(minLength: 0)
      if isBookmarked {
        Image(systemName: "bookmark.fill").font(.footnote).foregroundStyle(.tint)
          .accessibilityLabel("Bookmarked")
      }
    }
    .opacity(hasContent ? 1 : 0.55)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}
