import KataCore
import KataStore
import SwiftUI

/// Today, Path, Library (with its categories), Search and Bookmarks.
struct MacSidebar: View {
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store
  @State private var libraryExpanded = true

  var body: some View {
    @Bindable var model = model
    let reviews = model.reviewQueue().count
    let katas = model.dueKatas().count
    let bookmarks = store.bookmarks().count
    List(selection: $model.selection) {
      Label("Today", systemImage: "sun.max")
        .badge(reviews + katas)
        .tag(MacSection.today)
        .help(badgeHelp(reviews: reviews, katas: katas))
      Label("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        .tag(MacSection.path)
      DisclosureGroup(isExpanded: $libraryExpanded) {
        ForEach(model.library.topics) { topic in
          ForEach(topic.categories) { category in
            Label(category.title, systemImage: symbol(for: category.id))
              .tag(MacSection.category(topic.id, category.id))
          }
        }
      } label: {
        Label("Library", systemImage: "books.vertical").tag(MacSection.library)
      }
      Label("Search", systemImage: "magnifyingglass").tag(MacSection.search)
      Label("Bookmarks", systemImage: "bookmark")
        .badge(bookmarks)
        .tag(MacSection.bookmarks)
    }
    .listStyle(.sidebar)
  }

  private func badgeHelp(reviews: Int, katas: Int) -> String {
    var parts: [String] = []
    if reviews > 0 { parts.append(reviews == 1 ? "1 review due" : "\(reviews) reviews due") }
    if katas > 0 { parts.append(katas == 1 ? "1 kata due" : "\(katas) katas due") }
    return parts.isEmpty ? "Nothing due" : parts.joined(separator: ", ")
  }

  private func symbol(for category: String) -> String {
    switch category {
    case "foundations": "building.columns"
    case "creational": "hammer"
    case "structural": "square.on.square"
    case "behavioral": "arrow.triangle.branch"
    case "concurrency": "point.3.connected.trianglepath.dotted"
    case "enterprise": "building.2"
    case "resilience": "shield"
    default: "folder"
    }
  }
}
