import SwiftUI

@main
struct TahoeHostApp: App {
    @NSApplicationDelegateAdaptor(TahoeAppDelegate.self) private var appDelegate
    @StateObject private var state = TahoeAppState()
    private let requestServer = TahoeRequestServer()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
        .windowResizability(.contentSize)
    }
}
