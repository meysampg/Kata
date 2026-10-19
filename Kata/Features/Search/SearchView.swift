import KataCore
import KataUI
import SwiftUI

struct SearchView: View {
  @Environment(AppModel.self) private var model
  @State private var results: [SearchResult] = []

  var body: some View {
    @Bindable var model = model
    List {
      ForEach(results) { result in
        let hasContent = model.hasContent(result.key)
        let content = row(result, hasContent: hasContent)
        if hasContent {
          NavigationLink(value: DeckRoute(key: result.key, role: result.role)) { content }
        } else {
          content
        }
      }
    }
    .listStyle(.plain)
    .overlay {
      if model.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
        ContentUnavailableView(
          "Search patterns", systemImage: "magnifyingglass",
          description: Text("Titles, aliases and everything on the cards."))
      } else if results.isEmpty {
        ContentUnavailableView.search(text: model.searchQuery)
      }
    }
    .navigationTitle("Search")
    .searchable(text: $model.searchQuery, prompt: "Patterns, principles, terms")
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
    return VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 8) {
        Text(result.title).font(.body.weight(.medium))
        if !hasContent { ComingSoonBadge() }
      }
      if let snippet = result.snippet {
        Text(snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
      }
      Text([category, roleTitle].compactMap { $0 }.joined(separator: " · "))
        .font(.caption).foregroundStyle(.tertiary)
    }
    .opacity(hasContent ? 1 : 0.55)
    .accessibilityElement(children: .combine)
  }
}
