import KataCore
import SwiftUI

public struct ComparisonCardView: View {
  let rows: [ComparisonRow]
  let topic: Topic
  let hasContent: (ItemKey) -> Bool
  let onOpen: (ItemKey) -> Void

  /// - Parameters:
  ///   - hasContent: whether a referenced item has a body (rows without one are not tappable).
  ///   - onOpen: opens the referenced item.
  public init(
    rows: [ComparisonRow], topic: Topic, hasContent: @escaping (ItemKey) -> Bool,
    onOpen: @escaping (ItemKey) -> Void
  ) {
    self.rows = rows; self.topic = topic; self.hasContent = hasContent; self.onOpen = onOpen
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        let key = topic.key(for: row.ref)
        let available = hasContent(key)
        Button {
          if available { onOpen(key) }
        } label: {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
              Text(topic.meta(for: row.ref)?.title ?? row.ref).font(.headline)
              Text(row.relation.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: .capsule)
              Spacer(minLength: 0)
              if available {
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
              } else {
                ComingSoonBadge()
              }
            }
            Text(InlineMarkdown.attributed(row.difference))
              .font(.callout).foregroundStyle(.primary)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }
          .cardSurface()
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityHint(available ? "Opens \(topic.meta(for: row.ref)?.title ?? row.ref)" : "No content yet")
      }
    }
  }
}

public extension ComparisonRelation {
  var label: String {
    switch self {
    case .lookAlike: "Look-alike"
    case .alternative: "Alternative"
    case .combines: "Combines with"
    case .oftenConfused: "Often confused"
    case .specializes: "Specializes"
    }
  }
}
