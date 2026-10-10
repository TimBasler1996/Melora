# UAT — 30-Second Song Preview (teen testers)

**Feature:** The album cover is now a play button. Tapping it plays a ~30 second snippet of the song inside Melora — on the Discover card (small cover on the right) and on the song sheet (big cover at the top). The snippet does not come from Spotify (Spotify switched previews off), it is looked up live from Apple's and Deezer's public catalogues.
**Build under test:** branch `Dev3`, commit `377a25f`, build 10.
**Who runs this:** testers aged 14–19, on their own phones, with their own Spotify accounts.
**Files behind it:** `Services/TrackPreviewService.swift`, `Services/PreviewPlayer.swift`, `Features/Discover/Views/DiscoverCardView.swift`, `Features/Discover/Views/DiscoverTrackSheet.swift`.

## Persona

You are 16. Spotify **Free**, an iPhone SE or a hand-me-down iPhone 11/12, Dark Mode always on, Low Power Mode on most of the day, mobile data that dies on the bus and in the school basement. Your AirPods are usually one-in-one-out, your ringer is on silent from first period until the bus home, and your phone is often playing music out loud in your room. You scroll fast and you tap before you read. The whole point of this feature for you is: *hear it, then decide* — you should never have to leave for Spotify just to find out whether a song is any good. Judge it like TikTok: if the sound does not start almost instantly, if it blasts out loud in a lecture, if two songs play at once, if your own music does not come back, or if a tap does nothing and the app never says why, you are done with it. Be honest about the embarrassing moments — those matter more than the bugs.

How to fill in the status table: `Pass`, `Fail`, or `Blocked`, with a one-line note. If the app says something to you, copy the exact words into the note. Always write down **how many seconds** you waited.

---

## TEEN-PREV-01 — The snippet starts fast, and a slow connection is honest about it

**Preconditions**
- Logged in, Discover shows several cards with album art.
- Headphones in (so you can hear the first moment clearly).
- Run the test twice: once on good Wi-Fi, once on bad mobile data (bus, basement, or turn on Airplane Mode for 2 seconds and off again right before tapping).

**Steps**
1. Good Wi-Fi: tap the small album cover on the right of a Discover card. Count out loud how long until you hear music.
2. Tap the same cover again to stop it. Then tap it a third time and count again (this one should come from memory, not from the internet).
3. Bad connection: tap the cover of a card you have not tapped before. Do **not** tap again. Just watch the cover for up to 30 seconds and say what it is doing.
4. While it is still thinking, say out loud whether you believe it is working or whether you think the tap was ignored.
5. Open the song sheet of another song (tap the title) and do the same there: tap the big cover once on a bad connection and watch it.

**Expected**
On Wi-Fi the music is audible in about a second, and a second play of the same song is instant. On a bad connection the tap is *visibly* acknowledged at once — the little play mark on the cover turns into a spinner and stays spinning until either the music starts or the app gives up — so it never feels like the tap was swallowed. On the big cover in the song sheet the spinner is clearly visible; note it as a **Fail** if the tiny spinner on the small card cover is so small you cannot tell it is spinning, or if you ever wait longer than about 10 seconds with no sound and no message.

| Tester | Device / iOS | Connection | Seconds to sound | Status | Note |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

---

## TEEN-PREV-02 — Tapping card after card, fast, back and forth

**Preconditions**
- Discover shows at least 4 different cards with art.
- Headphones in, volume high enough to notice two songs at once.

**Steps**
1. Tap the cover of card 1. As soon as you hear it, tap the cover of card 2. Then card 3, then card 4 — about one tap per second.
2. Listen carefully: is there ever a moment where you hear two songs at the same time, even for half a second?
3. Look at the covers: only one cover should have the thin line running around it. Check it is running around the cover of the song you are actually hearing.
4. Now go back and forth: card 1, card 2, card 1, card 2 — as fast as you can tap, about 8 taps.
5. Now hammer the **same** cover: tap it 5 times fast, then stop and listen.
6. Tap the title of a card to open the song sheet, start the preview on the big cover, swipe the sheet away, and immediately tap a different card's cover.

**Expected**
Exactly one snippet is ever audible — starting a new one always kills the old one instantly, with no overlap and no echo of the same song slightly offset. The progress line runs around exactly one cover, always the one you are hearing, and it disappears from the one you left. Hammering the same cover 5 times must not end with two copies of that song playing on top of each other, and must not leave the cover showing a pause mark while nothing plays. Write down exactly what you heard at step 5 — this is the step most likely to break.

