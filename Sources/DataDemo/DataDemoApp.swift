import SwiftUI

@main
struct DataDemoApp: App {
    @State private var selectedNode: DataNode?

    private let configuration = AppConfiguration.load()

    var body: some Scene {
        WindowGroup {
            RootWindowView(
                configuration: configuration,
                selectedNode: $selectedNode
            )
            .frame(minWidth: 980, minHeight: 680)
            .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
