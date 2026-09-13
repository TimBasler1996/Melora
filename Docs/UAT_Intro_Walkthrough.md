# UAT — Intro Walkthrough & Discover Song Hint (TestFlight build 8)

Feature under test: the three-page first-run intro ("You go live" → "See who's around" → "A song is the door") and the one-time "Tap a song…" hint above the first live card in Discover. Both shipped in build 8 (commit `cbd0e3a`) after a real tester installed the app and did not understand the concept.

What "pass" means overall: a new tester gets the idea in under 20 seconds, the intro is shown exactly once and can be reopened from Settings, nothing feels repeated or lecturing, and the notification permission prompt never lands on top of the intro.

Test devices: one iPhone with a fresh install (new user) and, ideally, one that already had build 7 installed with an account (existing user). Spotify installed and logged in. A second phone or a friend nearby who is live helps for the Discover hint cases; otherwise use a test account that is broadcasting.

Relevant code: `Views/Onboarding/IntroWalkthroughView.swift`, `Views/Main/MainView.swift`, `Views/Profile/SettingsContentView.swift`, `Features/Discover/Views/DiscoverView.swift`.

---

## INTRO-01 — First landing after onboarding shows the intro exactly once

**Preconditions:** Fresh install of build 8 (delete any previous Melora install first). No account.

**Steps:**
1. Launch the app and complete the welcome + onboarding flow (Get started → photo/name/age → Spotify connect or skip → Apple sign-in or "Not now").
2. Watch what appears the moment the main app (tab bar) is reached.
3. Do not tap anything for 3 seconds.

**Expected:** Immediately on first landing, a full-screen dark page titled "You go live" covers the tab bar, with the animated ripple, a "Nights — Frank Ocean · Live" pill, the Melora wordmark top-left, "Skip" top-right, three dots (first one wide and orange) and a "Next" button. No system permission dialog (notifications or location) is showing on top of it.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-02 — Page content, order, dots and Next / Let's go

**Preconditions:** Intro is on screen (INTRO-01, or Settings → "How Melora works").

**Steps:**
1. On page 1, read the title and text, then tap **Next**.
2. On page 2, read the title, text and the small footnote, then tap **Next**.
3. On page 3, read the title and text and look at the button label.
4. Check the dots after each tap.

**Expected:** Pages appear in this order with this content: (1) "You go live" — "Play something on Spotify and tap Go live. People nearby see what you're playing — for as long as it plays." with ripple + now-playing pill; (2) "See who's around" — "Discover shows the people near you and the song they're playing right now. Slide the radius to go wider." with three stacked mini cards (Lena / Samir / Ava) and the footnote "Your distance is shown in rough steps — never your exact location."; (3) "A song is the door" — "Tap a song to play it on your Spotify, like it, or say something. A like is a signal — if they like you back, you can chat." with artwork, "Nights / Frank Ocean" and a Play · Like · Message · Share row. The active dot is the wide orange one and moves with the page; the button reads "Next" on pages 1–2 and "Let's go" on page 3 only.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-03 — Swipe navigation works in both directions and stays in sync with the dots

**Preconditions:** Intro is on screen, page 1.

**Steps:**
1. Swipe left to go to page 2, then swipe left again to page 3.
2. Swipe right back to page 2, then right again to page 1.
3. Try swiping right on page 1 and left on page 3.
4. Tap **Next** once, then swipe left once.

**Expected:** Swiping moves one page at a time with a short smooth slide (no bounce-heavy or flashy effect); the dots and the Next/Let's go label always match the visible page; swiping past the first or last page rubber-bands slightly but does not dismiss the intro or jump; mixing taps and swipes never desyncs the dots.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-04 — "Let's go" and "Skip" both close the intro and mark it as seen

**Preconditions:** Two fresh installs (or one install, deleted and reinstalled between run A and run B).

**Steps:**
1. Run A: complete onboarding, walk through all three pages, tap **Let's go**.
2. Note where you land. Force-quit the app (swipe up in the app switcher) and relaunch. Note whether the intro shows.
3. Run B: delete the app, reinstall, complete onboarding, and on page 1 tap **Skip**.
4. Force-quit and relaunch. Note whether the intro shows.
5. In both runs, switch between all four tabs and background/foreground the app a few times.

**Expected:** Both "Let's go" and "Skip" close the intro with a light haptic and land on the Discover tab; after relaunch, tab switches and backgrounding, the intro never appears again in either run.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-05 — Notification permission is asked after the intro, not on top of it

**Preconditions:** Fresh install; notification permission for Melora has never been decided on this device (check Settings → Notifications → Melora is absent; if present, delete the app and reinstall).

**Steps:**
1. Complete onboarding and reach the intro.
2. Walk through all three pages slowly (~15 s). Watch for any system dialog while the intro is visible.
3. Tap **Let's go**.
4. Observe the next 2 seconds.

