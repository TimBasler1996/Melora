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
Bottom tab bar: Discover (home, with a Go live banner) · Live (player and
the live toggle) · Inbox (Messages | Activity, one badge) · Profile. Every
avatar or name opens the person's profile.

## Identity ("Ember")
One idea: a point and the waves it sends out. `RippleMark` / `LiveRipple` /
`MeloraWordmark` (Views/Components/RippleMark.swift) are the mark, the
live indicator and the wordmark. Tokens live in `Utils/AppTheme.swift`:
Ember `#FF5A3C` for live and the one primary action, warm "vinyl" black
`#0E0C0B`, cream text `#F4EFE6`, radii 12/20. Names and UI use the system
grotesk; song titles use `AppFonts.song` (italic serif) and nothing else
does. Album covers tint Discover cards (`ArtworkColorCache`). The design
canvas: https://claude.ai/code/artifact/738ee33e-0097-4cfa-b88f-3771ac1e307b

## The social loop
Three verbs, each with one meaning:
- **Like** – react to a track someone is playing live. A signal only; the
  other person sees it in Activity and can look at your profile. Nothing to
  accept.
- **Follow** – see when someone goes live (Discover friends mode, push).
  One-way, no acceptance. Followers show up in Activity with Follow back.
- **Message** – from the Discover card or a profile. Reaches the other
  person as a message request in Chats; their first reply opens the chat.
  A declined request is invisible to the sender.

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
