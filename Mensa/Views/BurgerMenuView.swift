import SwiftUI

struct BurgerMenu: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var localnavAgenda = false
    @State private var localnavMyEvents = false

    var currentView: String  // "agenda" ou "myevents"
    
    var body: some View {
        if navManager.showMenu {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { navManager.showMenu = false } }

            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 6) {
                        // --- Agenda IDF ---
                        Button("Agenda IDF") {
                            withAnimation { navManager.showMenu = false }
                            DispatchQueue.main.async {
                                localnavAgenda = true
                            }
                        }
                        .foregroundColor(currentView == "agenda" ? .gray : .blue)
                        .disabled(currentView == "agenda")

                        NavigationLink(
                            destination: AgendaView().environmentObject(navManager),
                            isActive: $localnavAgenda
                        ) { EmptyView() }

                        // --- Mes événements ---
                        Button("Mes événements") {
                            withAnimation { navManager.showMenu = false }
                            DispatchQueue.main.async {
                                localnavMyEvents = true
                            }
                        }
                        .foregroundColor(currentView == "myevents" ? .gray : .blue)
                        .disabled(currentView == "myevents")

                        NavigationLink(
                            destination: MyEventsView().environmentObject(navManager),
                            isActive: $localnavMyEvents
                        ) { EmptyView() }

                        // --- Se déconnecter ---
                        Button("Se déconnecter") {
                            withAnimation { navManager.showMenu = false }
                            AuthService.shared.logout {
                                DispatchQueue.main.async {
                                    navManager.isLoggedIn = false
                                }
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                Spacer()
            }
            .padding()
            .transition(.move(edge: .trailing))
        }
    }
}
