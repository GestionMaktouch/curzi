import SwiftUI

@main
struct CurziApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .task { await model.loadRates() }
        }
    }
}
