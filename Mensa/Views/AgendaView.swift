import SwiftUI
import Alamofire

struct AgendaView: View {
    @EnvironmentObject var navManager: NavigationManager
    @StateObject private var viewModel = AgendaViewModel()

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.monthSymbols[viewModel.currentMonth - 1].capitalized
    }

    var body: some View {
        ZStack {
            VStack {
                // --- Navigation links helper ---
                NavigationLinksHelper()
                    .environmentObject(navManager)
                
                Text("\(monthName) \(viewModel.currentYear)")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                HStack {
                    Button("Mois précédent") { viewModel.goToPreviousMonth() }
                        .disabled(viewModel.currentYear < Calendar.current.component(.year, from: Date()) ||
                                  (viewModel.currentYear == Calendar.current.component(.year, from: Date()) &&
                                   viewModel.currentMonth <= Calendar.current.component(.month, from: Date())))
                        .padding(.leading)
                    Spacer()
                    Button("Mois suivant") { viewModel.goToNextMonth() }
                        .padding(.trailing)
                }
                .padding(.bottom, 8)

                Divider()

                if viewModel.isLoading {
                    ProgressView("Chargement de l'agenda…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).multilineTextAlignment(.center).padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.activitiesGroupedByDate, id: \.date) { section in
                                // Date affichée en premier
                                Text(section.date)
                                    .font(.subheadline).bold()
                                    .foregroundColor(.gray.opacity(0.8))
                                    .padding(.horizontal)
                                    .padding(.bottom, 2)   // rapproche la date de l’activité qui suit
                                    .padding(.top, 12)     // espace plus important avant la date
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                                
                                // Activités de cette date
                                ForEach(section.activities.indices, id: \.self) { index in
                                    let activity = section.activities[index]
                                    let detailVM = ActivityDetailViewModel(activity: activity)

                                    NavigationLink(destination: ActivityDetailView(viewModel: detailVM)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(activity.title)
                                                .font(.headline)
                                                .foregroundColor(colorForRegState(activity.regState))
                                            if !activity.place.isEmpty {
                                                Text(activity.place)
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(backgroundColor(for: activity.regState))
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.activities)
                    }
                }
            }

            // Menu burger
            if navManager.showMenu {
                BurgerMenu(currentView: "agenda").environmentObject(navManager)
            }
        }
        .navigationTitle("Agenda Mensa IDF")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { withAnimation { navManager.showMenu.toggle() } }) { Image(systemName: "line.horizontal.3").imageScale(.large) }
            }
        }
        .onAppear { viewModel.fetchAgenda() }
    }

    private func colorForRegState(_ regState: Int) -> Color {
        switch regState {
        case 1: return Color(red: 0, green: 0.45, blue: 0.1)
        case 10, 11: return .orange
        default: return .blue
        }
    }

    private func backgroundColor(for regState: Int) -> Color {
        switch regState {
        case 1: return Color.green.opacity(0.25)
        case 10, 11: return Color.orange.opacity(0.25)
        default: return Color.gray.opacity(0.15)
        }
    }
}
