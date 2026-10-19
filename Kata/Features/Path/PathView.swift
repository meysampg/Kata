import KataCore
import KataStore
import KataUI
import SwiftUI

/// The learning path: a calm vertical list grouped by section. Nothing is locked.
struct PathView: View {
  @Environment(AppModel.self) private var model
  @Environment(ProgressStore.self) private var store

  private var topic: Topic? {
    let topics = model.library.topics
    return topics.first { $0.id == model.pathTopicID } ?? topics.first
  }

  var body: some View {
    let mastery = model.masteryMap()
    let progress = store.allProgress()
    Group {
      if let topic, let path = model.library.learningPath(topic.id) {
        List {
          header(topic: topic, path: path, progress: progress, mastery: mastery)
          let next = nextItem(topic: topic, path: path, mastery: mastery)
          ForEach(Array(path.sections.enumerated()), id: \.offset) { _, section in
            Section(section.title) {
              ForEach(section.items, id: \.self) { id in
                if let meta = topic.meta(for: id) {
                  row(meta: meta, key: topic.key(for: id), next: next, mastery: mastery, progress: progress)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      } else {
        ContentUnavailableView("No content installed", systemImage: "tray")
      }
    }
    .navigationTitle("Path")
    .toolbar {
      if model.library.topics.count > 1 {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker("Topic", selection: Binding(get: { topic?.id ?? "" }, set: { model.pathTopicID = $0 })) {
              ForEach(model.library.topics) { Text($0.title).tag($0.id) }
            }
          } label: { Image(systemName: "square.stack.3d.up") }
        }
      }
    }
  }

  private func nextItem(topic: Topic, path: LearningPath, mastery: [ItemKey: ItemMastery]) -> ItemID? {
    var levels: [ItemID: Mastery] = [:]
    for id in path.allItems {
      let key = topic.key(for: id)
      levels[id] = model.hasContent(key) ? (mastery[key]?.level ?? .notStarted) : .mastered
    }
    return path.next(progress: levels)
  }

  private func header(topic: Topic, path: LearningPath, progress: [ItemKey: ItemProgressRecord], mastery: [ItemKey: ItemMastery]) -> some View {
    let studied = path.allItems.filter { id in
      let key = topic.key(for: id)
      return progress[key]?.studiedAt != nil || (mastery[key]?.level ?? .notStarted) != .notStarted
    }.count
    return Section {
      VStack(alignment: .leading, spacing: 8) {
        Text(topic.title).font(.title2.weight(.semibold))
        if let subtitle = topic.subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        ProgressView(value: Double(studied), total: Double(max(path.allItems.count, 1)))
        Text("\(studied) / \(path.allItems.count) studied")
          .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
      }
      .padding(.vertical, 4)
    }
  }

  @ViewBuilder
  private func row(meta: ItemMeta, key: ItemKey, next: ItemID?, mastery: [ItemKey: ItemMastery], progress: [ItemKey: ItemProgressRecord]) -> some View {
    let hasContent = model.hasContent(key)
    let content = ItemRow(
      meta: meta, mastery: mastery[key], hasContent: hasContent,
      isBookmarked: progress[key]?.isBookmarked ?? false, note: progress[key]?.note ?? "",
      isNext: meta.id == next)
    if hasContent {
      NavigationLink(value: DeckRoute(key: key)) { content }
        .listRowBackground(meta.id == next ? Color.accentColor.opacity(0.10) : nil)
    } else {
      content
    }
  }
}
