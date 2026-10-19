import KataCore
import KataStore
import KataUI
import SwiftUI

/// Topics (only listed when there is more than one), then categories and items.
struct LibraryView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let topics = model.library.topics
    Group {
      if topics.count == 1, let topic = topics.first {
        TopicLibraryView(topic: topic)
      } else if topics.isEmpty {
        ContentUnavailableView("No content installed", systemImage: "tray")
      } else {
        List(topics) { topic in
          NavigationLink(value: topic.id) {
            Label {
              VStack(alignment: .leading) {
                Text(topic.title).font(.body.weight(.medium))
                if let s = topic.subtitle { Text(s).font(.subheadline).foregroundStyle(.secondary) }
              }
            } icon: { Image(systemName: topic.symbol) }
          }
        }
        .navigationTitle("Library")
        .navigationDestination(for: TopicID.self) { id in
          if let topic = model.library.topic(id) { TopicLibraryView(topic: topic) }
        }
      }
    }
  }
}

struct TopicLibraryView: View {
  let topic: Topic
  @Environment(AppModel.self) private var model
  @Environment(ProgressStore.self) private var store

  var body: some View {
    @Bindable var model = model
    let mastery = model.masteryMap()
    let progress = store.allProgress()
    let onlyBookmarks = model.libraryBookmarksOnly
    List {
      Section {
        Toggle(isOn: $model.libraryBookmarksOnly) {
          Label("Bookmarks", systemImage: onlyBookmarks ? "bookmark.fill" : "bookmark")
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
      }
      ForEach(topic.categories) { category in
        let items = topic.items.filter { meta in
          meta.category == category.id
            && (!onlyBookmarks || progress[topic.key(for: meta.id)]?.isBookmarked == true)
        }
        if !items.isEmpty {
          Section {
            ForEach(items) { meta in
              let key = topic.key(for: meta.id)
              let hasContent = model.hasContent(key)
              let content = ItemRow(
                meta: meta, mastery: mastery[key], hasContent: hasContent,
                isBookmarked: progress[key]?.isBookmarked ?? false, note: progress[key]?.note ?? "")
              if hasContent {
                NavigationLink(value: DeckRoute(key: key)) { content }
              } else {
                content
              }
            }
          } header: {
            Text(category.title)
          } footer: {
            if let s = category.summary, !onlyBookmarks { Text(s) }
          }
        }
      }
      if onlyBookmarks && store.bookmarks().isEmpty {
        ContentUnavailableView(
          "No bookmarks yet", systemImage: "bookmark",
          description: Text("Bookmark an item from its deck to find it here."))
          .listRowBackground(Color.clear)
      }
    }
    .navigationTitle(topic.title)
  }
}
