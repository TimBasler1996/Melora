import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

/// Handles APNs device token registration and FCM token refresh.
/// FCM tokens are stored in Firestore at users/{uid}/fcmToken so Cloud Functions
/// can look them up when sending push notifications.
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    /// Most recent FCM token. Re-uploaded whenever the signed-in user changes
    /// (first anonymous sign-in, sign-out + re-sign-in).
    private var latestFCMToken: String?
    private var authHandle: AuthStateDidChangeListenerHandle?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Register with APNs if the user already granted permission earlier.
        // The permission prompt itself is shown in context (onboarding /
        // settings), not at launch.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self, let user, let token = self.latestFCMToken else { return }
            self.uploadToken(token, for: user.uid)
        }

        return true
    }

    // MARK: - Foreground notification display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification taps → in-app navigation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            AppRouter.shared.handleNotification(userInfo: userInfo)
        }
        completionHandler()
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
        latestFCMToken = token
        if let uid = Auth.auth().currentUser?.uid {
            uploadToken(token, for: uid)
        }
        // Otherwise the auth listener uploads it once a user exists.
    }

    private func uploadToken(_ token: String, for uid: String) {
        Firestore.firestore().collection("users").document(uid).setData([
            "fcmToken": token
        ], merge: true) { error in
            if let error {
                print("❌ [FCM] Failed to store token: \(error.localizedDescription)")
            }
        }
    }
}
