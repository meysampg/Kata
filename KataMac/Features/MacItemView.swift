import KataCode
import KataCore
import KataStore
import KataUI
import SwiftUI

/// What menu commands can do to the item on screen.
struct ItemNavigation {
  var pageCount: Int
  var canGoNext: Bool
  var canGoPrevious: Bool
  var isCards: Bool
  var next: () -> Void
  var previous: () -> Void
  var jump: (Int) -> Void
}

struct ItemNavigationKey: FocusedValueKey {
  typealias Value = ItemNavigation
}

extension FocusedValues {
  var itemNavigation: ItemNavigation? {
    get { self[ItemNavigationKey.self] }
    set { self[ItemNavigationKey.self] = newValue }
  }
}

/// One item: Cards · Practice · Kata.
struct MacItemView: View {
  let route: MacRoute
  @Environment(MacAppModel.self) private var model
  @Environment(ProgressStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @State private var tab: ItemTab
  @State private var role: String?
  @State private var codeMode: CodeViewMode = {
    #if DEBUG
    return DebugLaunch.walkStep > 0 ? .walkthrough : .read
    #else
    return .read
    #endif
  }()
  @State private var isNotePresented = false
  @State private var noteDraft = ""
  @State private var comingSoon: String?
  @State private var practiceRequest: PracticeRequest?

  init(route: MacRoute) {
    self.route = route
    _tab = State(initialValue: route.tab ?? .cards)
    _role = State(initialValue: route.role)
    _practiceRequest = State(
      initialValue: route.tab == .practice ? PracticeRequest(kind: .item(route.key)) : nil)
  }

  var body: some View {
    if let item = model.library.item(route.key), let topic = model.library.topic(route.key.topic) {
      content(item: item, topic: topic)
    } else {
      ContentUnavailableView(
        "Coming soon", systemImage: "hourglass", description: Text("This item has no content yet."))
    }
  }

  private func content(item: KataCore.LibraryItem, topic: Topic) -> some View {
    let cards = item.item.cards
    let selected = role ?? cards.first?.role
    let index = cards.firstIndex { $0.role == selected } ?? 0
    return Group {
      switch tab {
      case .cards:
        CardsTab(
          item: item, topic: topic, selected: selected, codeMode: $codeMode,
          select: { role = $0 }, startPractice: { switchTab(.practice) }, openKata: { switchTab(.kata) })
      case .practice:
        if item.item.exercises.isEmpty {
          ContentUnavailableView(
            "No exercises yet", systemImage: "checklist",
            description: Text("This item has cards but no practice exercises."))
        } else if let practiceRequest {
          MacPracticeView(request: practiceRequest, embedded: true) { switchTab(.cards) }
            .id(practiceRequest.id)
        }
      case .kata:
        MacKataTab(key: route.key)
      }
    }
    .environment(\.openURL, OpenURLAction { url in
      guard url.scheme == "kata" else { return .systemAction }
      if let key = model.resolve(link: url, in: route.key.topic) {
        if model.hasContent(key) { model.open(key) } else { comingSoon = model.title(of: key) }
      }
      return .handled
    })
    .alert("Coming soon", isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("\(comingSoon ?? "This item") has no content yet.")
    }
    .navigationTitle(item.meta.title)
    .navigationSubtitle(item.category?.title ?? "")
    .toolbar {
      ToolbarItem(placement: .principal) {
        Picker("View", selection: Binding(get: { tab }, set: { switchTab($0) })) {
          ForEach(ItemTab.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(width: 260)
        .labelsHidden()
      }
      ToolbarItemGroup(placement: .primaryAction) {
        noteButton
        bookmarkButton
      }
    }
    .focusedSceneValue(\.itemNavigation, ItemNavigation(
      pageCount: cards.count, canGoNext: index < cards.count - 1, canGoPrevious: index > 0,
      isCards: tab == .cards,
      next: { step(1, cards: cards, index: index) },
      previous: { step(-1, cards: cards, index: index) },
      jump: { i in
        guard cards.indices.contains(i) else { return }
        withAnimation(.smooth) { role = cards[i].role }
      }))
    .task(id: selected) {
      if tab == .cards { store.markOpened(route.key, role: selected) }
    }
  }

  private func step(_ delta: Int, cards: [Card], index: Int) {
    let next = min(max(index + delta, 0), cards.count - 1)
    withAnimation(.smooth) { role = cards[next].role }
  }

  private func switchTab(_ new: ItemTab) {
    if new == .practice { practiceRequest = PracticeRequest(kind: .item(route.key)) }
    tab = new
  }

  // MARK: Bookmark and note

  private var progress: ItemProgressRecord? { store.progress(for: route.key) }

  private var bookmarkButton: some View {
    let on = progress?.isBookmarked ?? false
    return Button { store.setBookmarked(route.key, !on) } label: {
      Image(systemName: on ? "bookmark.fill" : "bookmark")
    }
    .help(on ? "Remove bookmark" : "Bookmark this item")
    .accessibilityLabel(on ? "Remove bookmark" : "Bookmark")
  }

  private var noteButton: some View {
    let note = progress?.note ?? ""
    return Button {
      noteDraft = note
      isNotePresented = true
    } label: {
      Image(systemName: note.isEmpty ? "note.text.badge.plus" : "note.text")
    }
    .help(note.isEmpty ? "Add a note" : "Edit note")
    .accessibilityLabel(note.isEmpty ? "Add note" : "Edit note")
    .popover(isPresented: $isNotePresented) {
      MacNoteEditor(text: $noteDraft) {
        store.setNote(route.key, noteDraft)
        isNotePresented = false
      }
    }
  }
}

/// One-line note, 140 characters, saved on Return.
private struct MacNoteEditor: View {
  @Binding var text: String
  let onSave: () -> Void
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Note").font(.headline)
      TextField("One line for future you", text: $text)
        .textFieldStyle(.roundedBorder)
        .focused($focused)
        .onChange(of: text) { _, new in
          if new.count > ItemProgressRecord.maxNoteLength {
            text = String(new.prefix(ItemProgressRecord.maxNoteLength))
          }
        }
        .onSubmit(onSave)
      HStack {
        Text("\(text.count) / \(ItemProgressRecord.maxNoteLength)")
          .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        Spacer()
        Button("Save", action: onSave).keyboardShortcut(.defaultAction)
      }
    }
    .padding()
    .frame(width: 320)
    .onAppear { focused = true }
  }
}

// MARK: - Cards

private struct CardsTab: View {
  let item: KataCore.LibraryItem
  let topic: Topic
  let selected: String?
  @Binding var codeMode: CodeViewMode
  let select: (String) -> Void
  let startPractice: () -> Void
  let openKata: () -> Void

