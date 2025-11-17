import Foundation
import Combine
import SwiftUI
import Alamofire

@MainActor
class ActivityDetailViewModel: ObservableObject {
    @Published var activity: Activity
    @Published var regState: Int = 0
    @Published var registrationMessage: String?
    @Published var isProcessing = false
    @Published var hasCheckedRegistration = false
    @Published var canAddGuest = false
    @Published var guestsMaxReached = false
    
    init(activity: Activity) {
        self.activity = activity
        self.regState = activity.regState
    }

    func fetchActivityDetail() {
        guard AuthService.shared.isLoggedIn else { return }

        Task {
            do {
                let detailedActivity = try await HTMLUtils.fetchActivity(by: activity.act_id)
                self.activity = detailedActivity
                self.regState = detailedActivity.regState
                self.hasCheckedRegistration = true
            } catch {
                print("⚠️ Erreur lors du fetchActivityDetail : \(error.localizedDescription)")
                self.hasCheckedRegistration = true
                self.registrationMessage = "Impossible de charger les détails de l’activité."
            }
        }
    }

    // --- Inscription / désinscription ---
    func toggleActivityState() {
        guard AuthService.shared.isLoggedIn else {
            registrationMessage = "Non connecté"
            return
        }

        isProcessing = true
        registrationMessage = nil

        let url = HTMLUtils.baseURL + "?action=iAgenda_iactivite"
        let params: [String: Any] = [
            "action": "iAgenda_iactivite",
            "membre": AuthService.shared.username,
            "id": activity.act_id,
            "d": regState
        ]
        AF.request(url, method: .post, parameters: params)
            .validate()
            .responseString { response in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    switch response.result {
                    case .success(let html):
                        if html.contains("name=\"d\" value=\"1\"") {
                            self.regState = 1
                            self.registrationMessage = "Inscription réussie !"
                        } else if html.contains("name=\"d\" value=\"10\"") {
                            self.regState = 10
                            self.activity.guests = 0
                            self.registrationMessage = "Désinscription réussie."
                        } else if html.contains("name=\"d\" value=\"11\"") {
                            self.regState = 11
                            self.registrationMessage = "Ajouté à la liste d’attente."
                        } else {
                            self.regState = 0
                            self.activity.guests = 0
                            self.registrationMessage = "Désinscription réussie."
                        }
                    case .failure(let error):
                        self.registrationMessage = "Erreur réseau : \(error.localizedDescription)"
                    }
                }
            }
    }

    // --- Boutons ---
    func buttonLabel() -> String {
        switch regState {
        case 1: return "Se désinscrire"
        case 10: return "S’inscrire sur liste d'attente"
        case 11: return "Se désinscrire de la liste d'attente"
        case -1: return ""
        default: return "S’inscrire"
        }
    }

    func buttonColor() -> Color {
        switch regState {
        case 1: return .red
        case 10, 11: return .orange
        default: return .blue
        }
    }
}
