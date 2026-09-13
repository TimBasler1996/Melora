# UAT — Intro Walkthrough & Discover Song Hint (teen testers)

**Feature:** first-run intro walkthrough (3 pages) + one-time Discover song hint
**Build:** TestFlight build 8 (commit cbd0e3a)
**Files under test:** `Views/Onboarding/IntroWalkthroughView.swift`, `Views/Main/MainView.swift`, `Views/Profile/SettingsContentView.swift`, `Features/Discover/Views/DiscoverView.swift`

## Persona

Mia is 16. A friend sent her a TestFlight link in a group chat with "try this, it shows what people around you are playing". She installed it on the bus, one-handed, with Spotify open in the background and about twenty seconds of patience. She has never read an app's welcome screen in her life; she taps through until something looks interesting. She does not know what "broadcast" means and would be creeped out by any app that seems to know exactly where she is. If she has to think about what to do next, she closes the app and goes back to the group chat. Some tests are run on her friend Noah's old iPhone SE with Dark Mode, Reduce Motion and larger text already switched on.

---

## TEEN-INTRO-01 — Getting the concept from the three pages alone

**Preconditions:** Fresh install of build 8, onboarding finished. The tester has NOT been told what Melora is and the Welcome screen was tapped past without reading it. Spotify is installed. Someone is holding a stopwatch.

**Steps:**
1. Land in the app after onboarding; the intro appears full screen.
2. Start the stopwatch. Read page 1 ("You go live") and look at the pulsing ripple and the "Nights — Frank Ocean · Live" pill.
3. Tap Next. Read page 2 ("See who's around") and look at the three stacked cards (Lena, Samir, Ava).
4. Tap Next. Read page 3 ("A song is the door") and look at the artwork tile and the Play / Like / Message / Share row.
5. Tap "Let's go". Stop the stopwatch.
6. Without looking at the app again, explain in one sentence what Melora does and what you would tap first.

**Expected:** In under 20 seconds the tester says something like "you share the song you're playing, you see people nearby and their songs, and you tap a song to play it, like it or message them" — no confusion about what "live" means, no guessing that it is a normal music player or a dating app.

| Tester | Device | Date | Time to "Let's go" | Result (Pass/Fail) | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

## TEEN-INTRO-02 — Tone and illustrations: does it feel like the app or like a lecture?

**Preconditions:** Fresh install, intro visible. The tester has used Discover and the song sheet on a friend's phone for a minute, so they know what the real screens look like.

**Steps:**
1. Go through all three pages slowly and read every word out loud, including the small grey footnote on page 2.
2. Flag any word that sounds like a grown-up, a company or a settings screen (e.g. "broadcast", "radius", "signal", "enable", "permission").
3. On page 2, compare the mini cards to the real Discover cards: name, big song title, small artist, "Live · under 500 m" line, ripple mark, tinted artwork square.
4. On page 3, compare the Play / Like / Message / Share row to the real song sheet.
5. Say whether "A song is the door" makes sense or sounds like a poster.

**Expected:** Nothing reads as patronising or corporate — the tester does not roll their eyes or ask "what does that mean?" — and they immediately recognise the page 2 cards and page 3 action row as the same things they saw in Discover and the song sheet, not as generic stock illustrations.

| Tester | Device | Date | Result (Pass/Fail) | Words flagged | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

## TEEN-INTRO-03 — Skip: findable, one-handed, and the intro can be found again

**Preconditions:** Fresh install, intro visible on page 1. Tester holds the phone in one hand (right hand, thumb only) on an iPhone 15 / 16 Pro Max size device, and repeats on an iPhone SE.

**Steps:**
1. Without being told where it is, find a way to skip the intro within 3 seconds.
2. Try to hit "Skip" (top right, next to the melora wordmark) with the thumb only, without shifting grip. Note whether it needs two hands or a grip change.
3. Tap Skip. Confirm you land on Discover with a light haptic and no leftover intro page.
4. Force-quit and reopen the app. Confirm the intro does not come back.
5. Now pretend you regret skipping: go to Profile → Settings and look for a way to see the intro again.
6. Tap "How Melora works". Go through it and tap "Let's go" (or Skip).

**Expected:** Skip is spotted in under 3 seconds and is at least tappable one-handed (a grip change on a Max phone is acceptable, two hands is not); after skipping the intro never reappears on its own, and "How Melora works" in Settings shows the exact same three pages and returns cleanly to Settings when closed.

| Tester | Device | Date | Result (Pass/Fail) | One-handed? | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

## TEEN-INTRO-04 — Swiping instead of tapping Next, and the last page

**Preconditions:** Fresh install, intro visible on page 1. Tester is told nothing about the buttons.

**Steps:**
1. Try to move to the next page the way you would in any story-style screen: swipe left.
2. Note whether the dots at the bottom follow (the active dot stretches to a pill) and the button label stays "Next".
3. Swipe right to go back to page 1, then swipe right once more past the first page.
4. Swipe left twice to reach page 3 and confirm the button now says "Let's go".
5. On page 3, swipe left once more, hard, as if there were a fourth page.
6. Observe whether anything happens (bounce only, or the intro closes, or a blank page). Then tap "Let's go".

**Expected:** Swiping works exactly like tapping Next in both directions; on page 1 swiping back just bounces; on page 3 an extra swipe only bounces (no blank page, no accidental close, no crash) and the tester naturally reaches for "Let's go" to finish.

