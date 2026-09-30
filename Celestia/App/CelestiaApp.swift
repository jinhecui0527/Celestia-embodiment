import SwiftUI

@main
struct CelestiaApp: App {
    @StateObject private var settings: LinkSettings
    @StateObject private var presence: PresenceEngine
    @StateObject private var link: LinkController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = LinkSettings()
        let presence = PresenceEngine()
        _settings = StateObject(wrappedValue: settings)
        _presence = StateObject(wrappedValue: presence)
        _link = StateObject(wrappedValue: LinkController(settings: settings, presence: presence))
    }

    var body: some Scene {
        WindowGroup {
            CocoaStage()
                .environmentObject(settings)
                .environmentObject(presence)
                .environmentObject(link)
                .environment(\.theme, Theme(link.tokens))
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .onAppear { link.restart() }
        }
        .onChange(of: scenePhase) { _, phase in
            link.setForeground(phase == .active)
            UIApplication.shared.isIdleTimerDisabled = phase == .active
        }
    }
}
