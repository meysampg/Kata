import KataCode
import KataCore
import KataStore
import KataUI
import SwiftUI

/// One item as a horizontally paged deck of cards (PLAN §4.4). The tab bar is hidden; a glass
/// strip of role symbols is the page indicator.
struct ItemDeckView: View {
  let route: DeckRoute
  @Environment(AppModel.self) private var model
  @Environment(ProgressStore.self) private var store
  @State private var current: String?
  @State private var codeMode: CodeViewMode = .read
  @State private var isNotePresented = false
  @State private var noteDraft = ""
  @State private var comingSoon: String?

  init(route: DeckRoute) {
    self.route = route
    _current = State(initialValue: route.role)
  }

  var body: some View {
    if let item = model.library.item(route.key), let topic = model.library.topic(route.key.topic) {
      deck(item: item, topic: topic)
    } else {
      ContentUnavailableView("Coming soon", systemImage: "hourglass", description: Text("This item has no content yet."))
    }
  }

  private func deck(item: KataCore.LibraryItem, topic: Topic) -> some View {
    let cards = item.item.cards
    let selected = current ?? cards.first?.role
    let pages = cards.map { card in
      GlassBottomBar.Page(
        id: card.role, symbol: topic.roles[card.role]?.symbol ?? "square",
        title: topic.roles[card.role]?.title ?? card.role)
    }
    let lastRole = cards.last?.role
    let hasExercises = !item.item.exercises.isEmpty
    let selectedCard = cards.first { $0.role == selected }
    return ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(cards, id: \.role) { card in
          CardPage(
            card: card, topic: topic, spec: topic.roles[card.role],
            showsPractice: hasExercises && card.role == lastRole, itemKey: route.key,
            codeMode: $codeMode
          )
          .containerRelativeFrame(.horizontal)
          .id(card.role)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $current)
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      GlassBottomBar(
        pages: pages,
        selection: Binding(get: { selected }, set: { current = $0 })
      )
      .padding(.bottom, 4)
    }
    .environment(\.openURL, OpenURLAction { url in
      guard url.scheme == "kata" else { return .systemAction }
      if let key = model.resolve(link: url, in: route.key.topic) {
        if model.hasContent(key) {
          model.push(DeckRoute(key: key))
        } else {
          comingSoon = model.title(of: key)
        }
      }
      return .handled
    })
    .alert("Coming soon", isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("\(comingSoon ?? "This item") has no content yet.")
    }
    .navigationTitle(item.meta.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarVisibility(.hidden, for: .tabBar)
    .toolbar {
      if case .code(let code)? = selectedCard?.content, !WalkthroughState(card: code).isEmpty {
        ToolbarItem(placement: .principal) {
          CodeModePicker(mode: $codeMode).frame(width: 230)
        }
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        noteButton
        bookmarkButton
      }
    }
    .task(id: selected) {
      store.markOpened(route.key, role: selected)
    }
  }

  // MARK: Bookmark and note

  private var progress: ItemProgressRecord? { store.progress(for: route.key) }

  private var bookmarkButton: some View {
    let on = progress?.isBookmarked ?? false
    return Button {
      store.setBookmarked(route.key, !on)
    } label: {
      Image(systemName: on ? "bookmark.fill" : "bookmark")
    }
    .accessibilityLabel(on ? "Remove bookmark" : "Bookmark")
    .sensoryFeedback(.selection, trigger: on)
  }

  private var noteButton: some View {
    let note = progress?.note ?? ""
    return Button {
      noteDraft = note
      isNotePresented = true
    } label: {
      Image(systemName: note.isEmpty ? "note.text.badge.plus" : "note.text")
    }
    .accessibilityLabel(note.isEmpty ? "Add note" : "Edit note")
    .popover(isPresented: $isNotePresented) {
      NoteEditor(text: $noteDraft) {
        store.setNote(route.key, noteDraft)
        isNotePresented = false
      }
      .presentationCompactAdaptation(.popover)
    }
  }
}

/// One-line note, 140 characters, saved on submit.
private struct NoteEditor: View {
  @Binding var text: String
  let onSave: () -> Void
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Note").font(.headline)
      TextField("One line for future you", text: $text)
        .textFieldStyle(.roundedBorder)
        .submitLabel(.done)
        .focused($focused)
        .onChange(of: text) { _, new in
          if new.count > ItemProgressRecord.maxNoteLength {
            text = String(new.prefix(ItemProgressRecord.maxNoteLength))
          }
        }
        .onSubmit(onSave)
      Text("\(text.count) / \(ItemProgressRecord.maxNoteLength)")
        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
    }
    .padding()
    .frame(width: 300)
    .onAppear { focused = true }
  }
}

/// Renders one card with its role heading; scrolls vertically unless it manages its own scroll.
private struct CardPage: View {
  let card: Card
  let topic: Topic
  let spec: RoleSpec?
  let showsPractice: Bool
  let itemKey: ItemKey
  @Binding var codeMode: CodeViewMode

  @Environment(AppModel.self) private var model
  @Environment(AppSettings.self) private var settings

  var body: some View {
    switch card.content {
    case .code(let code):
      VStack(spacing: 8) {
        heading.padding(.horizontal, Theme.pageMargin)
        CodeCardView(
          card: code, fontSize: settings.codeFontPoints, showLineNumbers: settings.showLineNumbers,
          mode: $codeMode)
      }
      .padding(.top, 8)
      .overlay(alignment: .bottomTrailing) {
        if showsPractice { PracticeCTA(itemKey: itemKey, compact: true).padding(.trailing, 16).padding(.bottom, 70) }
      }
    default:
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          heading
          content
          if showsPractice { PracticeCTA(itemKey: itemKey, compact: false).padding(.top, 8) }
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.vertical, 12)
      }
    }
  }

  private var heading: some View {
    Label(spec?.title ?? card.role, systemImage: spec?.symbol ?? "square")
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
      .accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder
  private var content: some View {
    switch card.content {
    case .text(let blocks): TextCardView(blocks: blocks, codeFontSize: max(12, settings.codeFontPoints - 1))
    case .code: EmptyView()
    case .diagram(let diagrams): DiagramCardView(diagrams: diagrams)
    case .lists(let groups): ListsCardView(groups: groups)
    case .comparison(let rows):
      ComparisonCardView(
        rows: rows, topic: topic, hasContent: { model.hasContent($0) },
        onOpen: { model.push(DeckRoute(key: $0)) })
    case .references(let entries): ReferencesCardView(entries: entries)
    }
  }
}

/// "Practice this pattern" at the end of the deck.
private struct PracticeCTA: View {
  let itemKey: ItemKey
  let compact: Bool
  @Environment(AppModel.self) private var model

  var body: some View {
    Button { model.startPractice(item: itemKey) } label: {
      Label("Practice this pattern", systemImage: "figure.mind.and.body")
        .font(.body.weight(.semibold))
        .frame(maxWidth: compact ? nil : .infinity, minHeight: 44)
        .padding(.horizontal, compact ? 8 : 0)
    }
    .buttonStyle(.glassProminent)
  }
}
