import SwiftUI

@main
struct KataMacApp: App {
  @State private var model = MacAppModel.live()

  var body: some Scene {
    WindowGroup(id: "main") {
      MacRootView()
        .environment(model)
        .environment(model.store)
        .environment(model.settings)
        .modelContainer(model.container)
        .task {
          #if DEBUG
          await DebugLaunch.run(model)
          await DebugLaunch.snapshotIfRequested()
          #endif
        }
    }
    .defaultSize(width: 1120, height: 760)
    .windowResizability(.contentMinSize)
    .commands {
      MacCommands(model: model)
      SidebarCommands()
      TextEditingCommands()
    }

    Settings {
      MacSettingsView()
        .environment(model)
        .environment(model.store)
        .environment(model.settings)
    }
  }
}
