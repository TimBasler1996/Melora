//
//  BroadcastManager.swift
//  SocialSound
//

import Foundation

@MainActor
final class BroadcastManager: ObservableObject {

    @Published private(set) var isBroadcasting: Bool = false
    @Published private(set) var currentUser: User

    private let userService: UserApiService

    init(userService: UserApiService = .shared) {
        self.userService = userService

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

    func updateCurrentUser(_ user: User) {
        self.currentUser = user
    }

    // MARK: - Broadcasting

    /// Start: marks user as broadcasting + pushes initial track + location
    func startBroadcasting(currentTrack: Track?, location: LocationPoint?) {
        guard !isBroadcasting else { return }
        isBroadcasting = true

        let uid = currentUser.id
        userService.setBroadcasting(uid: uid, isBroadcasting: true)

        if let location {
            userService.updateLastLocation(uid: uid, location: location)
        }

        // also set currentTrack (can be nil if unknown)
        userService.updateCurrentTrack(uid: uid, track: currentTrack)
    }

    /// Stop: marks user not broadcasting + clears currentTrack (optional)
    func stopBroadcasting() {
        guard isBroadcasting else { return }
        isBroadcasting = false

        let uid = currentUser.id
        userService.setBroadcasting(uid: uid, isBroadcasting: false)
        userService.updateCurrentTrack(uid: uid, track: nil)
    }

    // MARK: - Live updates

    func updateTrack(_ newTrack: Track) {
        guard isBroadcasting else { return }
        userService.updateCurrentTrack(uid: currentUser.id, track: newTrack)
    }

    func updateLocation(_ newLocation: LocationPoint) {
        guard isBroadcasting else { return }
        userService.updateLastLocation(uid: currentUser.id, location: newLocation)
    }
}

