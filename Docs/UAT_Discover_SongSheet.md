# UAT – Discover Song Sheet (Round 3)

User acceptance tests for the song sheet that opens from a Discover card (`DiscoverTrackSheet`).
Tapping the cover or the song title on a Discover card opens the sheet; tapping the person's name or the chevron still expands the card.

Round 1 passed 12/12 and produced eight fixes (`be96fa0`). Round 2 produced a second set of fixes, now in `3c7a96a`. Round 3 re-runs the whole surface and checks each round 2 fix explicitly:

- an expired Spotify login is remembered (`loginExpired`), so Play, Queue and Save show "Your Spotify login expired · Reconnect" even before a request is made; the flag clears on disconnect and on a new login;
- an HTTP 401 from Spotify is treated as an expired login (Reconnect), not a generic failure;
- like pre-checks read from the server, so an offline like fails fast instead of hanging;
- sending a message shows a spinner on the Message button; a failure shows inside the sheet and the typed text comes back;
- when the Spotify app is not installed, the browser fallback says "Opened in browser" and "Spotify isn't installed — opened in your browser";
- "Hide this song" runs after the sheet is down, so the card fade and the undo toast are visible;
- cards in "Recently live" animate out when hidden, like the live ones;
- the cover fades in instead of popping;
- the close button has a 44 pt tap target;
- the share sheet preview shows the song title and the cover.

Run these on a physical iPhone with the Melora build from this branch. Most tests need a signed-in account and at least one other user broadcasting in Discover. Tests that involve Spotify playback need the Spotify app installed. UAT-05 needs a Spotify Free account; UAT-06 needs a way to invalidate the stored Spotify login (revoke Melora at spotify.com/account/apps, or change the Spotify password); UAT-07 needs an account connected on an older build (before the library scopes were added). UAT-10 needs a phone without the Spotify app.

Product intent: calm, premium, music-first. The song is the hero.

Legend for the status tables: Pass / Fail / Blocked, plus tester initials, date, and a short note.

---

## UAT-01 – Open the sheet from the cover and the title; name and chevron still expand the card

**Preconditions:** Signed in. Discover shows at least one card with a real cover. The card is collapsed.

**Steps:**
1. On a Discover card, tap the small square cover on the right (it has a tiny play badge).
2. Note what opens, then close it with the X in the top-right corner of the sheet.
3. Tap the song title (the serif text) on the same card.
4. Close the sheet again.
5. Tap the person's name on the card.
6. Tap the chevron on the right edge of the card.
7. With the card expanded, tap the cover again.

**Expected:** Steps 1, 3 and 7 open the song sheet with a light haptic and the card itself does not expand or collapse; steps 5 and 6 expand/collapse the card in place with a short spring and no sheet appears.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-02 – Header: cover fades in, glow follows the cover, titles read at a glance

**Preconditions:** Song sheet closed. Two Discover cards whose covers have clearly different dominant colours; at least one track has an album name. Force-quit the app first so the 220 pt cover is not cached.

**Steps:**
1. Open the sheet for the first card and watch the cover area during the first half second.
2. Read the header: cover, title, artist, album.
3. Tap "Like" in the action row and watch the cover and the text under it while the ripple plays.
4. Close and open the sheet for the second card; compare the glow colour.

**Expected:** Step 1: a muted placeholder with a music icon is shown first and the real cover fades in over it (no pop, no layout jump), while the colour glow at the top fades in softly. Step 2: a large square cover (about 220 pt) with a soft shadow sits centred under the drag indicator and the X button; below it the title in the serif font (large, up to two lines), the artist in a smaller semibold line, the album in a muted footnote. Step 3: the ripple spreads once from the cover and the cover, title, artist and album do not move or resize. Step 4: the glow colour follows the second cover.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-03 – "Playing now by" row opens the profile after the sheet is down

**Preconditions:** Sheet open for a card that is live now. A second card in "Recently live" (if available).

**Steps:**
1. Read the row under the header: photo, small uppercase label, name, "Live" with a ripple mark, and distance or city.
2. Tap anywhere on the row.
3. Close the profile with "Close".
4. Open the sheet for a "Recently live" card and read the same row.

