import SwiftUI

@main
struct MensaApp: App {
    @StateObject private var navManager = NavigationManager()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(.systemBackground).ignoresSafeArea() // fond uniforme, pas de noir

                if showLaunch {
                    LaunchView(isActive: $showLaunch)
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                        .environmentObject(navManager)
                }
            }
        }
    }
}
