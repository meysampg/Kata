import KataCore
import SwiftUI

/// Floating glass strip under a deck: chevrons plus one symbol per card role as page indicator.
struct GlassBottomBar: View {
  struct Page: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
  }

  let pages: [Page]
  @Binding var selection: String?

  private var index: Int { pages.firstIndex { $0.id == selection } ?? 0 }

  var body: some View {
    GlassEffectContainer(spacing: 8) {
      HStack(spacing: 4) {
        Button { move(-1) } label: { Image(systemName: "chevron.left") }
          .disabled(index == 0)
          .accessibilityLabel("Previous card")
        ForEach(pages) { page in
          Button { withAnimation(.smooth) { selection = page.id } } label: {
            Image(systemName: page.symbol)
              .font(.system(size: 16, weight: page.id == selection ? .semibold : .regular))
              .frame(width: 34, height: 34)
              .foregroundStyle(page.id == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
              .background {
                if page.id == selection { Circle().fill(.tint.opacity(0.16)) }
              }
          }
          .accessibilityLabel(page.title)
          .accessibilityAddTraits(page.id == selection ? .isSelected : [])
        }
        Button { move(1) } label: { Image(systemName: "chevron.right") }
          .disabled(index >= pages.count - 1)
          .accessibilityLabel("Next card")
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .glassEffect(.regular.interactive(), in: .capsule)
    }
    .sensoryFeedback(.selection, trigger: selection)
  }

  private func move(_ delta: Int) {
    let next = min(max(index + delta, 0), pages.count - 1)
    withAnimation(.smooth) { selection = pages[next].id }
  }
}