  @Environment(MacAppModel.self) private var model
  @Environment(AppSettings.self) private var settings

  var body: some View {
    let cards = item.item.cards
    let card = cards.first { $0.role == selected } ?? cards.first
    VStack(spacing: 0) {
      RoleBar(
        pages: cards.map { c in
          RoleBar.Page(
            id: c.role, symbol: topic.roles[c.role]?.symbol ?? "square",
            title: topic.roles[c.role]?.title ?? c.role)
        },
        selection: card?.role, select: select)
      Divider()
      if let card {
        page(card, isLast: card.role == cards.last?.role)
          .id(card.role)
          .transition(.opacity)
      }
    }
    .animation(.smooth(duration: 0.2), value: card?.role)
  }

  @ViewBuilder
  private func page(_ card: Card, isLast: Bool) -> some View {
    let spec = topic.roles[card.role]
    let hasExercises = !item.item.exercises.isEmpty
    switch card.content {
    case .code(let code):
      VStack(spacing: 8) {
        HStack {
          heading(spec, card.role)
          Spacer()
          if !WalkthroughState(card: code).isEmpty {
            CodeModePicker(mode: $codeMode).frame(width: 220)
          }
        }
        .padding(.horizontal, MacLayout.pageMargin)
        CodeCardView(
          card: code, fontSize: settings.codeFontPoints, showLineNumbers: settings.showLineNumbers,
          mode: $codeMode)
      }
      .frame(maxWidth: 900)
      .frame(maxWidth: .infinity)
      .padding(.top, 14)
      .boundedHeight()
      .overlay(alignment: .bottomTrailing) {
        if isLast && hasExercises { practiceButton.padding(20) }
      }
    default:
      MacPage {
        VStack(alignment: .leading, spacing: 18) {
          heading(spec, card.role)
          cardContent(card)
          if isLast && hasExercises {
            practiceButton.padding(.top, 8)
          }
        }
      }
    }
  }

  private func heading(_ spec: RoleSpec?, _ role: String) -> some View {
    Label(spec?.title ?? role, systemImage: spec?.symbol ?? "square")
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
      .accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder
  private func cardContent(_ card: Card) -> some View {
    switch card.content {
    case .text(let blocks):
      TextCardView(blocks: blocks, codeFontSize: max(12, settings.codeFontPoints - 1))
    case .code: EmptyView()
    case .diagram(let diagrams): DiagramCardView(diagrams: diagrams)
    case .lists(let groups): ListsCardView(groups: groups)
    case .comparison(let rows):
      ComparisonCardView(
        rows: rows, topic: topic, hasContent: { model.hasContent($0) },
        onOpen: { model.open($0) })
    case .references(let entries): ReferencesCardView(entries: entries)
    }
  }

  private var practiceButton: some View {
    Button(action: startPractice) {
      Label("Practice this pattern", systemImage: "figure.mind.and.body")
        .font(.body.weight(.semibold))
        .frame(minHeight: 32)
        .padding(.horizontal, 8)
    }
    .buttonStyle(.glassProminent)
  }
}

/// A strip of role symbols with chevrons: the page indicator and picker of the cards.
private struct RoleBar: View {
  struct Page: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
  }

  let pages: [Page]
  let selection: String?
  let select: (String) -> Void

  private var index: Int { pages.firstIndex { $0.id == selection } ?? 0 }

  var body: some View {
    HStack(spacing: 6) {
      Button { move(-1) } label: { Image(systemName: "chevron.left") }
        .disabled(index == 0)
        .help("Previous card (⌘[)")
        .accessibilityLabel("Previous card")
      ForEach(Array(pages.enumerated()), id: \.element.id) { i, page in
        let isOn = page.id == selection
        Button { select(page.id) } label: {
          HStack(spacing: 6) {
            Image(systemName: page.symbol)
              .font(.system(size: 14, weight: isOn ? .semibold : .regular))
            if isOn { Text(page.title).font(.subheadline.weight(.medium)) }
          }
          .padding(.horizontal, isOn ? 12 : 9)
          .frame(height: 30)
          .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
          .background { if isOn { Capsule().fill(.tint.opacity(0.14)) } }
          .contentShape(.capsule)
        }
        .help("\(page.title) (⌥⌘\(i + 1))")
        .accessibilityLabel(page.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
      }
      Button { move(1) } label: { Image(systemName: "chevron.right") }
        .disabled(index >= pages.count - 1)
        .help("Next card (⌘])")
        .accessibilityLabel("Next card")
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .animation(.smooth(duration: 0.2), value: selection)
  }

  private func move(_ delta: Int) {
    let next = min(max(index + delta, 0), pages.count - 1)
    select(pages[next].id)
  }
}
