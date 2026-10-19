import KataCore
import KataStore
import KataUI
import SwiftUI

struct TodayView: View {
  @Environment(AppModel.self) private var model
  @Environment(ProgressStore.self) private var store

  var body: some View {
    let queue = model.reviewQueue()
    let mastery = model.masteryMap()
    let progress = store.allProgress()
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if let error = model.libraryError {
          ContentUnavailableView(
            "Content could not be loaded", systemImage: "exclamationmark.triangle",
            description: Text(error))
        }
        reviewCard(count: queue.count)
        streakLine
        if let next = nextItem(mastery: mastery) { continueCard(next) }
        recentSection(progress: progress, mastery: mastery)
        bookmarkSection(progress: progress, mastery: mastery)
      }
      .padding(.horizontal, Theme.pageMargin)
      .padding(.vertical, 12)
    }
    .navigationTitle("Today")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { model.isSettingsPresented = true } label: { Image(systemName: "gearshape") }
          .accessibilityLabel("Settings")
      }
    }
  }

  // MARK: Review

  private func reviewCard(count: Int) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      if count > 0 {
        Text(count == 1 ? "1 review due" : "\(count) reviews due")
          .font(.title2.weight(.semibold))
        Text("A short session keeps what you learned.")
          .font(.subheadline).foregroundStyle(.secondary)
        Button { model.startReview() } label: {
          Text("Start review").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
      } else {
        Text("All caught up").font(.title2.weight(.semibold))
        Text(nextReviewText).font(.subheadline).foregroundStyle(.secondary)
      }
    }
    .cardSurface()
  }

  private var nextReviewText: String {
    guard let due = model.nextDueDate() else {
      return "Study a pattern, then practice it to schedule reviews."
    }
    let seconds = due.timeIntervalSinceNow
    if seconds <= 0 { return "Nothing left for today." }
    return "Next review in \(IntervalFormatter.short(seconds: seconds, scheduledDays: seconds >= 86_400 ? seconds / 86_400 : 0))."
  }

  private var streakLine: some View {
    let streak = store.currentStreak()
    let today = store.todayActivity()
    let count = today.reviews
    return HStack(spacing: 8) {
      Image(systemName: "flame").foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
        .accessibilityHidden(true)
      Text(streak > 0 ? "\(streak)-day streak" : "No streak yet")
      Text("·").foregroundStyle(.tertiary)
      Text(count == 0 ? "Nothing practiced today" : (count == 1 ? "1 exercise today" : "\(count) exercises today"))
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
    .font(.subheadline)
    .accessibilityElement(children: .combine)
  }

  // MARK: Continue path

  /// The next item to study in path order. Items without a body count as done so they are skipped.
  private func nextItem(mastery: [ItemKey: ItemMastery]) -> ItemKey? {
    for topic in model.library.topics {
      guard let path = model.library.learningPath(topic.id) else { continue }
      var levels: [ItemID: Mastery] = [:]
      for id in path.allItems {
        let key = topic.key(for: id)
        levels[id] = model.hasContent(key) ? (mastery[key]?.level ?? .notStarted) : .mastered
      }
      if let next = path.next(progress: levels) { return topic.key(for: next) }
    }
    return nil
  }

  private func continueCard(_ key: ItemKey) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionCaption("Continue your path")
      if let meta = model.library.meta(key) {
        Button { model.push(DeckRoute(key: key)) } label: {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(meta.title).font(.title3.weight(.semibold))
              Spacer()
              DifficultyDots(level: meta.difficulty)
            }
            Text(meta.intent).font(.subheadline).foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }
          .cardSurface()
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: Recent and bookmarks

  @ViewBuilder
  private func recentSection(progress: [ItemKey: ItemProgressRecord], mastery: [ItemKey: ItemMastery]) -> some View {
    let recent = store.recentlyStudied(limit: 4)
    if !recent.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        SectionCaption("Recently studied")
        compactList(recent.map(\.key), progress: progress, mastery: mastery)
      }
    }
  }

  @ViewBuilder
  private func bookmarkSection(progress: [ItemKey: ItemProgressRecord], mastery: [ItemKey: ItemMastery]) -> some View {
    let marks = store.bookmarks()
    if !marks.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          SectionCaption("Bookmarks")
          Spacer()
          if marks.count > 5 {
            Button("All") {
              model.libraryBookmarksOnly = true
              model.selectedTab = .library
            }
            .font(.footnote)
          }
        }
        compactList(marks.prefix(5).map(\.key), progress: progress, mastery: mastery)
      }
    }
  }

  private func compactList(_ keys: [ItemKey], progress: [ItemKey: ItemProgressRecord], mastery: [ItemKey: ItemMastery]) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(keys.enumerated()), id: \.element) { i, key in
        if let meta = model.library.meta(key) {
          let hasContent = model.hasContent(key)
          Button {
            if hasContent { model.push(DeckRoute(key: key)) }
          } label: {
            ItemRow(
              meta: meta, mastery: mastery[key], hasContent: hasContent,
              isBookmarked: progress[key]?.isBookmarked ?? false, note: progress[key]?.note ?? "")
              .padding(.vertical, 10)
          }
          .buttonStyle(.plain)
          .disabled(!hasContent)
          if i < keys.count - 1 { Divider() }
        }
      }
    }
    .padding(.horizontal, Theme.cardPadding)
    .padding(.vertical, 2)
    .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
  }
}

#Preview {
  NavigationStack { TodayView() }
    .environment(AppModel.preview())
    .environment(AppModel.preview().store)
}