**Expected:** Step 1: the label reads "PLAYING NOW BY", the name is bold, "Live" is in the accent colour with a single ripple ring, and a distance band ("under 500 m", "about 2 km") or the city follows. Step 2: the song sheet slides down first, then the profile preview opens on its own, with no double sheet, flicker, or stuck sheet. Step 3: Discover is back with the card still in place. Step 4: the label reads "PLAYED BY" and the second line reads "Live <time ago>" in grey, not in the accent colour.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-04 – Play and Queue with a connected Premium account and an active device

**Preconditions:** Spotify connected in Melora Settings on a Spotify Premium account. The Spotify app is open on this phone and something is playing (or paused, but the device is active). Sheet open for a card.

**Steps:**
1. Read the primary button.
2. Tap "Play on Spotify" and watch the button and the line under it.
3. Switch to Spotify and check what plays; come back to Melora (the sheet should still be up).
4. Tap "Queue" in the action row and watch the button.
5. In Spotify, open the queue.

**Expected:** Step 1: the button reads "Play on Spotify" with a play icon, full width, in the primary colour. Step 2: the button briefly shows a spinner and "Starting…", then a check mark and "Playing on Spotify"; the status line "Now playing on your Spotify." fades in below and fades out again after a few seconds. Step 3: the song from the sheet is playing on the phone. Step 4: the Queue icon is replaced by a small spinner (no jump), then returns; the status line reads "Added to your queue." Step 5: the song sits at the top of the queue.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-05 – Play and Queue without an active device, with a Free account, and when Spotify is not connected

**Preconditions:** Three states are needed, in this order: (A) Spotify connected on a Premium account, the Spotify app installed but force-quit on this phone and no other device playing; (B) Spotify connected on a Spotify Free account; (C) Spotify disconnected in Melora Settings (no prior expired login: "Connect Spotify" is shown in Settings).

**Steps:**
1. In state A, open the sheet and tap "Play on Spotify"; watch the button until Spotify appears.
2. Return to Melora and read the button.
3. Tap "Queue" and read the status line.
4. In state B, open the sheet and tap "Play on Spotify"; read the status line, then come back from Spotify.
5. In state B, tap "Queue" and read the status line.
6. In state C, open the sheet and read the primary button; tap it.
7. Return to Melora, tap "Queue" and then "Save"; read the status line each time.

**Expected:** Step 1: the button shows "Starting…" with a spinner and stays that way until the Spotify app opens on the song; it never flashes back to "Play on Spotify" in between. Step 2: the button reads "Opened in Spotify" with an arrow icon. Step 3: "Open Spotify and play something first." Step 4: "Playing from Melora needs Spotify Premium — opening Spotify instead." is shown and the Spotify app opens on the song. Step 5: "The queue needs Spotify Premium." and nothing opens. Step 6: the button reads "Open in Spotify" (not "Play on Spotify") and tapping it opens the Spotify app on the song. Step 7: "Connect Spotify in Settings to use the queue." and "Connect Spotify in Settings to save songs." — informational, with no Reconnect button.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-06 – Expired Spotify login: Reconnect on Play, Queue and Save; the flag is remembered and cleared

**Preconditions:** Spotify connected in Melora. Then invalidate the login outside the app: revoke Melora's access at spotify.com/account/apps (or change the Spotify password). Do not disconnect in Melora.

**Steps:**
1. Open the sheet and tap "Play on Spotify"; read the button and the status line.
2. Close the sheet, open it again for a different card, and tap "Queue" without tapping Play first.
3. Tap "Save".
4. Tap "Reconnect" in the status line, cancel the Spotify login page, and read the status line.
5. Tap "Reconnect" again and complete the Spotify login.
6. Tap "Play on Spotify" (with an active device) or "Save".
7. Go to Settings, disconnect Spotify, return to Discover and open the sheet; tap "Queue".

