import SwiftUI

@main
struct DexCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
