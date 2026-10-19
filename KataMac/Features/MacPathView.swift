import KataCore
import KataStore
import KataUI
import SwiftUI

/// The learning path: sections of items, nothing locked.
struct MacPathView: View {
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store
  @State private var topicID: TopicID?

  private var topic: Topic? {
    let topics = model.library.topics
    return topics.first { $0.id == topicID } ?? topics.first
  }

  var body: some View {
    let mastery = model.masteryMap()
    let progress = store.allProgress()
    Group {
      if let topic, let path = model.library.learningPath(topic.id) {
        let next = model.nextItem(topic: topic, path: path, mastery: mastery)
        MacPage {
          VStack(alignment: .leading, spacing: 24) {
            header(topic: topic, path: path, progress: progress, mastery: mastery)
            ForEach(Array(path.sections.enumerated()), id: \.offset) { _, section in
              VStack(alignment: .leading, spacing: 8) {
                SectionCaption(section.title)
                MacItemListCard(
                  rows: section.items.compactMap { id in
                    topic.meta(for: id).map {
                      .init(meta: $0, key: topic.key(for: id), isNext: id == next)
                    }
                  },
                  mastery: mastery, progress: progress, onOpen: { model.open($0) })
              }
            }
          }
        }
      } else {
        ContentUnavailableView("No content installed", systemImage: "tray")
      }
    }
    .navigationTitle("Path")
    .toolbar {
      if model.library.topics.count > 1 {
        ToolbarItem {
          Picker("Topic", selection: Binding(get: { topic?.id ?? "" }, set: { topicID = $0 })) {
            ForEach(model.library.topics) { Text($0.title).tag($0.id) }
          }
        }
      }
    }
  }

  private func header(
    topic: Topic, path: LearningPath, progress: [ItemKey: ItemProgressRecord],
    mastery: [ItemKey: ItemMastery]
  ) -> some View {
    let studied = path.allItems.filter { id in
      let key = topic.key(for: id)
      return progress[key]?.studiedAt != nil || (mastery[key]?.level ?? .notStarted) != .notStarted
    }.count
    return VStack(alignment: .leading, spacing: 8) {
      Text(topic.title).font(.title2.weight(.semibold))
      if let subtitle = topic.subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
      ProgressView(value: Double(studied), total: Double(max(path.allItems.count, 1)))
      Text("\(studied) / \(path.allItems.count) studied")
        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
    }
    .cardSurface()
  }
}
