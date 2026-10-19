import KataCore
import KataStore
import KataUI
import SwiftUI

struct MacTodayView: View {
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store

  var body: some View {
    let queue = model.reviewQueue()
    let mastery = model.masteryMap()
    let progress = store.allProgress()
    MacPage {
      VStack(alignment: .leading, spacing: 24) {
        if let error = model.libraryError {
          ContentUnavailableView(
            "Content could not be loaded", systemImage: "exclamationmark.triangle",
            description: Text(error))
        }
        reviewCard(count: queue.count)
        katasCard
        streakLine
        if let next = model.nextItem(mastery: mastery) { continueCard(next) }
        recentSection(progress: progress, mastery: mastery)
        bookmarkSection(progress: progress, mastery: mastery)
      }
    }
    .navigationTitle("Today")
  }

  // MARK: Review

  private func reviewCard(count: Int) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      if count > 0 {
        Text(count == 1 ? "1 review due" : "\(count) reviews due")
          .font(.title2.weight(.semibold))
        Text("A short session keeps what you learned.")
          .font(.subheadline).foregroundStyle(.secondary)
        HStack {
          Button { model.startReview() } label: {
            Text("Start review").font(.body.weight(.semibold)).frame(minWidth: 140, minHeight: 32)
          }
          .buttonStyle(.glassProminent)
          Text("⇧⌘R").font(.footnote).foregroundStyle(.tertiary)
        }
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

  // MARK: Katas

  @ViewBuilder
  private var katasCard: some View {
    if !model.library.katas.isEmpty {
      let due = model.dueKatas()
      VStack(alignment: .leading, spacing: 10) {
        Text("Katas due").font(.title3.weight(.semibold))
        if due.isEmpty {
          Text("No katas due today. Katas for the patterns you have studied show up here.")
            .font(.subheadline).foregroundStyle(.secondary)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(due.enumerated()), id: \.element) { index, key in
              if let kata = model.library.kata(key) {
                Button { model.open(key, tab: .kata) } label: {
                  HStack(spacing: 10) {
                    Image(systemName: "hammer").foregroundStyle(.tint).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                      Text(kata.title).font(.body.weight(.medium))
                      Text("\(model.title(of: key)) · \(kata.kind.rawValue) · about \(kata.minutes) min")
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                  }
                  .padding(.vertical, 8)
                }
                .buttonStyle(MacRowButtonStyle())
                if index < due.count - 1 { Divider().padding(.horizontal, 10) }
              }
            }
          }
        }
      }
      .cardSurface()
    }
  }

  private var streakLine: some View {
    let streak = store.currentStreak()
    let count = store.todayActivity().reviews
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

  private func continueCard(_ key: ItemKey) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionCaption("Continue your path")
      if let meta = model.library.meta(key) {
        Button { model.open(key) } label: {
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
        list(recent.map(\.key), progress: progress, mastery: mastery)
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
            Button("All") { model.show(.bookmarks) }.font(.footnote).buttonStyle(.link)
          }
        }
        list(marks.prefix(5).map(\.key), progress: progress, mastery: mastery)
      }
    }
  }

  private func list(_ keys: [ItemKey], progress: [ItemKey: ItemProgressRecord], mastery: [ItemKey: ItemMastery]) -> some View {
    MacItemListCard(
      rows: keys.compactMap { key in model.library.meta(key).map { .init(meta: $0, key: key) } },
      mastery: mastery, progress: progress, onOpen: { model.open($0) })
  }
}
