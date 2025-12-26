import Foundation
import FirebaseAuth

enum FirebaseAuthBootstrap {
    
    /// Stellt sicher, dass es einen eingeloggten Firebase-User gibt.
    /// Falls noch keiner vorhanden ist, wird anonym eingeloggt.
    static func ensureFirebaseUser() {
        // Wenn schon ein User existiert → nichts tun
        if let user = Auth.auth().currentUser {
            print("✅ Firebase user already signed in: \(user.uid)")
            return
        }
        
        // Anonym einloggen
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("❌ Firebase anonymous auth failed: \(error)")
                return
            }
            
            if let user = result?.user {
                print("✅ Firebase anonymous user signed in: \(user.uid)")
            } else {
                print("⚠️ Firebase anonymous auth returned no user")
            }
        }
    }
}
