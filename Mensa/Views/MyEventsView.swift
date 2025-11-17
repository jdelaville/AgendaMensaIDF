import SwiftUI
import Alamofire

struct MyEventsView: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var events: [Activity] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedActivity: Activity?
    @State private var isLoadingDetail = false
    @State private var showDetail = false

    var body: some View {
        ZStack {
            VStack {
                // --- Navigation links helper ---
                NavigationLinksHelper()
                    .environmentObject(navManager)

                // --- Titre principal (identique à AgendaView) ---
                Text("Mes événements")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                Divider()

                // --- Contenu principal ---
                if isLoading {
                    ProgressView("Chargement des événements…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.date)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(event.title)
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onTapGesture {
                                    Task {
                                        await fetchActivityDetail(for: event)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- ✅ BurgerMenu superposé comme dans AgendaView ---
            if navManager.showMenu {
                BurgerMenu(currentView: "myevents").environmentObject(navManager)
            }
        }
        .navigationTitle("Agenda Mensa IDF") // même barre de navigation
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { withAnimation { navManager.showMenu.toggle() } }) {
                    Image(systemName: "line.horizontal.3")
                        .imageScale(.large)
                }
            }
        }
        .overlay {
            if isLoadingDetail {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Chargement du détail…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
        .onAppear { fetchMyEvents() }
        .background(
            Group {
                if let selectedActivity {
                    NavigationLink(
                        destination: ActivityDetailView(viewModel: ActivityDetailViewModel(activity: selectedActivity)),
                        isActive: $showDetail
                    ) { EmptyView() }
                } else {
                    EmptyView()
                }
            }
        )
    }

    // --- Récupération des événements ---
    private func fetchMyEvents() {
        guard AuthService.shared.isLoggedIn else {
            self.errorMessage = "Non connecté"
            self.isLoading = false
            return
        }

        AF.request(HTMLUtils.baseURL + "?action=iAgenda_ievenements")
            .validate()
            .responseString { response in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch response.result {
                    case .success(let html):
                        self.events = parseEvents(html: html)
                        if self.events.isEmpty {
                            self.errorMessage = "Aucun événement trouvé"
                        }
                    case .failure(let error):
                        self.errorMessage = "Erreur réseau : \(error.localizedDescription)"
                    }
                }
            }
    }

    // --- Parsing HTML de la page "Mes événements" ---
    private func parseEvents(html: String) -> [Activity] {
        let nsHTML = html as NSString
        var results: [Activity] = []

        guard let rowRegex = try? NSRegularExpression(
            pattern: #"<tr>.*?<a [^>]*href="([^\"]*)"[^>]*>(.*?)</a>.*?<td>(.*?)</td>.*?</tr>"#,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else { return [] }

        let matches = rowRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            let href = nsHTML.substring(with: match.range(at: 1))
            let title = HTMLUtils.htmlToPlainText(nsHTML.substring(with: match.range(at: 2)))
            let date = HTMLUtils.htmlToPlainText(nsHTML.substring(with: match.range(at: 3)))
            var act_id = ""
            if let idRange = href.range(of: "id=") {
                act_id = String(href[idRange.upperBound...])
            }

            results.append(
                Activity(
                    id: UUID().uuidString,
                    act_id: act_id,
                    title: title,
                    place: "",
                    date: date,
                    regState: 0
                )
            )
        }

        return results
    }

    // --- Chargement du détail ---
    private func fetchActivityDetail(for activity: Activity) async {
        isLoadingDetail = true
        errorMessage = nil
        do {
            let detailed = try await HTMLUtils.fetchActivity(by: activity.act_id)
            self.selectedActivity = detailed
            self.isLoadingDetail = false
            self.showDetail = true
        } catch {
            self.isLoadingDetail = false
            self.errorMessage = "Erreur : \(error.localizedDescription)"
            print("❌ Erreur fetchActivityDetail : \(error.localizedDescription)")
        }
    }
}
