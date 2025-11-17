import SwiftUI
import Combine

struct NavigationLinksHelper: View {
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        Group {
            NavigationLink(
                destination: AgendaView(),
                isActive: $navManager.navigateToAgenda
            ) { EmptyView() }

            NavigationLink(
                destination: MyEventsView(),
                isActive: $navManager.navigateToMyEvents
            ) { EmptyView() }

/*            NavigationLink(
                destination: LoginView(),
                isActive: $navManager.shouldLogout
            ) { EmptyView() }
*/        }
    }
}

class NavigationManager: ObservableObject {
    @Published var showMenu: Bool = false
    @Published var isLoggedIn: Bool = false
    @Published var navigateToAgenda: Bool = false
    @Published var navigateToMyEvents: Bool = false
    @Published var shouldLogout: Bool = false
}
