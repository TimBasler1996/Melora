# UAT – Discover Song Sheet

User acceptance tests for the song sheet that opens from a Discover card (`DiscoverTrackSheet`).
Tapping the cover or the song title on a Discover card opens the sheet; tapping the person's name or the chevron still expands the card.

Run these on a physical iPhone with the Melora build from this branch. Most tests need a signed-in account and at least one other user broadcasting in Discover. Tests that involve Spotify playback need the Spotify app installed.

Product intent: calm, premium, music-first. The song is the hero.

Legend for the status tables: Pass / Fail / Blocked, plus tester initials, date, and a short note.

---

## UAT-01 – Open the sheet from the cover, the title, and the card still expands

**Preconditions:** Signed in. Discover shows at least one card with a real cover. The card is collapsed.

**Steps:**
1. On a Discover card, tap the small square cover on the right.
2. Note what opens, then close it with the X in the top-right corner.
3. Tap the song title (the serif text) on the same card.
4. Close the sheet again.
5. Tap the person's name on the card.
6. Tap the chevron on the right edge of the card.

**Expected:** Steps 1 and 3 open the song sheet (light haptic on tap, card does not expand). Steps 5 and 6 expand/collapse the card in place with a short spring, and the sheet does not appear.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-02 – Header shows the song as the hero

**Preconditions:** Song sheet open for a track that has cover art, an artist, and an album.

**Steps:**
1. Look at the top of the sheet.
2. Swipe down a little inside the sheet and let go, to confirm the header does not shift or jump.
3. Open the sheet for a different card whose cover has a clearly different dominant colour.

**Expected:** A large square cover (about 220 pt) with a soft shadow sits centered under a drag indicator and an X close button; a colour glow derived from the cover fades from the top of the sheet. Under it: the song title in the serif font (large, up to two lines), the artist in a smaller semibold line, and the album in a muted footnote. The glow colour follows the cover of each song.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-03 – "Playing now by" row opens the profile

**Preconditions:** Song sheet open for a broadcast that is live (card shows "Live"), from a user with a profile photo and a distance.

**Steps:**
1. Read the row under the header.
2. Tap the row.
3. Return to Discover and open the sheet for a card that is not live (shows "Live 12 min ago" or similar).
4. Read the same row.

**Expected:** Step 1: a card row with the user's round photo, the small uppercase label "PLAYING NOW BY", the user's name, a "Live" mark with the ripple, the distance band (for example "· about 1 km"), and a chevron. Step 2: the sheet slides down, then the user's profile opens (no two sheets stacked). Step 4: the label reads "PLAYED BY" and the line shows "Live <time ago>" instead of the live mark.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-04 – Play on Spotify with an active device

**Preconditions:** Spotify is connected in Melora Settings with a recent login. The Spotify app is open on this phone (or another device) and something is playing or recently played, so Spotify has an active device.

**Steps:**
1. Open the song sheet.
2. Confirm the primary Ember (coral accent) pill button reads "Play on Spotify" with a play icon.
3. Tap it.
4. Watch the button and the line under it for about 5 seconds.
5. Switch to Spotify to confirm.

**Expected:** The button briefly shows a spinner with "Starting…", then a checkmark with "Playing on Spotify"; a status line "Now playing on your Spotify." appears under the button and fades out after a few seconds. Spotify is playing this exact track. Melora stays in the foreground.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-05 – Play on Spotify without an active device, and when not connected

**Preconditions:** Part A: Spotify connected, but the Spotify app is force-quit on every device (no active device). Part B: Spotify disconnected in Melora Settings.

**Steps:**
1. Part A: open the song sheet and tap "Play on Spotify".
2. Come back to Melora and look at the primary button.
3. Part B: disconnect Spotify in Settings, open a song sheet, and read the primary button.
4. Tap it.
5. Come back to Melora.

**Expected:** Part A: the Spotify app opens on this track (no error line shown); back in Melora the button reads "Opened in Spotify" with an arrow icon. Part B: the button reads "Open in Spotify"; tapping it opens the Spotify app on this track (or the Spotify web page if the app is not installed), and the button reads "Opened in Spotify" afterwards.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-06 – Queue the song

**Preconditions:** Spotify connected. Spotify app open and playing on this phone.

**Steps:**
1. Open the song sheet and tap "Queue" in the action row.
2. Watch the Queue icon and the line under the primary button.
3. Open Spotify and check the queue.
4. Force-quit Spotify on every device, return to Melora, and tap "Queue" again.
5. Disconnect Spotify in Melora Settings, open a song sheet, and tap "Queue".

**Expected:** Step 2: a small spinner replaces the Queue icon for a moment, then "Added to your queue." shows under the primary button and fades. Step 3: the track is next in the Spotify queue. Step 4: "Open Spotify and play something first." appears. Step 5: "Connect Spotify in Settings to use the queue." appears. No alerts or red error banners in any case.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-07 – Save to Liked Songs, and the Reconnect hint for older logins

**Preconditions:** Part A: Spotify connected with a login made on this build (includes the user-library scopes). The track is not yet in the tester's Liked Songs. Part B: an account whose Spotify login predates the library scopes (connected on an older build and never reconnected).

