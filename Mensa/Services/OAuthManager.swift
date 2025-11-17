import Foundation
import OAuth2
import SwiftUI

class OAuthManager {
    static let shared = OAuthManager()
    
    private var oauth2: OAuth2CodeGrant
    
    private init() {
        oauth2 = OAuth2CodeGrant(settings: [
            "client_id": "mensaconnect",
            "authorize_uri": "https://auth.mensa-france.net/oauth2/authorize",
            "token_uri": "https://connect.mensa.fr/realms/mensa/protocol/openid-connect/token",
            "scope": "openid profiles email",
            "redirect_uris": ["myapp://oauth/callback"], // définir ton URL scheme
            "secret_in_body": true,
            "verbose": true,
        ])
    }
    
    func authorize(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        oauth2.authConfig.authorizeEmbedded = true
        oauth2.authorizeEmbedded(from: viewController) { authParameters, error in
            if let params = authParameters {
                print("✅ OAuth OK: \(params)")
                completion(true)
            } else {
                print("❌ OAuth error: \(error?.localizedDescription ?? "unknown")")
                completion(false)
            }
        }
    }
    
    func accessToken() -> String? {
        return oauth2.accessToken
    }
    
    func logout() {
        oauth2.forgetTokens()
    }
}
