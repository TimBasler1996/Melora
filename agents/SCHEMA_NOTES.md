# Schema notes for the agent scripts

Derived from the code on `Dev3` (commit 3f6a1bf), not from memory. Sources:
`Docs/Firebase_Schema.txt`, `firestore.rules`, `firestore.indexes.json`,
`functions/src/index.ts`, `Features/Discover/Services/DiscoverService.swift`,
`Features/Discover/ViewModels/DiscoverViewModel.swift`,
`Services/BroadcastManager.swift`, `Services/UserApiService.swift`,
`Services/LikeApiService.swift`, `Services/ChatApiService.swift`,
`Services/FollowApiService.swift`, `Model/*.swift`.

**The spec names `seedTestUsers.js`, `refreshBroadcasts.js` and
`patchPhotos.js`. None of them exist in this repository (no `*.js` outside
`functions/`), and there is no `serviceAccount.json`.** The 30 static test
users were created some other way; the app treats users with a
`deletionRequestedAt` field as absent, which is how they were retired.
Everything below therefore comes from the app and the functions.

## Answers to the five questions

| Question | Answer |
|---|---|
| Collections, messages nested or flat? | `users/{uid}`, `users/{uid}/likesReceived/{id}`, `users/{uid}/likesGiven/{id}`, `broadcasts/{uid}`, `conversations/{id}`, `conversations/{id}/messages/{id}`, `follows/{a_b}`, `blocks/{a_b}`, `reports/{id}`. Messages are a **subcollection** of the conversation. |
| Position: GeoPoint, lat/lng or geohash? | Two Doubles: `latitude`, `longitude` on `broadcasts/{uid}` (the reader also accepts a `location` GeoPoint, but nothing writes one). No geohash; distance is computed on the client from all loaded broadcasts. On `users/{uid}` it is a map `lastLocation: {latitude, longitude}`. Clients snap to a 0.0025° grid (~275 m) before writing (`LocationPoint.fuzzed()`). |
| Broadcast timestamp field and type | `updatedAt` (Firestore **Timestamp**, server time) is the field the reader queries: `where updatedAt > now - 24 h`. `broadcastedAt` is set once at session start, `endedAt` on stop. Never a Number. |
| How is a broadcast ended? Flag or age? | Both. `isLive: false` + `endedAt` on a clean stop (document kept for the "Recently live" list). Age also matters: Discover shows a doc as live only if `isLive == true` **and** `updatedAt` is younger than 5 min (`DiscoverViewModel.maxLiveAge`); the `expireStaleBroadcasts` function marks live docs older than 10 min as ended every 10 min and deletes docs older than 24 h. |
| How does a match come about? | There is **no match document and no function that creates one.** The social loop was redesigned: a *like* is a signal (`likesReceived` doc, status stays `pending` unless the receiver reacts), a *follow* is one-way (`follows` doc), a *message* is a request: the sender creates `conversations/{id}` with `status: "pending"`, `initiatorId`, and the first message; the recipient's client sets `status: "accepted"` or `"rejected"` (and mirrors that status onto the linked like when `createdFromLikeId` is set). Cloud Functions only send pushes and maintain counters. |

## Exact write shapes the agents reproduce

### users/{uid} (must pass `DiscoverService.fetchDiscoverUser`)
Required to be visible: `profileCompleted: true`, non-empty `firstName`, no
`deletionRequestedAt`. Age is read from `age` (Int) or derived from
`birthday` (Timestamp). Photo priority: `heroPhotoURL` → `profilePhotoURL`
→ `photoURLs[0]` → `spotifyAvatarURL` → `avatarURL`.

Agents write: `firstName, lastName, displayName, firstNameLower,
lastNameLower, displayNameLower, birthday (Timestamp), gender, city,
countryCode: "CH", lookingFor, photoURLs: [url], heroPhotoURL,
profileCompleted: true, completedAt, createdAt, updatedAt, isBroadcasting:
false, spotifyTaste {topArtists, topTracks, playlists: [], updatedAt}` (built
from the track pool), `notifyLikes/notifyMessages/notifyFollowers: false`
(no `fcmToken` anyway, so functions never push to an agent), plus the two
agent markers `isAgent: true` and `agentId: <uid>`.

Presence while live (same keys `UserApiService` writes): `isBroadcasting:
true`, `currentTrack: {id, title, artist, album, artworkURL, durationMs}`,
`lastLocation: {latitude, longitude}`, `lastActiveAt`, `updatedAt`. On stop:
`isBroadcasting: false`, `currentTrack` and `lastLocation` deleted,
`broadcastMinutesTotal` incremented.

### broadcasts/{uid}
Document id = uid. Keys as in `BroadcastManager.upsertBroadcast`:
`userId, trackId, trackTitle, trackArtist, trackAlbum, trackArtworkURL,
spotifyTrackURL ("https://open.spotify.com/track/<id>"), latitude,
longitude, isLive: true, endedAt: delete, updatedAt: serverTimestamp,
broadcastedAt: serverTimestamp (first write of a session)` + `agentId`.
Stop (`clearServerState`): `isLive: false, latitude/longitude deleted,
endedAt, updatedAt`.

