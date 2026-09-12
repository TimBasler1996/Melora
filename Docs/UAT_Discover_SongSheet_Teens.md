# UAT — Discover Song Sheet (teen testers, round 3)

**Feature:** Tapping a song (the cover or the serif title) on a Discover card opens the song sheet (`DiscoverTrackSheet`).
**Build under test:** branch `Dev3`, round 2 fixes committed (`be96fa0` and later).
**Who runs this:** testers aged 14–19, on their own phones, with their own Spotify accounts.

## Persona

You are 16. You have Spotify **Free** (no Premium), an iPhone SE or a hand-me-down iPhone 11/12, Dark Mode always on, Low Power Mode on most of the day, and mobile data that drops out on the bus and in the school basement. You use TikTok and Instagram, so you expect things to open instantly, look good, and never lecture you. The main reason you'd use Melora is to see what people around you are playing and to send a song to a friend in iMessage or WhatsApp. If something feels slow, stuck, paywalled or creepy (someone's exact location, an accidental message to a stranger), you delete the app. Test like that: tap fast, tap twice, swipe the sheet away while it's still doing something, and say honestly whether it feels cool or like a settings screen.

How to fill in the status table: `Pass`, `Fail`, or `Blocked`, with a one-line note. If the app says something to you, copy the exact words into the note.

---

## TEEN-01 — Opens instantly, cover first, looks like a music app

**Preconditions**
- Logged in, Discover shows at least one card with album art.
- Phone in Dark Mode, Low Power Mode ON.
- Mobile data (turn Wi-Fi off).

**Steps**
1. On a Discover card, tap the small album cover on the right.
2. Watch the first second: what shows first, what animates.
3. Swipe the sheet down to close it. Tap the song *title* (the serif text) on the same card instead.
4. Look at the sheet: title font, colour glow at the top, cover shadow.
5. Tap the round X at the top right once, with your thumb, one-handed.

**Expected**
The sheet slides up right away on both taps (cover and title). The cover is visible at once (a soft placeholder at most for a blink, then the real cover fades in — it never "pops" or jumps). The top of the sheet glows in the colour of the cover, the title is in the big serif font, artist and album under it. The X closes it on the first tap. Nothing looks like a form or a settings page.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-02 — Play on Spotify with a Free account (no paywall wall)

**Preconditions**
- Spotify **Free** account connected to Melora (Settings shows it as connected).
- Spotify app installed and playing something (any device counts, phone is fine).

**Steps**
1. Open a song sheet.
2. Read the big orange button. Tap it once.
3. Read the line that appears under the button and watch what happens on screen.
4. Come back to Melora and look at the button text.

**Expected**
The button says "Play on Spotify". After the tap it shows a short spinner ("Starting…"), then Melora tells you in one calm line that playing from Melora needs Spotify Premium *and* immediately hands you over to the Spotify app on that song — you are not left on a dead button or a "buy Premium" wall. Back in Melora the button reads "Opened in Spotify". Nothing sounds like it's your fault.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-03 — Queue and Save on a Free account; spam-tapping Queue

**Preconditions**
- Spotify Free connected, Spotify app open and playing.
- You connected Spotify *after* the latest Melora update (so Save has the new permissions).

**Steps**
1. Open a song sheet. Tap **Queue** five times as fast as you can.
2. Read the line under the play button. Check your Spotify queue.
3. Tap **Save** once. Wait for the icon to change. Check "Liked Songs" in Spotify.
4. Tap **Save** again (now "Saved"). Check Liked Songs again.
5. Close the sheet, reopen the same song: look at the Save label.

**Expected**
Queue shows a tiny spinner while it works and ignores the extra taps (no five spinners, no five "Added" lines, and not five copies in the queue). On Free, Queue says in one short line that the queue needs Spotify Premium — honest, not pushy. Save works on Free: the icon flips to a tick and "Saved", the song appears in Liked Songs; tapping again removes it and says so. Reopening the sheet shows the correct Saved/Save state.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-04 — Share a song to a friend (iMessage / WhatsApp / Instagram)

**Preconditions**
- iMessage and WhatsApp (or Instagram) installed.
- Open a song sheet and wait until the cover is fully visible.

**Steps**
1. Tap **Share** in the action row.
2. Look at the top of the iOS share sheet: what preview is shown (image? name?).
3. Pick iMessage, send to yourself or a friend. Look at the bubble.
4. Go back, tap Share again, pick WhatsApp and send it.
5. Open the link from the message on the other phone (or your own).

**Expected**
The share sheet header shows the album cover plus "Song – Artist" (not a blank grey icon, not a random URL card). The message contains the song and artist as text plus an open.spotify.com link that opens the song in Spotify (app or web) — a friend without Melora can still play it. Sharing works on the first tap every time; the Share button is as easy to hit as Like.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-05 — Like: five taps in a row, then swipe away mid-like

**Preconditions**
- A song from a person you have NOT liked yet.
- Mobile data on (flaky is fine).

**Steps**
1. Open the sheet. Tap **Like** five times as fast as you can.
2. Watch the cover (the ripple) and the Like label.
3. Close the sheet; look at the same card in the feed (expand it with the chevron).
4. On a different song, tap Like and swipe the sheet down *immediately* (within half a second).
5. Reopen that song's sheet.

**Expected**
One ripple burst over the cover, the cover and title do not move, and Like turns into "Liked" (orange heart) once. Only one like reaches the other person — no duplicates, no repeated bursts, no error about "already reached out". The card in the feed shows the same "Liked" state as the sheet. Swiping away mid-like doesn't lose the like or freeze anything: reopening shows "Liked".

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-06 — Message a stranger: nothing sends by accident, errors are human

**Preconditions**
- A song from a person you have never messaged.
- Airplane mode ready to toggle.

