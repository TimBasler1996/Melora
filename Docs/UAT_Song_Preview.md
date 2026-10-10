# UAT — 30-Second Song Preview

Build 10 / commit `377a25f`. The snippet is resolved from the iTunes Search API first and Deezer as fallback (`Services/TrackPreviewService.swift`), played by the `PreviewPlayer` singleton (`Services/PreviewPlayer.swift`), and surfaced on two places: the album thumbnail of a Discover card (`DiscoverCardView`) and the big cover in the song sheet (`DiscoverTrackSheet`).

These tests are written from the product promise, not from the code: **instant, never a dead tap, and it must never cost the user their own music or their live session.** Testers should verify the claims about Spotify (broadcast survives a pause, Spotify resumes afterwards) rather than assume them.

Device requirements: a real iPhone (iOS 18) with the Spotify app installed and a Premium account connected in Melora, a second account broadcasting so Discover has cards, and a hardware silent switch. The simulator cannot be used for the audio-session and broadcast tests (PREV-08, PREV-09).

---

## PREV-01 — The Discover card thumbnail plays the snippet, and a second tap stops it

**Preconditions:** Logged in, Discover shows at least one card with a well-known mainstream track (a plain studio title, no remix suffix). Device volume audible, nothing playing on Spotify.

**Steps:**
1. Open Discover and locate a card.
2. Tap the square album thumbnail on the right of the card (not the title, not the row).
3. Watch the thumbnail while audio starts.
4. Let it play for about 5 seconds.
5. Tap the same thumbnail again.

**Expected:** The snippet starts within about a second (a brief spinner in the corner badge at most), the badge turns into a pause mark and a progress ring runs around the thumbnail; the second tap stops the audio immediately, the ring disappears and the badge returns to the play mark. The card never expands and the song sheet never opens.

---

## PREV-02 — The sheet cover plays the snippet; the ring tracks progress and resets at the end

**Preconditions:** As PREV-01. A track that does have a preview (confirmed in PREV-01).

**Steps:**
1. In Discover, tap the song title of the card to open the song sheet.
2. Tap the large 220pt cover.
3. Watch the ring around the cover for the full snippet (~30 s) without touching anything.
4. Observe the cover for 2 seconds after the audio stops.

**Expected:** Audio starts on the first tap, a play/pause badge sits on the cover and the ring fills smoothly and monotonically from empty to full over the snippet; when the snippet ends on its own the audio stops, the ring disappears and the badge shows play again — ready for a second tap, with no stuck ring, no half-filled arc and no error line.

---

## PREV-03 — Starting a second preview stops the first

**Preconditions:** Discover shows at least two cards whose tracks both have previews.

**Steps:**
1. Tap the album thumbnail of card A and let it play for ~5 seconds.
2. While A is playing, tap the album thumbnail of card B.
3. Listen and watch both cards.
4. Now open card B's song sheet and tap its large cover while the card preview is running.

**Expected:** Only ever one snippet is audible: starting B cuts A off instantly, A's ring and pause badge disappear while B gets them, and no overlap or double audio is heard — the same holds when the second tap happens on the sheet instead of a card.

---

## PREV-04 — "Play on Spotify" takes over from the snippet

**Preconditions:** Spotify Premium connected, Spotify app installed and recently opened (an active device exists). Song sheet open on a track with a preview.

**Steps:**
1. Tap the cover to start the snippet.
2. After ~5 seconds, tap the primary "Play on Spotify" button.
3. Listen for the hand-over and watch the cover.
4. Read the status line under the button.

**Expected:** The snippet stops the moment the button is tapped (ring and pause badge gone) and the full track starts on the user's Spotify, with the status line confirming "Now playing on your Spotify" — never both at once, and never a snippet continuing under the real song.

---

## PREV-05 — Dismissing the sheet stops the preview

**Preconditions:** Song sheet open on a track with a preview.

**Steps:**
1. Tap the cover to start the snippet.
2. While it is playing, dismiss the sheet by swiping it down.
3. Listen for 3 seconds after the sheet is gone.
4. Repeat, dismissing with the close (X) button instead.
5. Repeat once more, starting the snippet from the sheet and then dismissing it, and check the Discover card underneath.

**Expected:** The audio stops as the sheet leaves the screen in all three cases, nothing keeps playing behind Discover, and the card underneath shows no pause badge or ring for that track.

---

## PREV-06 — No preview exists: honest on both surfaces, and the failed lookup is not repeated

**Preconditions:** A broadcast whose track has no match in either catalogue — an obscure local release, a bootleg, a podcast-like upload or a region-locked title. (If no such card is naturally present, enable Airplane Mode only for the lookup variant; the real no-match case is preferred.) App freshly launched so no cached lookup exists.

**Steps:**
1. In Discover, tap the album thumbnail of that card.
2. Observe what happens on the card (audio, ring, navigation).
3. In the opened song sheet, tap the large cover.
4. Read the status line and look at the cover badge.
5. Dismiss the sheet, tap the same thumbnail again, and time how long it takes to react.
6. Reopen the sheet and tap the cover a second time.