**Expected:** Step 1: the button returns to "Play on Spotify" and the status line reads "Your Spotify login expired." with a bold "Reconnect" link that stays until acted on. Steps 2 and 3: the same "Your Spotify login expired. · Reconnect" line appears immediately, without a network round-trip spinner, because the expired state is remembered. Step 4: the status line is cleared when Reconnect is tapped; cancelling leaves the app usable and a further Play shows the expired line again. Step 5: after login, the primary button reads "Play on Spotify". Step 6: the action succeeds ("Now playing on your Spotify." or "Saved to your Liked Songs."). Step 7: the status reads "Connect Spotify in Settings to use the queue." — the expired flag is gone after a disconnect.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-07 – Save to Liked Songs, and the Reconnect hint for an older login

**Preconditions:** Two accounts or two states: (A) Spotify connected on this build (login includes the new user-library scopes); (B) Spotify connected on a build before the library scopes were added, then upgraded without reconnecting. In state A, pick a track that is NOT yet in your Liked Songs and one that IS.

**Steps:**
1. In state A, open the sheet for the track that is not in Liked Songs; read the Save button.
2. Tap "Save" and watch it.
3. Close and reopen the sheet for the same track.
4. Tap "Saved"; watch it.
5. Open the sheet for the track that is already in Liked Songs; read the button.
6. In state B, open the sheet; read the Save button, then tap it.
7. Tap "Reconnect", complete the Spotify login, and tap "Save" again.

**Expected:** Step 1: "Save" with a plus icon. Step 2: the plus is replaced by a small spinner, then the button reads "Saved" with a check in the accent colour, and the status line reads "Saved to your Liked Songs."; Spotify's Liked Songs contains the track. Step 3: the sheet opens showing "Saved" straight away. Step 4: it returns to "Save" with "Removed from your Liked Songs." Step 5: "Saved" is shown on open. Step 6: the button reads "Save" (no crash, no stray error on open); tapping it shows "Reconnect Spotify to save songs." with a Reconnect link. Step 7: the save succeeds and the button reads "Saved".

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-08 – Like from the sheet stays in sync with the card; an offline like fails fast inside the sheet