Reader tolerance: `trackAlbum`, `trackArtworkURL`, `spotifyTrackURL` and the
position are optional; `userId, trackId, trackTitle, trackArtist` are
required or the doc is skipped silently.

### users/{to}/likesReceived/{likeId} + users/{from}/likesGiven/{likeId}
Same id, same payload, written in one batch (`LikeApiService`):
`fromUserId, toUserId, trackId, trackTitle, trackArtist, trackAlbum,
trackArtworkURL, createdAt (Timestamp), placeLabel, latitude, longitude,
fromUserDisplayName, fromUserAvatarURL, sessionId: null, message (optional,
≤160), status: "pending"` + `agentId`. Rules the client enforces and the
agents copy: one like per (from, to, track); no new like to someone who
declined one before; auto `status: "accepted"` when the receiver accepted an
earlier like from the same person. `onLikeCreated` increments
`likesReceivedCount` on the receiver and pushes when they have a token.

Accepting/declining a like = updating `status` + `respondedAt` on **both**
docs; `onLikeAccepted` (on `likesGiven`) pushes "X accepted your like" to
the liker.

### conversations/{id} and messages
`id = [uidA, uidB].map(lowercase).sort().join("_")`. Request creation
(`createRequestConversation` / `deliverLikeMessage`): `participantIds: [a, b],
createdAt, updatedAt, status: "pending", initiatorId, createdFromLikeId?,
createdFromTrackId?`. Every message (`appendMessage`): `senderId, text,
type: "text", createdAt: serverTimestamp, replyTo?, track?` and on the
conversation `lastMessageText, lastMessageAt, lastMessageSenderId,
updatedAt`. Read marker: `lastReadAt.<uid>`. `onNewChatMessage` pushes the
text to the other participant, except for the first message of a pending
request (the like push already covered it).

The inbox lists `conversations where participantIds array-contains me
order by updatedAt desc` and sorts rows by `status`/`initiatorId` into
chats, requests received, requests sent. Accept/decline is a client write
of `status` (only the non-initiator may change it).

### follows/{followerId_followingId}
`followerId, followingId, createdAt` + `agentId`. `onFollowCreated` pushes.

### Storage
`userPhotos/{uid}/photo_0.jpg` and `hero_photo.jpg`, `image/jpeg`. Agents
upload with custom metadata `agentId` and a `firebaseStorageDownloadTokens`
token so the URL has the same shape the app produces
(`https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<path>?alt=media&token=…`).

### Auth
Anonymous auth in the app. Agents get Admin-created accounts with the fixed
uid `agent_<handle>` and `disabled: true` (nobody can ever sign in as one).
The uid prefix is a convenience; the `agentId` field is the contract.

## Decisions where the spec and the code disagree

1. **"Like → match → chat" does not exist.** Adapted behaviour (§3.6):
   - agents *like* visible broadcasts (like doc, status pending);
   - agents *accept* pending likes they received, with the spec's 70 % /
     5–90 min delay, by flipping `status` on both like docs (this is the
     path that triggers the "accepted your like" push);
   - agents *answer message requests* they received (conversation
     `status: pending`, not initiator): accept 70 %, decline 10 %, ignore
     20 %, after the same delay; on accept the linked like is accepted too,
     as the client does;
   - agents occasionally *follow* people they liked, and with a small
     probability *send a message request* to a real user after a like,
     using a short canned opener in their language (no LLM in the tick);
   - agent-to-agent likes and follows are allowed; agent-to-agent message
     requests are not created (nothing in the app would show them).
2. **`maxBroadcastAge` is 5 min on the client and 10 min in the sweeper**,
   so the tick is 2 min (spec §3.1) and a live agent refreshes `updatedAt`
   every tick.
3. **Positions:** the spec asks for a 40–150 m offset per session and no two
   sessions on identical coordinates. The app snaps to a ~275 m grid, which
   would collapse those offsets. Agents write the un-snapped offset position
   (decision: follow the spec; the distance bands in the app cope with any
   precision, and no real person is behind these positions).
4. **No analytics** (§1.3): agents never run the app; Admin SDK writes do not
   produce Analytics events. Nothing to do.
5. **Kill switch** lives at `config/agents` → `{enabled: Bool}`; the tick and
   the chat listener read it every loop and stop when it is false. The doc is
   tagged `agentId: "system"` so the purge removes it too.
6. **Purge index:** `agentId` needs a collection-group index on
   `likesReceived`, `likesGiven` and `messages` for the collection-group
   purge query. Added to `firestore.indexes.json` (deploy with
   `firebase deploy --only firestore:indexes`). Until it is deployed the purge
   falls back to per-uid queries (`fromUserId == uid`, `toUserId == uid`,
   participant conversations, recursive delete of the user doc), which cover
   the same documents.
7. **Runtime state** of the tick (current session, sessions today, pending
   decisions) is kept in `agentState/{uid}` documents, tagged with `agentId`,
   so a restart continues where it left off and the purge removes them.
8. **Track pool:** built once from the Spotify Search API per genre cluster
   (client-credentials token or a pasted user token), never at runtime.
   The editorial-playlist endpoints are no longer available to development
   apps, so playlists are not used as the source.