**Expected:** No system dialog appears while any intro page is visible; right after "Let's go" (or Skip) the standard iOS "Melora Would Like to Send You Notifications" dialog appears once over the Discover tab, and the intro is no longer visible behind it.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-06 — Existing user upgrading to build 8 sees the intro once; notification prompt still handled

**Preconditions:** Device with build 7 (or earlier) installed, already onboarded and signed in, notifications already decided (allowed or denied). Install build 8 from TestFlight over it, do not delete the app.

**Steps:**
1. Launch build 8. Note what shows on landing.
2. Tap **Skip** or walk through and tap **Let's go**.
3. Note whether any notification dialog shows.
4. Force-quit and relaunch.

**Expected:** The existing user lands straight in the main app with the intro on top (no onboarding again, account and profile intact); after closing the intro no notification dialog appears because permission was already decided, the app continues normally, and the intro does not show again on relaunch.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-07 — Settings → "How Melora works" reopens the intro without re-arming first-run

**Preconditions:** Intro has already been seen on this install (INTRO-04).

**Steps:**
1. Go to the Profile tab → gear icon → Settings.
2. Scroll to the About section and tap **How Melora works**.
3. Walk through all three pages, then tap **Let's go**. Note where you land.
4. Reopen it once more and this time tap **Skip**.
5. Tap **Done** to close Settings, switch to Discover, force-quit and relaunch the app.

**Expected:** "How Melora works" opens the identical three-page intro full screen; both "Let's go" and "Skip" return you to the Settings list (not to Discover); no notification dialog appears; after relaunch the intro is not shown automatically.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-08 — Discover song hint appears above the first live card only when someone is live

**Preconditions:** Fresh install past the intro, or an existing install where you have never tapped a song or the hint's X since build 8. Have one nearby person (or test account) live, and a way to make nobody live (e.g. slide the radius down until the list is empty, or ask them to stop).

**Steps:**
1. Open Discover with the radius set so at least one live card is in the list.
2. Look at the area between the "Live now · N" header and the first card.
3. Slide the radius down (or wait) until "Nobody is live…" is shown. Look for the hint.
4. Switch the mode picker to **Following** with no one you follow live, then back to **Nearby** with a live card.
5. Pull to refresh.

**Expected:** With at least one live card, a single compact card reads "Tap a song to play it, like it or say hi." with an orange play dot on the left and a small X on the right, sitting directly above the first live card; with an empty feed (nobody live, or Following with nobody live) the hint is not shown at all; it reappears when live cards come back; refreshing does not duplicate it.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-09 — Song hint dismisses via X and via the first song tap, and never returns

**Preconditions:** Two installs or two runs (delete + reinstall between them), each with the song hint visible (INTRO-08).

**Steps:**
1. Run A: tap the **X** on the hint. Watch how it leaves. Scroll, change radius, pull to refresh, switch tabs, force-quit and relaunch, and return to Discover with a live card visible.
2. Run B: with the hint visible, tap the **song title** (or the album artwork on the right) on any live card. Close the song sheet. Repeat the checks from step 1.
3. Run B extra: before tapping a song, tap the person's name / expand the card without opening the song sheet. Note whether the hint is still there.

**Expected:** In run A the hint fades out in place (short, quiet fade, cards slide up gently) and never comes back after any navigation, refresh or relaunch; in run B the song sheet opens and, when closed, the hint is gone for good in the same way; expanding the card or tapping the name without opening a song does not dismiss the hint.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |

---

## INTRO-10 — Welcome screen + intro do not feel like the same thing twice; UX guideline conformance

**Preconditions:** Fresh install. Hand the phone to someone who has never seen Melora (ideally 16–25) and stay silent.

**Steps:**
1. Let them read the welcome screen (ripple, "Share what you're playing. Meet the people around you through music.", the Go live / Discover / Connect rows) and tap Get started.
2. Let them complete onboarding and go through the three intro pages at their own pace. Time it.
3. Right after "Let's go", ask them: "What does this app do, and what happens when you tap a song?"
4. Ask: "Did any screen feel like it was repeating an earlier one, or like it was lecturing you?"
5. On your own, review each intro page: text fits without truncation on the smallest supported iPhone (SE / mini class) and on a Max, with Larger Text turned up one step; the only motion is the slow ripple, the dot sliding and the page slide; colours match the rest of the app (dark background, orange primary, serif song titles).

**Expected:** The tester can explain "go live with your Spotify song, see nearby people and their songs, tap a song to play/like/message" within 20 seconds of finishing the intro, says it did not feel repetitive or preachy (welcome = one-breath pitch with three short rows; intro = three illustrated one-sentence pages that add the how, e.g. radius, rough distance, like-back → chat), and the visual review finds no truncated text, no flashy animation, and no "developer UI" element on any page.

| Tester | Device / iOS | Date | Result (Pass/Fail) | Notes |
|---|---|---|---|---|
|  |  |  |  |  |