**Steps:**
1. Part A: open the song sheet; confirm the action row shows "Save" with a plus icon.
2. Tap "Save".
3. Close and reopen the sheet for the same song.
4. Tap "Saved".
5. Part B: on the old-login account, open a song sheet and tap "Save".
6. Tap "Reconnect" in the status line, complete the Spotify login, return to Melora, and tap "Save" again.

**Expected:** Step 2: brief spinner, then the button turns to a Ember (coral accent) checkmark "Saved" and the line "Saved to your Liked Songs." appears and fades; the track is in Liked Songs in Spotify. Step 3: the sheet opens already showing "Saved". Step 4: it returns to "Save" with "Removed from your Liked Songs.". Step 5: the sheet shows "Save"; tapping it shows the sticky line "Reconnect Spotify to save songs." with a Ember (coral accent) "Reconnect" link, no crash and no alert. Step 6: after reconnecting, Save works as in Step 2.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-08 – Like from the sheet stays in sync with the card

**Preconditions:** Signed in. A Discover card for a broadcast the tester has not liked yet.

**Steps:**
1. Expand the card (tap the name) and confirm its Like button reads "Like".
2. Open the song sheet from the cover and tap "Like" in the action row.
3. Tap "Liked" once more.
4. Close the sheet and look at the expanded card.
5. On a second, unliked card, tap "Like" on the card itself, then open its song sheet.

**Expected:** Step 2: a medium haptic, a single ripple burst spreads once from the cover (about a second, then gone), and the button becomes a red filled heart labelled "Liked". Step 3: nothing further happens (no second like, no repeated burst). Step 4: the card also shows "Liked". Step 5: the sheet opens already showing "Liked".

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-09 – Message inline, then "Open chat"

**Preconditions:** Signed in. Song sheet open for a user the tester has not messaged from Discover before.

**Steps:**
1. Tap "Message" in the action row.
2. Note where the field appears and whether the keyboard comes up.
3. With the field empty, look at the round send button; then type "Love this one".
4. Tap the send button.
5. Look at the action row, then tap the same button again.

**Expected:** Step 1–2: a rounded text field with the placeholder "Say something about the song…" slides in under the action row and takes focus (keyboard up). Step 3: the send button is grey while empty and turns Ember (coral accent) once text is typed. Step 4: the field slides away, the keyboard closes, and the button now reads "Open chat" in Ember (coral accent). Step 5: the sheet slides down and the conversation with that user opens, with the sent message visible.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-10 – Share and "Open in Spotify" footer link

**Preconditions:** Song sheet open. Spotify app installed.

**Steps:**
1. Tap "Share" in the action row.
2. Choose Copy in the share sheet, dismiss it, and paste into Notes.
3. Back in the sheet, scroll to the footer and tap "Open in Spotify" (with the Spotify icon).
4. Return to Melora.
5. On a phone without the Spotify app, repeat step 3.

**Expected:** Step 1: the iOS share sheet appears with the message "<Title> – <Artist>" and the track link. Step 2: the pasted content is an open.spotify.com track link for this song. Step 3: the Spotify app opens on this track. Step 4: the primary button reads "Opened in Spotify". Step 5: Safari opens the open.spotify.com page for the track instead.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-11 – Hide this song with undo

**Preconditions:** Discover shows at least two cards, one of which plays a song the tester wants to hide.

**Steps:**
1. Open the song sheet for that card and scroll to the bottom.
2. Tap "Hide this song".
3. Look at the Discover feed and the bottom of the screen.
4. Within 5 seconds tap "Undo" on the toast.
5. Repeat steps 1–2 and this time wait about 6 seconds without tapping.
6. Pull to refresh Discover.

**Expected:** Step 2–3: the sheet closes, the card fades out of the feed, and a dark capsule toast at the bottom reads "“<Title>” hidden" with a Ember (coral accent) "Undo". Step 4: the card returns and the toast disappears. Step 5: the toast fades on its own and the card stays hidden. Step 6: the song does not come back after refreshing.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-12 – Dismissal and the calm, premium feel

**Preconditions:** Song sheet open on a card with cover art. Spotify connected.

**Steps:**
1. Swipe the sheet down from the drag indicator.
2. Reopen it and tap the X close button in the top-right.
3. Reopen it, tap "Message" to show the field, then swipe the sheet down with the keyboard open.
4. Reopen and hold the phone at arm's length: identify song, artist, who is playing it, and the main action without reading closely.
5. Tap "Queue" and then "Save" and watch every transition; scroll the sheet to the bottom and back.

**Expected:** Steps 1–3: the sheet dismisses cleanly each time (no stuck keyboard, no stray state), and Discover underneath is unchanged. Step 4: title, artist, name, and the single Ember (coral accent) "Play on Spotify" pill are readable at a glance; there is generous spacing between the cover, the row, the button, the action row, and the footer, and nothing looks like a dense list or developer UI. Step 5: motion is limited to short fades/springs (status line, spinner, message field, one like ripple); no bouncing, flashing, or colour-changing backgrounds; the footer links are quiet secondary text.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |
