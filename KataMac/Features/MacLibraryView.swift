import KataCore
import KataStore
import KataUI
import SwiftUI

/// All categories of the library (or just one), and the bookmarks list.
struct MacLibraryView: View {
  /// `nil` shows every category of every topic.
  var category: (topic: TopicID, id: String)?
  var bookmarksOnly = false
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store

  var body: some View {
    let mastery = model.masteryMap()
    let progress = store.allProgress()
    let topics = model.library.topics
    Group {
      if topics.isEmpty {
        ContentUnavailableView("No content installed", systemImage: "tray")
      } else if bookmarksOnly && store.bookmarks().isEmpty {
        ContentUnavailableView(
          "No bookmarks yet", systemImage: "bookmark",
          description: Text("Bookmark an item from its page to find it here."))
      } else {
        MacPage {
          VStack(alignment: .leading, spacing: 28) {
            ForEach(topics.filter { category == nil || $0.id == category?.topic }) { topic in
              topicSections(topic, mastery: mastery, progress: progress, showsTopic: topics.count > 1 && category == nil)
            }
          }
        }
      }
    }
    .navigationTitle(title)
  }

  private var title: String {
    if bookmarksOnly { return "Bookmarks" }
    if let category, let topic = model.library.topic(category.topic),
      let c = topic.categories.first(where: { $0.id == category.id })
    {
      return c.title
    }
    return "Library"
  }

  @ViewBuilder
  private func topicSections(
    _ topic: Topic, mastery: [ItemKey: ItemMastery], progress: [ItemKey: ItemProgressRecord],
    showsTopic: Bool
  ) -> some View {
    if showsTopic { Text(topic.title).font(.title2.weight(.semibold)) }
    ForEach(topic.categories.filter { category == nil || $0.id == category?.id }) { c in
      let items = topic.items.filter { meta in
        meta.category == c.id
          && (!bookmarksOnly || progress[topic.key(for: meta.id)]?.isBookmarked == true)
      }
      if !items.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            SectionCaption(c.title)
            if let summary = c.summary, !bookmarksOnly {
              Text(summary).font(.footnote).foregroundStyle(.secondary)
            }
          }
          MacItemListCard(
            rows: items.map { .init(meta: $0, key: topic.key(for: $0.id)) },
            mastery: mastery, progress: progress, onOpen: { model.open($0) })
        }
      }
    }
  }
}
