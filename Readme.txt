# SocialSound

SocialSound is an iOS app built with SwiftUI.

## Core idea
- Users broadcast the music they are currently listening to
- Nearby users discover each other through music
- Profiles are lightweight, modern, and inspired by apps like Hinge / Spotify

## Tech stack
- SwiftUI (iOS 18+)
- Architecture: MVVM
- Firebase: Auth (anonymous), Firestore, Storage, Cloud Messaging, Cloud Functions
- Spotify integration (PKCE, connected during onboarding or later)

## Navigation
Bottom tab bar:
- Now
- Discover
- Chats
- Profile

## Backend
Everything server-side lives in this repo and deploys with the Firebase CLI:
- `firestore.rules`, `storage.rules` – security rules (every client write path is covered)
- `firestore.indexes.json` – composite indexes
- `functions/src/index.ts` – push notifications, search-field sync, cleanup jobs
- `hosting/` – privacy policy and terms, served at https://socialsound-5fdd9.web.app
  (linked from Settings → About via `Utils/LegalLinks.swift`)

    cd functions && npm install
    firebase deploy --only firestore,storage,functions,hosting

Schema reference: `Docs/Firebase_Schema.txt`.

## Secrets
Never commit `*.p8` keys, `functions/.env` or anything under `functions/lib`.
APNs keys are uploaded in the Firebase console (Cloud Messaging → APNs), not
stored in the repo.

## Important constraints
- Do NOT use "+" in file names
- Do NOT break SwiftUI previews
- Avoid heavy rebuild/run loops (Xcode Previews are important)
- All ViewModels are annotated with `@MainActor`
- UX quality is more important than speed
