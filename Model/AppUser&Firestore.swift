//
//  AppUser+Firestore.swift
//  SocialSound
//

import Foundation
import FirebaseFirestore

extension AppUser {

    static func fromFirestore(uid: String, data: [String: Any]) -> AppUser {

        func intValue(_ key: String) -> Int? {
            if let v = data[key] as? Int { return v }
            if let v = data[key] as? Int64 { return Int(v) }
            if let v = data[key] as? Double { return Int(v) }
            return nil
        }

        func boolValue(_ key: String) -> Bool? {
            data[key] as? Bool
        }

        func stringValue(_ key: String) -> String? {
            data[key] as? String
        }

        func ts(_ key: String) -> Date? {
            (data[key] as? Timestamp)?.dateValue()
        }

        let lastLocation: LocationPoint? = {
            guard let dict = data["lastLocation"] as? [String: Any],
                  let lat = dict["latitude"] as? Double,
                  let lon = dict["longitude"] as? Double else { return nil }
            return LocationPoint(latitude: lat, longitude: lon)
        }()

        let photoURLs: [String]? = {
            if let arr = data["photoURLs"] as? [String] { return arr }
            return nil
        }()

        return AppUser(
            uid: uid,
            spotifyId: stringValue("spotifyId") ?? "",
            displayName: stringValue("displayName") ?? "Unknown",
            avatarURL: stringValue("avatarURL"),
            avatarSource: stringValue("avatarSource"),
            age: intValue("age"),
            hometown: stringValue("hometown"),
            musicTaste: stringValue("musicTaste"),
            countryCode: stringValue("countryCode"),
            gender: stringValue("gender"),
            photoURLs: photoURLs,
            isBroadcasting: boolValue("isBroadcasting"),
            profileCompleted: boolValue("profileCompleted"),
            createdAt: ts("createdAt"),
            updatedAt: ts("updatedAt"),
            lastActiveAt: ts("lastActiveAt"),
            lastLocation: lastLocation
        )
    }
}