| Tester | Device | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
| | | | | |

---

## TEEN-INTRO-05 — Friend's iPhone SE with Dark Mode, Reduce Motion and larger text

**Preconditions:** iPhone SE (2nd/3rd gen, 4.7-inch). iOS Settings: Appearance = Dark, Accessibility → Motion → Reduce Motion = On, Accessibility → Display & Text Size → Larger Text set to the largest non-accessibility size (and once more at an accessibility size). Fresh install of build 8.

**Steps:**
1. Reach the intro. On page 1, check the ripple: with Reduce Motion on, it should not pulse aggressively (a still mark or a gentle fade is fine).
2. On every page, check that the illustration, the title, the sentence, the dots and the Next button are all fully on screen without scrolling and without anything cut off at the top (Skip / wordmark) or the bottom (button under the home indicator).
3. On page 2, check that all three stacked cards and the grey footnote are visible and readable and do not overlap the title.
4. Bump text to an accessibility size and repeat step 2. Note whether the page text grows at all (some text uses fixed sizes) and whether the layout breaks if it does.
5. Switch Appearance to Light. Reopen the intro from Settings → "How Melora works" and confirm it still looks intentional (the intro is always dark).
6. Rotate the phone if rotation is allowed and check nothing disappears.

**Expected:** On the SE every page fits in one screen with title, sentence, dots and the button all visible and nothing clipped; Reduce Motion calms or stops the ripple; larger text either scales gracefully or stays legible at its fixed size without overlapping — and the tester does not see any page where the button or Skip is unreachable.

| Tester | Device | Date | Text size | Result (Pass/Fail) | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

## TEEN-INTRO-06 — System prompts: notifications and location around the intro

**Preconditions:** Fresh install, all permissions unset (delete the app first if needed), onboarding finished with Spotify connected.

**Steps:**
1. Land in the app. Confirm no system alert (notifications or location) is sitting on top of the intro on page 1.
2. Go through all three pages at normal speed. Confirm no alert interrupts you mid-page.
3. Tap "Let's go". Note exactly what appears next and in what order: the notification alert, the location alert, the Discover list.
4. Count how many system alerts stack up in the first five seconds after "Let's go".
5. On the notification alert, tap "Don't Allow". Confirm the app keeps working and you land on Discover.
6. Repeat from a fresh install, but this time tap Skip on page 1 instead of finishing. Check the same prompts still appear once, after the intro, not before.

**Expected:** No system alert ever appears while the intro is on screen; after "Let's go" or Skip the notification alert appears once, at a moment that feels like "the app is ready now", and if a location alert follows it the two do not land at the same instant or feel like an ambush — the tester can say no to both and still see Discover.

| Tester | Device | Date | Order of prompts | Result (Pass/Fail) | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

## TEEN-INTRO-07 — Discover song hint: clear, dismissable, not nagging, gone after the first tap

**Preconditions:** Fresh install, intro finished, location allowed, at least one other person live nearby (have a friend go live on their phone, or widen the radius). Run twice: once dismissing with X, once dismissing by tapping a song.

**Steps:**
1. Open Discover. Look above the first "Live now" card for the small card with the orange play circle and "Tap a song to play it, like it or say hi."
2. Say what you think it wants you to do without touching anything.
3. Run A: tap the X on the right. Confirm the hint fades out and the list moves up smoothly.
4. Pull to refresh, switch to another tab and back, force-quit and reopen. Confirm the hint never comes back.
5. Run B (fresh install): ignore the X and tap the song title on the first card. Confirm the song sheet opens and, when you close it, the hint is gone.
6. Also check: with nobody live nearby (only "Recently live" or the "nobody live" card), confirm no hint is shown at all and nothing feels missing.
7. Reopen the intro from Settings → "How Melora works" and go back to Discover: confirm this does not bring the hint back.

**Expected:** The hint is understood at a glance as "tap the song, not the photo", it disappears for good after either the X or the first song tap (never reappearing after refresh, tab switch, relaunch or re-watching the intro), and it never shows when there is no live card to point at.

| Tester | Device | Date | Run (A/B) | Result (Pass/Fail) | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

## TEEN-INTRO-08 — Page 2 and location: does a teenager feel safe?

**Preconditions:** Fresh install, intro on page 2. The tester is someone who has said they don't like apps knowing where they are. They have not yet seen the location system alert.

**Steps:**
1. Read page 2: the title, the sentence about the radius, and the small grey footnote "Your distance is shown in rough steps — never your exact location."
2. Look at the cards: "Live · under 500 m", "about 1 km", "about 2 km". Say out loud what you think other people would see about you.
3. Ask the tester: "Could someone use this to find your house or your school?" Record the answer and how sure they sound.
4. Ask: "Do you think it shares your location when you're not live?" Record the answer.
5. Finish the intro, allow location, and go live from the Live tab. Ask a friend on another phone what distance they see for you and compare it with what the page promised.
6. Open Profile → Settings and read the footer under About ("Your location is shared only while you're live, rounded to a few hundred metres…"). Say whether it matches what page 2 said.

**Expected:** After page 2 alone the tester says, in their own words, that others only see a rough distance like "under 500 m" and never a pin on a map, they are not scared to allow location, and what a friend actually sees for them matches the page's promise — with the Settings footer telling the same story in the same plain words.

| Tester | Device | Date | Felt safe? (Y/N) | Result (Pass/Fail) | Notes |
|---|---|---|---|---|---|
| | | | | | |
