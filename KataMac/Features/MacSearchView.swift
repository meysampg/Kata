import KataCore
import KataUI
import SwiftUI

struct MacSearchView: View {
  @Environment(MacAppModel.self) private var model
  @State private var results: [SearchResult] = []

  var body: some View {
    let trimmed = model.searchQuery.trimmingCharacters(in: .whitespaces)
    Group {
      if trimmed.isEmpty {
        ContentUnavailableView(
          "Search patterns", systemImage: "magnifyingglass",
          description: Text("Titles, aliases and everything on the cards. Press ⌘F anywhere."))
      } else if results.isEmpty {
        ContentUnavailableView.search(text: model.searchQuery)
      } else {
        MacPage {
          VStack(spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
              let hasContent = model.hasContent(result.key)
              Button { model.open(result.key, role: result.role) } label: {
                row(result, hasContent: hasContent).padding(.vertical, 10)
              }
              .buttonStyle(MacRowButtonStyle())
              .disabled(!hasContent)
              if index < results.count - 1 { Divider().padding(.horizontal, 10) }
            }
          }
          .padding(.horizontal, 6).padding(.vertical, 4)
          .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
        }
      }
    }
    .navigationTitle("Search")
    .task(id: model.searchQuery) {
      let query = model.searchQuery
      if query.trimmingCharacters(in: .whitespaces).isEmpty {
        results = []
        return
      }
      try? await Task.sleep(for: .milliseconds(200))
      guard !Task.isCancelled else { return }
      results = model.library.search(query)
    }
  }

  private func row(_ result: SearchResult, hasContent: Bool) -> some View {
    let topic = model.library.topic(result.key.topic)
    let category = topic?.category(for: result.category)?.title ?? result.category
    let roleTitle = result.role.flatMap { topic?.roles[$0]?.title }
    return HStack {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 8) {
          Text(result.title).font(.body.weight(.medium))
          if !hasContent { ComingSoonBadge() }
        }
        if let snippet = result.snippet {
          Text(snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        Text([category, roleTitle].compactMap { $0 }.joined(separator: " · "))
          .font(.caption).foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .opacity(hasContent ? 1 : 0.55)
    .accessibilityElement(children: .combine)
  }
}
