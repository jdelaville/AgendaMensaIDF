import SwiftUI
import Alamofire

struct AddGuestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ActivityDetailViewModel

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSubmitting = false
    @State private var message: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informations invité")) {
                    TextField("Prénom", text: $firstName)
                    TextField("Nom", text: $lastName)
                }

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(message.contains("succès") ? .green : .red)
                }

                Section {
                    Button(action: submitGuest) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Ajouter")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || isSubmitting)

                    Button("Annuler") { dismiss() }
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Inscrire un invité")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func submitGuest() {
        guard AuthService.shared.isLoggedIn else {
            message = "Non connecté"
            return
        }

        isSubmitting = true
        message = nil

        let url = HTMLUtils.baseURL + "?action=iAgenda_iactivite"
        let params: [String: Any] = [
            "action": "iAgenda_iactivite",
            "d": "9",
            "membre": AuthService.shared.username,
            "id": viewModel.activity.act_id,
            "nom_invite": lastName,
            "prenom_invite": firstName
        ]

        AF.request(url, method: .post, parameters: params)
            .validate()
            .responseString { response in
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    switch response.result {
                    case .success:
                        // --- Recharge le détail pour recalculer canAddGuest / guestsMaxReached ---
                        self.viewModel.fetchActivityDetail()
                        self.message = "\(firstName) \(lastName.uppercased()) ajouté.e avec succès."
                        self.viewModel.activity.guests += 1
                        self.viewModel.guestsMaxReached =
                            (self.viewModel.activity.guests >= self.viewModel.activity.max_guests)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    case .failure(let error):
                        self.message = "Erreur réseau : \(error.localizedDescription)"
                    }
                }
            }
    }
}
