import SwiftUI

@main
struct KataApp: App {
  @State private var model = AppModel.live()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .environment(model.store)
        .environment(model.settings)
        .modelContainer(model.container)
        .task {
          #if DEBUG
          await DebugLaunch.run(model)
          #endif
          await model.refreshReminders()
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { Task { await model.refreshReminders() } }
        }
    }
  }
}