**Preconditions:** Signed in. A card whose user you have not liked yet (Like shows an outline heart in the card's expanded row). A second such card. Airplane mode available.

**Steps:**
1. Open the sheet for the first card and tap "Like"; watch the cover and the button.
2. Tap "Liked" again.
3. Close the sheet, expand the card with the chevron and read its Like button.
4. Collapse the card, expand it, tap "Like" on a second card's expanded row, then open that card's sheet from the title.
5. Turn on Airplane mode. Open the sheet for a third, not-yet-liked card and tap "Like"; time how long until something happens.
6. Turn Airplane mode off.

**Expected:** Step 1: a medium haptic, a ripple spreads once from the cover without moving it, the button turns into a filled heart in the accent colour with "Liked". Step 2: nothing happens (no second like, no burst). Step 3: the card's own Like button reads "Liked" with a filled heart. Step 4: the sheet opens already showing "Liked". Step 5: within a few seconds (not a 30-second hang) the heart rolls back to "Like" and the status line under the primary button shows a readable error ("Couldn't send your like. Please try again." or a network message) — no system alert appears behind the sheet. Step 6: tapping "Like" again succeeds.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-09 – Message inline with a spinner, then "Open chat" after the sheet is down; a failed send gives the text back

**Preconditions:** Signed in. A card whose user you have not messaged yet. Airplane mode available.

**Steps:**
1. Open the sheet and tap "Message" in the action row.
2. Type a short message and watch the send button while typing.
3. Tap the round send button and watch the Message button and the status line.
4. Read the Message button once the spinner stops; close the sheet and check the card's expanded row.
5. Open the sheet again and tap "Open chat".
6. Go back to Discover. Turn on Airplane mode, open the sheet for a different, not-yet-messaged card, tap "Message", type a message and send it.
7. Turn Airplane mode off.

**Expected:** Step 1: a text field ("Say something about the song…") slides up under the action row with the keyboard already open; nothing is sent yet. Step 2: the round send button is grey while the field is empty and turns to the accent colour once there is text. Step 3: the field slides away, the keyboard closes, the Message icon is replaced by a small spinner while sending, then the status line reads "Message sent." Step 4: the button now reads "Open chat" in the accent colour, and the card's expanded row also reads "Open chat". Step 5: the song sheet slides down first, then the chat with that person is pushed and shows the message. Step 6: after a short wait the status line shows an error inside the sheet, the field reappears with the typed text still in it, and the button still reads "Message". Step 7: sending again succeeds.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-10 – Share with a cover preview; "Open in Spotify" footer; browser fallback without the Spotify app

**Preconditions:** Sheet open for a card with a real cover. For steps 5 to 7 use a phone WITHOUT the Spotify app installed (or delete it).

**Steps:**
1. Tap "Share" in the action row and read the top of the share sheet.
2. Choose "Copy" and paste into Notes.
3. Dismiss the share sheet. Tap "Open in Spotify" in the footer.
4. Return to Melora and read the primary button.
5. On a phone without the Spotify app, open the sheet and tap the primary button (it reads "Play on Spotify" when connected, "Open in Spotify" otherwise).
6. Return to Melora and read the primary button and the status line.
7. Tap "Open in Spotify" in the footer.

**Expected:** Step 1: the share sheet's preview shows the song cover with "Title – Artist" (not a generic link icon). Step 2: the pasted text is "Title – Artist" followed by an open.spotify.com/track link. Step 3: the Spotify app opens on the song. Step 4: the button reads "Opened in Spotify" with an arrow icon. Step 5: Safari opens on the open.spotify.com track page. Step 6: the button reads "Opened in browser" and the status line reads "Spotify isn't installed — opened in your browser." Step 7: the browser opens again on the same page; no crash, no dead tap.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-11 – Hide this song runs after the sheet is down, with a visible card fade and undo toast (live and recent)

**Preconditions:** Discover shows at least two cards: one in "Live now" and one in "Recently live" (or two live cards). Note the song titles.

**Steps:**
1. Open the sheet for the live card and tap "Hide this song" at the bottom.
2. Watch the feed as the sheet goes down; read the toast.
3. Tap "Undo" within five seconds.
4. Repeat step 1 for the "Recently live" card and watch the feed; this time let the toast time out.
5. Pull to refresh.
6. Open Settings and find the hidden song.

**Expected:** Steps 1 and 2: the sheet slides down first; only then does the card fade out of the feed (the other cards close the gap with a short spring) and a pill toast appears at the bottom reading "“<song title>” hidden" with an accent-coloured "Undo". Step 3: the card returns to its place and the toast disappears. Step 4: the "Recently live" card also animates out (no abrupt disappearance) and the toast fades after about five seconds. Step 5: the hidden song does not come back. Step 6: the song is listed under hidden songs and can be restored.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |

---

## UAT-12 – Dismissal, close button target, and the calm, premium feel

**Preconditions:** Sheet open for a card. Reduce Motion off.

**Steps:**
1. Swipe down on the sheet from the cover to dismiss it.
2. Reopen it and tap the X in the top-right corner, aiming slightly outside the visible circle (about 4 pt to the outside).
3. Reopen it, tap "Message" so the keyboard is up, then swipe down on the sheet.
4. Reopen the sheet and, without tapping anything, look at it for five seconds. Count the number of colours, font styles and elements. Check the spacing between the header, the "Playing now by" card, the primary button, the action row and the footer.
5. Trigger a status line (tap "Queue") and watch how it appears and disappears.
6. Scroll the sheet on a small phone (iPhone SE / mini) and check nothing is clipped.

**Expected:** Step 1: the sheet dismisses with the standard interactive drag; Discover is unchanged underneath. Step 2: the tap still closes the sheet (44 pt target). Step 3: the keyboard goes down with the sheet, and reopening shows a clean sheet with no message field and no stale status. Step 4: the sheet reads as one hero cover, one serif title, one primary button and one row of five equal actions; no dense lists, no developer-looking labels, generous spacing (roughly 20 pt between sections), text readable at a glance, nothing blinking or pulsing except the single ripple ring next to "Live". Step 5: the status line fades and slides in gently under the button and fades out after a few seconds without the button jumping. Step 6: all content is reachable by scrolling, the footer links are not hidden behind the home indicator, and the drag indicator and X stay at the top.

| Status | Tester | Date | Notes |
|--------|--------|------|-------|
|        |        |      |       |
