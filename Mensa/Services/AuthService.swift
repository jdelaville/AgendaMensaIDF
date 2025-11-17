import Foundation
import Alamofire
import LocalAuthentication
import Security

class AuthService {
    static let shared = AuthService()
    
    private init() {}
    
    private let loginURL = "https://mensa-idf.org/index.php?action=connection"
    private let logoutURL = "https://mensa-idf.org/index.php?action=deconnection"
    
    private(set) var isLoggedIn = false
    var username: String = "" // sera utilisé comme memberID

    // MARK: - Login standard
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let parameters: Parameters = [
            "id": username,
            "pw": password
        ]
        
        AF.request(loginURL, method: .post, parameters: parameters)
            .validate()
            .responseString { response in
                switch response.result {
                case .success(let html):
                    if html.contains("Bonjour") {
                        self.isLoggedIn = true
                        self.username = username
                        // On sauvegarde les identifiants pour Face ID
                        self.saveCredentials(username: username, password: password)
                        completion(true, nil)
                    } else {
                        self.isLoggedIn = false
                        self.username = ""
                        completion(false, "Identifiants incorrects")
                    }
                case .failure(let error):
                    self.isLoggedIn = false
                    self.username = ""
                    completion(false, "Erreur réseau : \(error.localizedDescription)")
                }
            }
    }
    
    func logout(completion: @escaping () -> Void) {
        AF.request(logoutURL).response { _ in
            self.isLoggedIn = false
            self.username = ""
            completion()
        }
    }
    
    // MARK: - Face ID / Touch ID
    func authenticateWithBiometrics(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Vérifier si Face ID ou Touch ID est disponible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authentifiez-vous pour vous connecter à Mensa IDF"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                if success {
                    // Si biométrie réussie, on tente la reconnexion avec les identifiants sauvegardés
                    if let (savedUser, savedPass) = self.loadCredentials() {
                        self.login(username: savedUser, password: savedPass, completion: completion)
                    } else {
                        completion(false, "Aucun identifiant sauvegardé pour Face ID")
                    }
                } else {
                    completion(false, authError?.localizedDescription ?? "Échec de l’authentification biométrique")
                }
            }
        } else {
            completion(false, "Face ID / Touch ID non disponible sur cet appareil")
        }
    }

    // MARK: - Keychain helpers
    private func saveCredentials(username: String, password: String) {
        let credentials: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "MensaCredentials",
            kSecValueData as String: "\(username):\(password)".data(using: .utf8)!
        ]
        SecItemDelete(credentials as CFDictionary)
        SecItemAdd(credentials as CFDictionary, nil)
    }

    private func loadCredentials() -> (String, String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "MensaCredentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let creds = String(data: data, encoding: .utf8),
           let sepIndex = creds.firstIndex(of: ":") {
            let user = String(creds[..<sepIndex])
            let pass = String(creds[creds.index(after: sepIndex)...])
            return (user, pass)
        }
        return nil
    }
}