**Expected:** The tap is never dead — the card falls back to opening the song sheet, the sheet shows "No preview for this one — open it in Spotify." and then hides the play badge on the cover entirely; on the repeat taps the answer comes back instantly with no spinner and no new network delay, because the empty result was cached for the session.

---

## PREV-07 — Audio session: silent switch, an incoming call, and Spotify afterwards

**Preconditions:** Physical device with the hardware silent switch, a second phone to call from, Spotify Premium connected with a track playing on the device.

**Steps:**
1. Start a song in the Spotify app, return to Melora, and tap a thumbnail to start a snippet. Note whether Spotify's music pauses.
2. Flip the hardware silent switch to silent while the snippet plays.
3. Stop the snippet (tap again) and check whether Spotify's music picks up again on its own.
4. Start a snippet again, then have the second phone call this device; accept the call.
5. End the call and return to Melora.
6. Inspect the thumbnail/cover state and tap it again.

**Expected:** The snippet is audible even with the silent switch on and it interrupts the user's Spotify cleanly; when the snippet is stopped or ended Spotify resumes playing by itself, an incoming call silences the snippet, and after the call the preview UI is in a consistent state (either stopped with a play badge, or still showing progress) and a single tap always gets back to a working play/stop — no silent player and no stuck pause badge.

---

## PREV-08 — The user's own live broadcast survives a 30-second preview

**Preconditions:** This device is broadcasting (live session active, Spotify playing a track, the ripple/Live marker visible). A second device logged in as another user, watching this user in Discover.

**Steps:**
1. Confirm on the second device that this user appears as Live with the right track.
2. On the broadcasting device, open Discover and play a full 30-second snippet from a card — long enough that the user's own Spotify stays paused for the whole snippet.
3. Watch the own live indicator (Now Playing / profile) throughout.
4. When the snippet ends, wait two Spotify poll cycles (~30 s) and re-check the second device.
5. Repeat with three snippets back to back (~90 s of paused Spotify).

**Expected:** The live session stays alive the whole time — the Live marker never drops, no "You went offline: nothing has been playing for a while" message or notification appears, the broadcast on the second device keeps reporting the same track, and after the snippet the user's own track continues and keeps being broadcast.

---

## PREV-09 — Offline and slow network: the lookup gives up in time

**Preconditions:** App launched and warm, a track whose preview has NOT been looked up yet in this session (restart the app to be sure). Network Link Conditioner available, or Airplane Mode.

**Steps:**
1. Enable Airplane Mode, open Discover and tap the album thumbnail of an untouched track. Time the reaction.
2. Observe what the card does, then what the sheet says.
3. Disable Airplane Mode, force-quit and relaunch the app, and set Network Link Conditioner to "Very Bad Network" (or 100% loss).
4. Tap the cover in the song sheet of an untouched track and time how long the spinner runs.
5. Restore normal network and tap the same cover again.

**Expected:** The app never hangs or freezes — offline, the lookup fails fast and the surface behaves exactly like a no-match (card opens the sheet, sheet shows the "no preview" line, spinner never longer than ~8–10 s); back online the same tap must be able to find and play the snippet, which also confirms the failure was not cached as a permanent "no".

---

## PREV-10 — Nothing left behind when the view disappears mid-playback

**Preconditions:** Xcode attached (Debug build, Memory Graph / Instruments Leaks available), Discover populated with several previewable tracks.

**Steps:**
1. Start a snippet from a Discover card, then immediately navigate away (switch to another tab, then back) while the ring is still running.
2. Start a snippet from the song sheet, then dismiss the sheet before the first second has elapsed.
3. Start a snippet, then background the app with the home gesture, wait 10 s, and return.
4. Repeat steps 1–3 about ten times, scrolling Discover between runs.
5. Capture a memory graph and check for leaked `PreviewPlayer`, `AVPlayer`, `AVPlayerItem` or lingering time/end observers; also watch the Xcode console for `AVPlayer` or audio-session warnings.
6. Finally, play one full snippet to the end.

**Expected:** Audio always stops with the view that started it, memory stays flat across the ten cycles with no accumulating `AVPlayer`/`AVPlayerItem` instances or retained observers, the console stays free of audio-session errors, and the final snippet still plays and completes normally.

---

## Status

| UAT | Tester | Device / OS | Date | Result (pass/fail) | Notes |
| --- | --- | --- | --- | --- | --- |
| PREV-01 |  |  |  |  |  |
| PREV-02 |  |  |  |  |  |
| PREV-03 |  |  |  |  |  |
| PREV-04 |  |  |  |  |  |
| PREV-05 |  |  |  |  |  |
| PREV-06 |  |  |  |  |  |
| PREV-07 |  |  |  |  |  |
| PREV-08 |  |  |  |  |  |
| PREV-09 |  |  |  |  |  |
| PREV-10 |  |  |  |  |  |
