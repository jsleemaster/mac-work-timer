import SwiftUI

@main
struct MacWorkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        _model = StateObject(wrappedValue: AppModel.shared)
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