| Tester | Device / iOS | Status | Note |
|---|---|---|---|
|  |  |  |  |

---

## TEEN-PREV-03 — Ringer on silent, in class, AirPods half in

**Preconditions**
- Phone **silent switch ON** (ringer off) — the way you carry it at school.
- One AirPod in your ear, the other in the case or on the table.
- Volume at whatever level you last left it (do not set it nicely for the test).

**Steps**
1. With the ringer on silent and no headphones connected at all, tap a cover in Discover. Say immediately whether sound came out of the phone speaker.
2. Imagine you are in a lecture: would that tap have embarrassed you? Write yes or no.
3. Connect your AirPods, take one out and leave it out, then tap another cover. Where does the sound come from, and how loud is the first moment compared to your music?
4. Put the AirPod back in the case so only one is in your ear, and tap a third cover.
5. Connect to a car or a Bluetooth speaker if you have one nearby and tap a cover.

**Expected**
You can report exactly what happens, and nothing surprises you more than once. Note as a **Fail** (or at least flag it loudly) if the snippet plays out loud through the phone speaker while the ringer is on silent and nothing on screen warned you first — that is the embarrassing case, and the app currently chooses to be audible on purpose. The first moment must not be noticeably louder than your normal music, must never start before the cover shows that it is playing, and the sound must go to the headphones whenever they are connected.

| Tester | Device / iOS | Silent switch | Sound came out of | Embarrassing? | Status | Note |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

---

## TEEN-PREV-04 — Your own music is playing out loud, then you tap a preview

**Preconditions**
- Your own Spotify is **playing** a song out loud (phone speaker or headphones), roughly in the middle of the track.
- Melora is live/broadcasting, so your own song is what friends see.

**Steps**
1. With your music playing, open Discover and tap another song's cover.
2. Say what happens to your own music in that moment: pause, duck (quieter), or keep playing on top?
3. Let the snippet run all 30 seconds to the end. Do not touch anything. Watch what your own music does when the snippet finishes.
4. Repeat, but this time stop the snippet early by tapping the cover again. Does your music come back, and from where — the same spot or the start of the track?
5. While the snippet is playing, pull Melora's own screens up: check your own live card / Now Playing. Does Melora still show *your* song as playing, or does it think you went offline?
6. Wait 2 minutes after the whole test and check you are still shown as live.

**Expected**
Your music pauses cleanly (no two songs at once) — that is accepted, nothing else is. When the snippet ends or you stop it, your own Spotify picks itself up again within a couple of seconds, from where it left off, without you touching Spotify. Melora keeps showing you as live with your own song the whole time — a 30 second snippet must never end your live session or wipe your song off your friends' Discover. Note as a **Fail** if your music stays dead and you have to open Spotify to restart it.

| Tester | Device / iOS | Music came back? | Still live? | Status | Note |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

---

## TEEN-PREV-05 — A song nobody has a snippet for

**Preconditions**
- You need a song that is unlikely to be found: an obscure remix, a live version, a "sped up" edit, a local/unreleased track, or a song with the artist written weirdly. Ask the team for one, or play one on your own Spotify so it lands in Discover.
- Headphones in.

**Steps**
1. On the Discover card for that song, tap the small cover once. Wait. Describe everything that happens on screen and whether any sound came.
2. Write down whether you understood what just happened without anyone explaining it.
3. Now tap the big cover inside the song sheet for the same song. Read any line of text the app shows you, word for word.
4. Look at the big cover afterwards: does it still invite you to tap it, or has the play mark gone away?
5. Tap it once more. How long does it take this time, and does it say the same thing?
6. Check the big orange "Play on Spotify" button still works for this song.

**Expected**
The app admits it in plain words instead of going quiet: in the song sheet one calm line appears ("No preview for this one — open it in Spotify." — copy the exact wording you see) and the play mark disappears from the cover so you stop poking it. From the Discover card, the tap is never dead — it does something useful (it opens the song) rather than nothing, and you can tell that the app looked and found nothing rather than that it is broken. The second attempt answers immediately. Flag it if the Discover card simply opens the sheet and *still* says nothing about the missing snippet — that reads as a bug, not an answer.

| Tester | Device / iOS | Exact wording shown | Status | Note |
|---|---|---|---|---|
|  |  |  |  |  |

---

## TEEN-PREV-06 — Scrolling away, leaving the screen, locking the phone, switching apps

**Preconditions**
- Discover has enough cards to scroll for a few screens.
- Headphones in.

