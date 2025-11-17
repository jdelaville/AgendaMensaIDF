import SwiftUI

struct LoginView: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

//    username = "12297"
//    password = "M\",'K]95Lx9~"

    var body: some View {
        VStack(spacing: 20) {
            Image("logo_mensa")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .padding(.top, 50)

            TextField("Identifiant", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)

            SecureField("Mot de passe", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            if isLoading {
                ProgressView()
            }

            Button("Se connecter") {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let vc = window.rootViewController {
                    
                    OAuthManager.shared.authorize(from: vc) { success in
                        if success {
                            print("Utilisateur connecté !")
                            // Charger la page mensa-idf.org comme connecté
                            // par exemple relancer fetchMyEvents()
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            Button {
                authenticateWithFaceID()
            } label: {
                Label("Se connecter avec Face ID", systemImage: "faceid")
            }
            .padding(.top, 10)

            Spacer()
        }
        .padding()
    }

    private func login() {
        isLoading = true
        errorMessage = nil
        AuthService.shared.login(username: username, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    navManager.isLoggedIn = true
                } else {
                    errorMessage = error
                }
            }
        }
    }

    private func authenticateWithFaceID() {
        isLoading = true
        errorMessage = nil
        AuthService.shared.authenticateWithBiometrics { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    navManager.isLoggedIn = true
                } else {
                    errorMessage = error
                }
            }
        }
    }
}
