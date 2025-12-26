import Foundation

/// Manages the user's broadcasting state and current active session.
/// Uses SessionApiService as a simple cloud backend.
@MainActor
final class BroadcastManager: ObservableObject {
    
    /// Whether the user is currently broadcasting an active session.
    @Published private(set) var isBroadcasting: Bool = false
    
    /// The current active session if broadcasting, otherwise `nil`.
    @Published private(set) var activeSession: Session?
    
    /// The app-level user that is used when creating sessions.
    /// This should be set from Spotify (or Profile) once we know who the user is.
    @Published private(set) var currentUser: User
    
    /// Session backend (Firestore).
    private let sessionService = SessionApiService.shared
    
    // MARK: - Init
    
    init() {
        // Default placeholder user; will be overridden via updateCurrentUser(_:)
        #if targetEnvironment(simulator)
        currentUser = User(
            id: "sim-\(UUID().uuidString)",
            displayName: "Guest (Simulator)",
            avatarURL: nil,
            age: nil,
            countryCode: nil
        )
        #else
        currentUser = User(
            id: "device-\(UUID().uuidString)",
            displayName: "Guest",
            avatarURL: nil,
            age: nil,
            countryCode: nil
        )
        #endif
    }
    
    // MARK: - User
    
    /// Updates the current user, e.g. after Spotify login or profile setup.
    func updateCurrentUser(_ user: User) {
        self.currentUser = user
    }
    
    // MARK: - Broadcasting
    
    /// Starts a new broadcast session with the given track and location.
    /// If `currentTrack` or `location` are `nil`, fallback defaults are used.
    func startBroadcasting(currentTrack: Track?, location: LocationPoint?) {
        guard isBroadcasting == false else { return }
        
        let track = currentTrack ?? Track(
            id: "unknown-track",
            title: "Unknown Track",
            artist: "Unknown Artist",
            album: nil,
            artworkURL: nil
        )
        
        let loc = location ?? LocationPoint(latitude: 47.0, longitude: 8.0)
        let user = currentUser
        
        Task {
            do {
                // 1) Session in Firestore anlegen
                let session = try await sessionService.createSession(
                    user: user,
                    track: track,
                    location: loc
                )
                self.activeSession = session
                self.isBroadcasting = true
                print("✅ Broadcast started with session ID: \(session.id)")
                
                // 2) ERSTER TRACK-EINTRAG IN DER HISTORY
                try await sessionService.appendPlayedTrack(
                    for: session.id,
                    track: track,
                    location: loc
                )
                
            } catch {
                print("❌ Failed to create broadcast session: \(error)")
            }
        }
    }
    
    /// Stops the current broadcast session, if any.
    func stopBroadcasting() {
        guard isBroadcasting == true, let session = activeSession else { return }
        
        Task {
            do {
                // Letzten Track-Eintrag sauber beenden
                try await sessionService.closeLastPlayedTrackIfNeeded(for: session.id)

                
                // Session als inactive markieren
                try await sessionService.endSession(id: session.id)
                print("✅ Broadcast ended for session ID: \(session.id)")
            } catch {
                print("❌ Failed to end broadcast session: \(error)")
            }
            
            self.activeSession = nil
            self.isBroadcasting = false
        }
    }
    
    // MARK: - Live updates
    
    /// Updates the track of the active session and sends it to the session service.
    /// Außerdem wird die Track-History aktualisiert (alter Track endet, neuer Track beginnt).
    func updateTrack(_ newTrack: Track) {
        guard var session = activeSession else { return }
        session = session.updating(track: newTrack)
        self.activeSession = session
        
        Task {
            do {
                // 1) Session-Daten (aktueller Track) updaten
                _ = try await sessionService.updateSession(session)
                print("🎵 Updated session \(session.id) with new track \(newTrack.title)")
                
                // 2) Track-History aktualisieren: alter Track enden, neuen Track starten
                try await sessionService.appendPlayedTrack(
                    for: session.id,
                    track: newTrack,
                    location: session.location
                )
                
            } catch {
                print("❌ Failed to update session track: \(error)")
            }
        }
    }
    
    /// Updates the location of the active session and sends it to the session service.
    func updateLocation(_ newLocation: LocationPoint) {
        guard var session = activeSession else { return }
        session = session.updating(location: newLocation)
        self.activeSession = session
        
        Task {
            do {
                _ = try await sessionService.updateSession(session)
                print("📍 Updated session \(session.id) with new location \(newLocation.latitude), \(newLocation.longitude)")
            } catch {
                print("❌ Failed to update session location: \(error)")
            }
        }
    }
}