**Steps**
1. Start a snippet on a card, then scroll fast until that card is far off screen. Does the sound keep going? Can you still find a way to stop it?
2. While a snippet is playing, switch to another tab in Melora (Chat, Profile). Does the music stop or follow you? Is there anything on screen telling you something is still playing?
3. Start a snippet, then lock the phone with the side button. What happens to the sound? Unlock and look at the cover: does it still claim to be playing?
4. Start a snippet, swipe up to the home screen and open TikTok or Instagram for 10 seconds, then come back to Melora.
5. Start a snippet in the song sheet and swipe the sheet down while it plays.
6. Pull down the lock screen / control centre during a snippet: does Melora appear as a music player there with the song name?

**Expected**
The snippet never becomes a ghost you cannot turn off: either it stops when you leave the song behind, or you can always stop it with one tap on something you can actually find. Swiping the song sheet away stops the snippet immediately. Nothing keeps a pause/play mark lit on a cover while no sound is playing. Write down what you expected to happen at each step versus what happened — your expectation matters as much as the behaviour here.

| Tester | Device / iOS | Scroll away | Lock screen | App switch | Status | Note |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

---

## TEEN-PREV-07 — A call, a voice note or a video comes in mid-snippet

**Preconditions**
- A friend ready to call you (normal call and/or WhatsApp call).
- Headphones in, snippet playing.

**Steps**
1. Start a snippet and have your friend call you about 5 seconds in. Decline the call.
2. Look at the cover straight away: is the line still running, does it show pause or play, and is there sound?
3. Tap the cover once. Does it do the thing you expected (start again / stop)?
4. Repeat, but this time accept the call, talk for 10 seconds, hang up, and come back to Melora.
5. Repeat once more, but instead of a call play an Instagram reel or a WhatsApp voice note in another app for 5 seconds, then come back.
6. Last one: start a snippet, then start a snippet on a *different* card while the first one is interrupted by a notification sound.

**Expected**
After any interruption the app tells the truth: it either resumes the snippet or it clearly shows it has stopped — never a frozen progress line or a pause mark with silence behind it. One tap on the cover always does the obvious next thing, with no "dead" first tap you have to repeat. Note as a **Fail** any state where the cover looks like music is playing but nothing is audible.

| Tester | Device / iOS | After declined call | After accepted call | After other app | Status | Note |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

---

## TEEN-PREV-08 — From "I heard it" to "I reacted" in one tap

**Preconditions**
- Discover shows a card from someone you do not know and one from a friend.
- Headphones in.

**Steps**
1. Tap a card's cover and listen to the snippet. Now, **without stopping it**, like the song. Count how many taps that took from hearing it.
2. Do the same for sending a message about the song: count the taps from "I heard it" to "message sent".
3. Does the snippet keep playing while you like / type, or does it cut out? Say which one you *wanted*.
4. Open the song sheet instead, start the big-cover snippet, and from there like, then message, then share. Count the taps again and say whether anything felt in the way.
5. While the snippet plays, tap the big orange "Play on Spotify" button. What happens to the snippet?
6. Finally, honest question for the note field: did hearing the snippet make you more likely to like or message than before? Yes / no / no difference.

**Expected**
From hearing the snippet, liking is **one** tap and messaging is at most two taps plus typing — nothing forces you to stop the music first or to leave the song. Liking while the snippet plays does not kill the sound (and the heart animation does not make the cover jump). Tapping "Play on Spotify" hands over cleanly: the snippet stops at once and the full song takes over, never both. Any tester who answers "no difference" at step 6 should say in one sentence what would have changed that.

| Tester | Device / iOS | Taps to like | Taps to message | More likely to react? | Status | Note |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

---

## Notes for the team (what the testers are probing)

- The snippet is resolved live over the network (Apple first, Deezer second) with a per-request timeout, so a slow connection can mean a long wait before any answer arrives — TEEN-PREV-01 exists to check that the wait is *shown* and not just endured.
- The audio session is `.playback`, which is deliberately audible with the silent switch on — TEEN-PREV-03 asks teens whether that trade is acceptable in a lecture.
- A preview pauses the user's own Spotify and relies on `.notifyOthersOnDeactivation` for it to resume, and on Spotify continuing to report the paused track so the live session survives — TEEN-PREV-04 verifies both claims instead of assuming them.
- Rapid repeated taps on the same cover (TEEN-PREV-02 step 5) and interruptions (TEEN-PREV-07) are the two places where the playing/loading state can get out of sync with what is actually audible.
