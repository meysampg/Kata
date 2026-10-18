import KataCore
import KataUI
import SwiftUI

struct ListsCardView: View {
  let groups: [ListGroup]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
        VStack(alignment: .leading, spacing: 10) {
          Label {
            Text(group.title).font(.headline)
          } icon: {
            Image(systemName: group.tone.symbolName).foregroundStyle(group.tone.color)
          }
          .accessibilityAddTraits(.isHeader)
          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(group.items.enumerated()), id: \.offset) { _, text in
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle().fill(group.tone.color.opacity(0.7)).frame(width: 5, height: 5)
                  .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                  .accessibilityHidden(true)
                Text(InlineMarkdown.attributed(text)).fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }
        .cardSurface()
      }
    }
  }
}
