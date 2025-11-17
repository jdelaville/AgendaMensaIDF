import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        NavigationStack {
            if navManager.isLoggedIn {
                AgendaView().environmentObject(navManager)
            } else {
                LoginView().environmentObject(navManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
