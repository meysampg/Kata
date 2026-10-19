import KataCore
import KataStore
import KataUI
import SwiftUI

/// Scrolling page with a readable column (at most `maxWidth`) centred in the window.
struct MacPage<Content: View>: View {
  var maxWidth: CGFloat = MacLayout.readableWidth
  @ViewBuilder var content: Content

  var body: some View {
    ScrollView {
      content
        .frame(maxWidth: maxWidth, alignment: .leading)
        .padding(.horizontal, MacLayout.pageMargin)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
  }
}

enum MacLayout {
  static let readableWidth: CGFloat = 760
  static let pageMargin: CGFloat = 28
}

/// A row button with a quiet hover highlight, used inside list cards.
struct MacRowButtonStyle: ButtonStyle {
  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 10)
      .padding(.vertical, 2)
      .background(
        (configuration.isPressed ? Color.primary.opacity(0.08) : (hovering ? Color.primary.opacity(0.05) : .clear)),
        in: .rect(cornerRadius: 12)
      )
      .onHover { hovering = $0 }
      .contentShape(.rect)
  }
}

/// A card of item rows (mastery ring, title, intent). Rows without a body are dimmed and inert.
struct MacItemListCard: View {
  struct Row: Identifiable {
    let meta: ItemMeta
    let key: ItemKey
    var isNext = false
    var category: String?
    var id: ItemKey { key }
  }

  let rows: [Row]
  let mastery: [ItemKey: ItemMastery]
  let progress: [ItemKey: ItemProgressRecord]
  var onOpen: (ItemKey) -> Void
  @Environment(MacAppModel.self) private var model

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
        let hasContent = model.hasContent(row.key)
        Button { onOpen(row.key) } label: {
          ItemRow(
            meta: row.meta, mastery: mastery[row.key], hasContent: hasContent,
            isBookmarked: progress[row.key]?.isBookmarked ?? false,
            note: progress[row.key]?.note ?? "", isNext: row.isNext, showsCategory: row.category)
            .padding(.vertical, 10)
        }
        .buttonStyle(MacRowButtonStyle())
        .disabled(!hasContent)
        if index < rows.count - 1 { Divider().padding(.horizontal, 10) }
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
  }
}
