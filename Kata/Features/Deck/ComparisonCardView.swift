import KataCore
import KataUI
import SwiftUI

struct ComparisonCardView: View {
  let rows: [ComparisonRow]
  let topic: Topic
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        let key = topic.key(for: row.ref)
        let hasContent = model.hasContent(key)
        Button {
          if hasContent { model.push(DeckRoute(key: key)) }
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
              if hasContent {
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
        .disabled(!hasContent)
        .accessibilityHint(hasContent ? "Opens \(topic.meta(for: row.ref)?.title ?? row.ref)" : "No content yet")
      }
    }
  }
}

extension ComparisonRelation {
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