**Steps**
1. Open the sheet, tap **Message**. Note whether anything was sent yet.
2. With the box empty, try to tap the send circle. Tap Message again to close the box.
3. Tap Message, type "this song is so good", turn on Airplane mode, tap send.
4. Read the line under the play button and look at the text box.
5. Turn Airplane mode off, tap send again.
6. Tap the Message button now (its label changed).

**Expected**
Tapping Message only opens a text box with the keyboard — nothing is sent until you tap the send circle, and the circle stays grey/disabled while the box is empty. Offline, the send shows a short spinner and then a friendly one-line note that it couldn't send (no big alert, no "Please try again" wall shouting at you) and your text comes back into the box so you don't retype. Online, it says "Message sent." and the button becomes "Open chat"; tapping that closes the sheet and opens the chat, not two screens stacked on top of each other.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-07 — Privacy: distance bands, no exact location, profile one tap away is safe

**Preconditions**
- Location allowed for Melora, Nearby mode, at least one live person nearby.

**Steps**
1. Open a song sheet. Read the "Playing now by" row: name, Live, distance/city.
2. Write down exactly how the distance is worded.
3. Tap the "Playing now by" row.
4. On the profile that opens, look for: exact metres, a map pin, street, or any way to see precisely where they are. Find the Block / Report options.
5. Close the profile and check you are back on Discover (not on a stuck sheet).

**Expected**
Distance is a band, never a number of metres: "under 500 m", "under 1 km", "about 2.5 km", "about 12 km". If there is no distance, it shows a city or "Somewhere", never coordinates. The profile opens only after the sheet has closed (no two sheets fighting), and it shows no exact position and no way to get one. Block and Report are easy to find in the profile menu. Nothing on the sheet sends a message or a like just by tapping the person's name.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-08 — Old or expired Spotify login: one clear "Reconnect", not a dead end

**Preconditions**
- Two situations, test both:
  - A: Spotify was never connected in Melora.
  - B: Spotify was connected, but the login expired (ask the dev to revoke Melora at spotify.com/account/apps, then open Melora again).

**Steps**
1. (A) Open a song sheet. Read the big button; tap it. Then tap Queue and Save and read each line.
2. (B) Open a song sheet. Read the big button; tap it. Read the line under it.
3. (B) Tap Queue, then Save. Read the lines.
4. (B) Tap **Reconnect**, log in on Spotify, come back.
5. (B) Tap the big button again.

**Expected**
(A) The button says "Open in Spotify" and just opens the song in Spotify; Queue and Save say in one short line to connect Spotify in Settings — no error alerts. (B) The button says "Play on Spotify"; tapping it shows "Your Spotify login expired." with a **Reconnect** button right there in the sheet — no need to go find Settings; Queue and Save show the same one line. After reconnecting, the line disappears and Play/Queue/Save work again (or give the Free-account message from TEEN-02/03). At no point does the app blame you or show a spinner that never ends.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-09 — Hide this song: it leaves the feed nicely and you can take it back

**Preconditions**
- At least three cards in the feed.

**Steps**
1. Open a song sheet, scroll to the bottom, tap **Hide this song**.
2. Watch the sheet and the feed for the next 2 seconds.
3. Read the toast at the bottom. Tap **Undo** within 5 seconds.
4. Repeat steps 1–2 for another song, but do NOT tap Undo. Wait 6 seconds.
5. Open Settings and check the hidden songs list.

**Expected**
The sheet closes first, *then* the card fades out of the feed where you can see it (no hide happening invisibly behind the sheet). A small toast says the song is hidden with an Undo. Undo brings the card straight back. Without Undo, the song stays hidden and shows up in Settings so you can restore it later. "Hide this song" is easy to reach one-handed on a small phone (scroll if needed, but it's there).

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-10 — Bad signal, small screen, swipe away mid-action: nothing gets stuck

**Preconditions**
- iPhone SE (or the smallest phone available), Dark Mode, Low Power Mode ON.
- Spotify Free connected, Spotify app open.
- Airplane mode ready.

**Steps**
1. Open a song sheet. Without scrolling, check what you can see: cover, title, "Playing by", play button, action row.
2. Scroll to the bottom: "Open in Spotify" and "Hide this song" must be reachable.
3. Turn on Airplane mode. Tap the play button, then Queue, then Save. Read each line.
4. Tap Save and swipe the sheet down *while* the spinner is showing.
5. Turn Airplane mode off. Reopen the same song. Check nothing is spinning, labels are correct.
6. Tap Play on Spotify, then immediately swipe the sheet away. Check Spotify opened and Melora is fine.

**Expected**
On a small screen the cover, title, person and play button all fit without scrolling; the footer is reachable by a short scroll. Offline, each action shows a short spinner (a blink, not seconds) and then one calm line like "Couldn't reach Spotify. Try again." — no frozen buttons, no alerts. Swiping the sheet away mid-action never leaves a spinner, a stuck button or a duplicate action; reopening the sheet is clean. Every animation still runs smoothly in Low Power Mode.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## Notes for the dev (from reading the code, not yet verified on device)

- `handleLike` guards on `hasLiked`, but that flag only flips after `sendLike` inserts the key on the main actor inside a Task. Five very fast taps may spawn more than one like request before the guard catches up (TEEN-05 will show whether the server dedupes cleanly or the second request surfaces "You've already reached out to …").
- The share preview uses the cover only when the 220pt image is already in the cache; if a tester taps Share before the cover has loaded, the preview falls back to the generic music icon (TEEN-04 step order is deliberate — also try tapping Share instantly).
- `displayName` is first + last name. Teens may not expect their surname on a stranger's sheet; worth a product decision (out of scope for this sheet, but TEEN-07 testers should note what they see).
