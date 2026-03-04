import UIKit
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

/// Handles APNs device token registration and FCM token refresh.
/// FCM tokens are stored in Firestore at users/{uid}/fcmToken so Cloud Functions
/// can look them up when sending push notifications.
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - APNs token forwarding

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - FCM token refresh

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("📱 [FCM] Token received: \(token.prefix(20))…")
        storeFCMToken(token)
    }

    private func storeFCMToken(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            // Not signed in yet – listen for auth state and retry
            var handle: AuthStateDidChangeListenerHandle?
            handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let user else { return }
                if let handle { Auth.auth().removeStateDidChangeListener(handle) }
                self?.uploadToken(token, for: user.uid)
            }
            return
        }
        uploadToken(token, for: uid)
    }

    private func uploadToken(_ token: String, for uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "fcmToken": token
        ], merge: true) { error in
            if let error {
                print("❌ [FCM] Failed to store token: \(error.localizedDescription)")
            } else {
                print("✅ [FCM] Token stored for user \(uid)")
            }
        }
    }
}
