# SocialSound

SocialSound is an iOS app built with SwiftUI.

## Core idea
- Users broadcast the music they are currently listening to
- Nearby users discover each other through music
- Profiles are lightweight, modern, and inspired by apps like Hinge / Spotify

## Tech stack
- SwiftUI (iOS 18+)
- Architecture: MVVM
- Firebase: Auth, Firestore, Storage
- Spotify integration (connected during onboarding)

## Navigation
Bottom tab bar:
- Now
- Discover
- Chats
- Profile

## Important constraints
- Do NOT use "+" in file names
- Do NOT break SwiftUI previews
- Avoid heavy rebuild/run loops (Xcode Previews are important)
- All ViewModels are annotated with `@MainActor`
- UX quality is more important than speed


