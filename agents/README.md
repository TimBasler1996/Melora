# Agents: virtual test users for Melora

Server-side bots that behave like people over the day: listening sessions
of a few tracks, movement between a handful of places, rest days, likes,
follows, message requests and chat replies. Testing and demo only. Design
and schema decisions: `SCHEMA_NOTES.md`; every knob: `config.js`.

Non-negotiables baked in: every document an agent writes carries
`agentId` (via `lib/firebase.js → tagged()`), Storage objects carry it as
custom metadata, `agentPurge.js` removes all of it, and agents never run the
app, so no Analytics events exist.

## Setup (once)

    cd agents
    npm install
    # Firebase console → Project settings → Service accounts → Generate new private key
    # save it as agents/serviceAccount.json (gitignored)

Deploy the purge index once: `firebase deploy --only firestore:indexes` from
the repo root.

## Order

1. `node genPersonas.js` – writes `personas.json` (already committed; re-run
   after editing the people list).
2. `SPOTIFY_CLIENT_ID=… SPOTIFY_CLIENT_SECRET=… node buildTrackPool.js` –
   writes `trackPool.json` from the Spotify Search API, once. Client id and
   secret: developer.spotify.com → app → Settings. No user login, no runtime
   quota.
3. `node seedAgents.js` – auth accounts (`agent_<handle>`, disabled), user
   documents, portraits in Storage, `config/agents {enabled: true}`. Open
   Discover on the phone: the profiles must be visible once they go live.
4. `node agentTick.js --debug` – probabilities × 12 for the first minutes,
   then `node agentTick.js` for realistic behaviour. Leave it running in a
   terminal; Ctrl-C ends the current tick cleanly.
5. `node agentPurge.js` then `node agentPurge.js --confirm` – test the purge
   once before large amounts of data exist. Re-seed afterwards.
6. `ANTHROPIC_API_KEY=… node agentChat.js` – replies in accepted chats.

## Kill switch

Firestore → `config/agents` → `enabled: false`. The tick loop ends all live
sessions and exits; the chat listener exits at once. Set it back to `true`
and restart the scripts.

## What to expect in the app

- Discover "Live now": agents within your radius while their session runs;
  "Recently live" afterwards. A session refreshes every 2 min, so an agent
  never drops out of the 5-minute live window.
- Activity: likes and follows from agents; some likes carry a message, which
  shows up as a message request in the Inbox.
- Your like or request to an agent is accepted after 5–90 min with 70 %
  probability (10 % declined, 20 % ignored), never between 01:00 and 07:00.
- Chats: answers after 1–10 min, at night not before 08:00–10:00, in the
  agent's language (Zürich/Brig German, Lausanne French).

## Dauerbetrieb

Die beiden Loops laufen als launchd-Dienste, damit sie einen Absturz, einen
Speicherkill und einen Neustart des Macs überleben:

    cp agents/com.melora.*.plist ~/Library/LaunchAgents/
    launchctl load ~/Library/LaunchAgents/com.melora.agentTick.plist
    launchctl load ~/Library/LaunchAgents/com.melora.agentChat.plist

Logs: `~/Library/Logs/melora/agentTick.log` und `agentChat.log`.
Stoppen: `launchctl unload ~/Library/LaunchAgents/com.melora.agentChat.plist`
(oder den Kill-Switch `config/agents.enabled` auf `false` setzen).

Die plists enthalten absichtlich keinen API-Schlüssel — `agentChat.js` liest
ihn aus `dashboard/daten/api_key`, wenn `ANTHROPIC_API_KEY` nicht gesetzt ist.

Vorher liefen sie von Hand im Terminal. Der Chat-Loop starb dann einmal zwei
Sekunden nach dem Start und blieb 2,5 Stunden unbemerkt tot.
