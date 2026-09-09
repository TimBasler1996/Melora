import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// One place that turns technical errors into copy a user can act on.
/// The original error stays in the logs; screens only show the result.
enum UserFacingError {

    /// Returns a short, human sentence for `error`. `fallback` is used when
    /// nothing better is known (e.g. "Couldn’t save your profile.").
    static func message(for error: Error, fallback: String) -> String {
        let nsError = error as NSError

        // Offline / timeouts / DNS
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return "You’re offline. Check your connection and try again."
            case NSURLErrorTimedOut:
                return "That took too long. Check your connection and try again."
            default:
                break
            }
        }

        // Firestore
        if nsError.domain == FirestoreErrorDomain {
            switch FirestoreErrorCode.Code(rawValue: nsError.code) {
            case .unavailable, .deadlineExceeded:
                return "You’re offline. Check your connection and try again."
            case .permissionDenied:
                return "You don’t have permission to do that."
            case .unauthenticated:
                return "You’re not signed in yet. Try again in a moment."
            case .resourceExhausted:
                return "Melora is busy right now. Please try again in a minute."
            default:
                break
            }
        }

        // Storage
        if nsError.domain == StorageErrorDomain {
            switch StorageErrorCode(rawValue: nsError.code) {
            case .quotaExceeded, .retryLimitExceeded:
                return "Upload failed. Check your connection and try again."
            case .unauthenticated:
                return "You’re not signed in yet. Try again in a moment."
            case .unauthorized:
                return "You don’t have permission to upload that."
            default:
                break
            }
        }

        // Auth
        if nsError.domain == AuthErrors.domain {
            switch AuthErrorCode(rawValue: nsError.code) {
            case .networkError:
                return "You’re offline. Check your connection and try again."
            case .userDisabled:
                return "This account has been disabled."
            case .requiresRecentLogin:
                return "Please sign in again to do that."
            default:
                break
            }
        }

        // Spotify
        if let spotifyError = error as? SpotifyAPIError {
            switch spotifyError {
            case .noActiveDevice:
                return "Open Spotify and play something first."
            default:
                return "Couldn’t reach Spotify. Please try again."
            }
        }
        if error is SpotifyAuthError {
            return "Spotify needs to be reconnected. You can do that in Settings."
        }

        #if DEBUG
        print("⚠️ [UserFacingError] \(fallback) — \(error)")
        #endif
        return fallback
    }
}
