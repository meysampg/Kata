import KataCore
import SwiftUI

struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    TabView(selection: $model.selectedTab) {
      Tab("Today", systemImage: "sun.max", value: AppTab.today) {
        NavigationStack(path: $model.todayPath) {
          TodayView().deckDestinations()
        }
      }
      Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: AppTab.path) {
        NavigationStack(path: $model.pathPath) {
          PathView().deckDestinations()
        }
      }
      Tab("Library", systemImage: "books.vertical", value: AppTab.library) {
        NavigationStack(path: $model.libraryPath) {
          LibraryView().deckDestinations()
        }
      }
      Tab(value: AppTab.search, role: .search) {
        NavigationStack(path: $model.searchPath) {
          SearchView().deckDestinations()
        }
      }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .fullScreenCover(item: $model.practice) { request in
      PracticeSessionView(request: request)
    }
    .sheet(isPresented: $model.isSettingsPresented) {
      SettingsView()
    }
  }
}

extension View {
  /// Registers the deck destination on a stack root.
  func deckDestinations() -> some View {
    navigationDestination(for: DeckRoute.self) { route in
      ItemDeckView(route: route)
    }
  }
}

#Preview {
  RootView().environment(AppModel.preview())
}
