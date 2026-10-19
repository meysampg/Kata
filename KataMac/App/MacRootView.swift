import KataCore
import KataStore
import KataUI
import SwiftUI

/// The main window: sidebar plus a detail stack. A review session replaces the detail pane.
struct MacRootView: View {
  @Environment(MacAppModel.self) private var model
  @FocusState private var searchFocused: Bool

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      MacSidebar()
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
    } detail: {
      ZStack {
        if let request = model.practice {
          MacPracticeView(request: request) { model.practice = nil }
            .id(request.id)
            .transition(.opacity)
        } else {
          MacDetail()
        }
      }
      .animation(.smooth(duration: 0.2), value: model.practice?.id)
    }
    .searchable(text: $model.searchQuery, prompt: "Patterns, principles, terms")
    .searchFocused($searchFocused)
    .onChange(of: model.searchQuery) { _, query in
      if !query.isEmpty, model.selection != .search { model.selection = .search }
    }
    .onChange(of: model.searchFocusTick) { _, _ in searchFocused = true }
    .frame(minWidth: 960, minHeight: 640)
  }
}

/// The detail stack for the sidebar selection.
private struct MacDetail: View {
  @Environment(MacAppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    NavigationStack(path: $model.path) {
      root
        .navigationDestination(for: MacRoute.self) { route in
          MacItemView(route: route).id(route)
        }
    }
  }

  @ViewBuilder
  private var root: some View {
    switch model.selection ?? .today {
    case .today: MacTodayView()
    case .path: MacPathView()
    case .library: MacLibraryView()
    case .category(let topic, let id): MacLibraryView(category: (topic, id))
    case .search: MacSearchView()
    case .bookmarks: MacLibraryView(bookmarksOnly: true)
    }
  }
}
