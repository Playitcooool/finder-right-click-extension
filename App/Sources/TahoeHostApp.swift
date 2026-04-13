import SwiftUI

@main
struct TahoeHostApp: App {
    @StateObject private var state = TahoeAppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
        .windowResizability(.contentSize)
    }
}
