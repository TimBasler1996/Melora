# UX Backlog

Product-level findings from the UX review of Dev3 (September 2026), grouped by epic and ranked by user impact. Code-level bugs found in the same review were fixed directly and are not listed here.

Priorities: **P0** must ship before launch · **P1** next · **P2** later · **P3** someday. Effort: S ≤ 1 day · M 2–4 days · L 1–2 weeks.

Totals: 53 items — P0 12 · P1 22 · P2 15 · P3 4 · done 14

## Decisions taken

- **UX-01** Give Discover something to show when nobody is live — Decided: ended broadcasts stay visible as 'Recently live' for 24 h (no distance filter), then are deleted.
- **UX-06** Bring the Discover card back to the guideline — Decided: rebuild the card to the guideline later (P2); the compact card stays for now.
- **UX-08** Decide the account model: Sign in with Apple or explicit 'Delete profile' — Decided: Sign in with Apple, linked to the anonymous uid (last onboarding step + Settings). 'Sign out' only for linked accounts; everyone gets 'Delete profile and data' with a double confirmation.
- **UX-16** Define and show what a declined request looks like to the sender — Decided: the sender is never told about a decline. Declined pairs can't like or message again; they see 'You've already reached out to X'.
- **UX-27** Reconsider asking for a last name — Decided: keep last name for now (used in the denormalised display name); revisit with the card redesign.
- **UX-31** Server-side nearby notifications — Decided: later. Locations are now fuzzed to a ~275 m grid, which makes a server-side matcher acceptable when it is built.

## Suggested order of work

1. Done: account model (UX-08), declined-request policy (UX-16), and the P0 set except the remaining P1/P2 work.
2. Next: P1 items epic by epic — blocked/hidden lists, report, welcome screen, Spotify step honesty, inbox fixes.
3. Then P2 polish, starting with the Discover card redesign.

## Discover & cold start

_Discover is the reason the app exists and today it is empty for almost every new user._

### UX-01 · Give Discover something to show when nobody is live

**P0 · before launch** · effort large (1–2 weeks) · **Done**

- **Problem:** Only people live within the radius in the last five minutes appear. A new user in a new city sees an empty feed and leaves.
- **Fix:** Add a 'Recently live near you' section (last 24 h, faded, no distance), widen the default radius automatically until there are results, and make the empty state a call to action: go live and get notified when someone is near.
- **Needs:** Decided: ended broadcasts stay visible as 'Recently live' for 24 h (no distance filter), then are deleted.

### UX-02 · Add a location-denied state and disable the radius slider without location

**P0 · before launch** · effort small (≤1 day) · **Done**

- **Problem:** With location denied the slider looks live but filters nothing, cards show no distance and the empty state blames other users.
- **Fix:** Dedicated state 'Turn on location to see who is near you' with an Open Settings button; hide the slider until a location exists.

### UX-03 · Make the empty state respect the radius

**P0 · before launch** · effort small (≤1 day) · **Done**

- **Problem:** With a 5 km radius and people live at 30 km the user reads 'No one is live right now'.
- **Fix:** When broadcasts exist outside the radius say 'Nobody live within 5 km' with a one-tap 'Widen radius' action.

### UX-04 · Turn the message button into 'Open chat' after sending

**P1 · next** · effort small (≤1 day) · **Done**

- **Problem:** After a message is sent the paperplane turns green and further taps silently do nothing.
- **Fix:** Replace the button with 'Open chat' that opens the pending conversation, or show a 'Request sent' chip on the card.

### UX-05 · Let users undo 'Not interested' and see what they hid

**P1 · next** · effort medium (2–4 days) · **Partly done**

- **Problem:** Muting a song hides it for every future broadcaster forever, muting a person is permanent, and neither is visible or reversible anywhere.
- **Fix:** Undo toast right after muting; 'Hidden songs and people' list in Settings; consider making song mutes session-only.
- **Progress:** Dialog copy now says hidden songs/people can be restored in Settings; the Settings list itself is still open.

### UX-06 · Bring the Discover card back to the guideline

**P2 · later** · effort large (1–2 weeks)

- **Problem:** The guideline asks for a dominant hero photo with name, age, city and distance; the shipped card is a small avatar row without age or city.
- **Fix:** Decide: either update the guideline or rebuild the card with hero photo, name + age, track large, artist small, city, distance.
- **Needs:** Decided: rebuild the card to the guideline later (P2); the compact card stays for now.

### UX-07 · Hide incomplete or ghost profiles from Discover and follower lists

**P2 · later** · effort small (≤1 day)

- **Problem:** Profiles without photos or with a blank name render as 'No photo' and 'Unknown', which looks broken.
- **Fix:** Filter out profiles that fail the completeness rule before showing them anywhere.

## Account, safety & privacy

_Anonymous auth, exact locations and no report path are launch blockers for a dating-adjacent app._

### UX-08 · Decide the account model: Sign in with Apple or explicit 'Delete profile'

**P0 · before launch** · effort medium (2–4 days) · **Done**

- **Problem:** Auth is anonymous. Reinstalling or tapping Sign out loses profile, photos, followers, likes and every chat forever, and the dialog only says 'Are you sure?'.
- **Fix:** Preferred: link Sign in with Apple to the anonymous uid so the account survives reinstall. Minimum: rename the action to 'Delete profile', explain exactly what is lost, require a second confirmation.
- **Needs:** Decided: Sign in with Apple, linked to the anonymous uid (last onboarding step + Settings). 'Sign out' only for linked accounts; everyone gets 'Delete profile and data' with a double confirmation.

### UX-09 · Actually delete or tombstone the data when a profile is deleted

**P0 · before launch** · effort medium (2–4 days) · **Done**

- **Problem:** After sign-out the old user document, photos, follow edges and conversations remain; followers still see a ghost that can never reply.
- **Fix:** Cloud Function on delete: remove the user doc, storage photos, follows in both directions, and mark conversations as closed for the other participant.
- **Needs:** UX-08

### UX-10 · Fuzz location and show distance bands

**P0 · before launch** · effort small (≤1 day) · **Done**

- **Problem:** Exact coordinates are stored and distance is shown in meters, so anyone can pinpoint where a person is standing.
- **Fix:** Round stored positions to a ~250 m grid and show 'under 500 m', '1 km', '3 km' instead of exact meters.

### UX-11 · Add Block and Report to other people's profiles

**P1 · next** · effort medium (2–4 days)

- **Problem:** A profile reached from Discover, a like or a follower list offers only Follow. Reporting does not exist anywhere.
- **Fix:** Overflow menu with Block and Report; reports land in a 'reports' collection and trigger an email to the team.

### UX-12 · Blocked people list with unblock

**P1 · next** · effort medium (2–4 days)

- **Problem:** Block is a one-way door: no list, no unblock, and the button sits in a destructive-styled dialog that is easy to fat-finger.
- **Fix:** Settings → 'Blocked people' with unblock, plus an undo toast right after blocking.

### UX-13 · Blocking from Discover should also close the chat and clear the badge

**P1 · next** · effort small (≤1 day) · **Done**

- **Problem:** Blocking from Discover leaves an unread badge lit on a conversation that is no longer visible.
- **Fix:** Delete the conversation on block (as the chat menu does) and exclude blocked users from the unread count.

### UX-14 · Privacy controls and legal links in Settings

**P2 · later** · effort medium (2–4 days)

- **Problem:** Settings admits 'Your broadcast is always visible to everyone' and has no privacy policy, terms or support link.
- **Fix:** Privacy section (who can see me, distance precision) and Legal / Support rows.

## Like → request → chat loop

_Both sides of an interaction need to see the same truth at every step._

### UX-15 · Roll the heart back when a like fails

**P0 · before launch** · effort small (≤1 day) · **Done**

- **Problem:** The heart turns red before the write; on failure it stays red and the card refuses further taps, so the like never happened and cannot be retried.
- **Fix:** Reset the card state on failure and let the tap fire again; keep the burst animation immediate.

### UX-16 · Define and show what a declined request looks like to the sender

**P0 · before launch** · effort medium (2–4 days) · **Done**

- **Problem:** A declined request simply disappears from 'Waiting for response'; the Discover card still shows the sent state; a retry produces 'Please try again' which can never work.
- **Fix:** Keep a quiet 'Not accepted' row (or none, but say so once), reflect it on the Discover card, and show the honest reason instead of a retry prompt. Don't create a fresh like for a declined pair.
- **Needs:** Decided: the sender is never told about a decline. Declined pairs can't like or message again; they see 'You've already reached out to X'.

### UX-17 · Reconcile 'like first, then message' into one thing to act on

**P0 · before launch** · effort medium (2–4 days) · **Done**

- **Problem:** The recipient gets a pending like in the Likes inbox and a message request in Chats from the same person. Ignoring the like silently deletes the unread message.
- **Fix:** Attach the message to the existing like so it moves to Message Requests, or show 'also sent you a message → open request' on the like row; never let Ignore delete an unread message.

### UX-18 · Route push notifications to the right screen

**P0 · before launch** · effort medium (2–4 days) · **Done**

- **Problem:** Every push opens whatever tab was last open.
- **Fix:** Handle notification taps: like → Likes inbox, message or request → that conversation, accepted → that chat.

### UX-19 · Make the Likes inbox reachable from Profile and Chats

**P1 · next** · effort small (≤1 day)

- **Problem:** The inbox is only a heart icon on the Now tab. People look for 'who liked me' in Profile or Chats; the Likes stat on the profile is not tappable.
- **Fix:** Tapping the Likes stat opens the inbox; add an entry above Message Requests in Chats.

### UX-20 · One vocabulary for the whole loop

**P1 · next** · effort small (≤1 day)

- **Problem:** 'Ignore' in the likes inbox vs 'Decline' in chat; pushes say 'accepted your interaction'; Discover says 'broadcasts' while Now says 'go live'.
- **Fix:** Settle on: like, message request, accept, decline, live. Apply to labels, empty states and push copy.

### UX-21 · Show what needs action in the likes cluster rows

**P2 · later** · effort small (≤1 day)

- **Problem:** Rows only say '3 likes'; pending, accepted and ignored likes sit together forever.
- **Fix:** Show '2 new' or '1 pending' per row, sort rows with pending likes first, collapse ignored ones.

### UX-22 · Recover when 'Open chat' from an accepted like hits a deleted conversation

**P2 · later** · effort small (≤1 day)

- **Problem:** If either side deleted the chat the screen shows 'Conversation not found' with a Retry that can never succeed.
- **Fix:** Offer 'Start a new chat' that recreates the conversation.

## First run & onboarding

_The first ninety seconds decide whether the profile gets finished._

### UX-23 · Add a welcome screen and move the location prompt to first go-live

**P1 · next** · effort medium (2–4 days)

- **Problem:** The app opens straight into a form, and the system location prompt fires on the loading screen before the user has seen anything.
- **Fix:** One screen: broadcast what you play, meet people through music. Ask for location the first time the user toggles live, with a sentence explaining why.

### UX-24 · Make the Spotify step honest and cancel-aware

**P1 · next** · effort small (≤1 day)

- **Problem:** Copy promises 'matches' and 'music compatibility' the app does not have and claims only basic profile access while requesting playback control. Cancelling the login sheet leaves 'Connecting…' for ninety seconds.
- **Fix:** Rewrite the three feature rows to what the app does; detect the cancelled web session and return to the buttons immediately.

### UX-25 · Don't re-upload photos on every finish retry; show progress

**P1 · next** · effort medium (2–4 days)

- **Problem:** Finishing uploads all photos each attempt with only 'Finishing…' as feedback; a failure at the last step redoes everything.
- **Fix:** Upload photos once as they are picked (or cache uploaded URLs), and show a per-step progress line while finishing.

### UX-26 · Explain that the birthday is permanent, and label optional fields

**P2 · later** · effort small (≤1 day)

- **Problem:** Birthday can never be changed later and nothing says so; 'Looking for' is optional but not marked.
- **Fix:** Caption under the birthday picker; '(optional)' on Looking for.

### UX-27 · Reconsider asking for a last name

**P2 · later** · effort small (≤1 day)

- **Problem:** Last name is required but the app only ever shows 'First Last' in a few denormalised places; dating-style apps show first names.
- **Fix:** Make last name optional or drop it, show first name everywhere.
- **Needs:** Decided: keep last name for now (used in the denormalised display name); revisit with the card redesign.

## Now tab & going live

_Going live is the first action of the loop; it must feel safe and understood._

### UX-28 · Explain why the live toggle is disabled and warn when location is off while live

**P1 · next** · effort small (≤1 day)

- **Problem:** The toggle is greyed out with no reason when nothing is playing. With location denied the user goes live but is invisible to nearby people.
- **Fix:** Caption 'Play something on Spotify to go live'; when live without location show 'Enable location so people nearby can find you'.

### UX-29 · Replace raw error strings under the toggle

**P1 · next** · effort small (≤1 day)

- **Problem:** 'Broadcast update failed: …' and Firestore messages appear as body text.
- **Fix:** Map to 'Couldn't update your broadcast. Retrying…' and keep the detail in logs.

### UX-30 · Tell the user when a broadcast auto-ends

**P2 · later** · effort small (≤1 day)

- **Problem:** After ten idle minutes the broadcast stops; the message only appears if the Now tab is open.
- **Fix:** Local notification 'Your broadcast ended because nothing was playing'.

### UX-31 · Server-side nearby notifications

**P3 · someday** · effort large (1–2 weeks)

- **Problem:** 'Someone nearby is live' only works while the app is running because it is computed on the device.
- **Fix:** A function that matches new broadcasts against recent user locations and pushes; depends on the location-precision decision.
- **Needs:** Decided: later. Locations are now fuzzed to a ~275 m grid, which makes a server-side matcher acceptable when it is built.

## Profile

_Editing must never lose work or lock the user out._

### UX-32 · Keep the editor on screen when a save fails; validate before uploading

**P0 · before launch** · effort medium (2–4 days) · **Done**

- **Problem:** A failed save replaces the editor with a grey sentence, no retry; the only exit discards everything although name and city were already written.
- **Fix:** Inline error banner with Retry above the still-visible editor, keep the draft, check the 2–5 photo rule and required fields locally before any upload.

### UX-33 · Validate required fields in the editor

**P0 · before launch** · effort small (≤1 day) · **Done**

- **Problem:** Saving with an empty name or city succeeds and sends the user back through onboarding on the next launch.
- **Fix:** Disable Save and show why when first name, last name, city or gender is empty, matching the onboarding rules.

### UX-34 · Show success after saving without the loading flash

**P1 · next** · effort small (≤1 day)

- **Problem:** The 'Changes saved' pill lives in edit mode, which closes on save; the user sees 'Loading profile…' then stale stats.
- **Fix:** Toast on the preview, update the profile in place, refresh stats.

### UX-35 · Explain photo rules in the editor and fix re-picking

**P1 · next** · effort small (≤1 day) · **Partly done**

- **Problem:** Min 2 / max 5 only surfaces as an error after upload; removing a photo then picking the same one again does nothing; Discard asks in one place and not the other.
- **Fix:** Subtitle '2–5 photos · first is your profile picture', a live counter, disable X on the last two, clear the picker on remove, confirm Discard consistently.
- **Progress:** Discard now confirms; photo-rule hint shows before saving. Re-pick and counter still open.

### UX-36 · Friendly load errors with Retry on own and other profiles

**P1 · next** · effort small (≤1 day)

- **Problem:** 'Profile not found.' or 'No Firebase user.' appear as body text with no way forward.
- **Fix:** Human copy plus a Retry button; hide the mode picker while nothing is loaded.

### UX-37 · Read-only birthday row in the editor

**P2 · later** · effort small (≤1 day)

- **Problem:** Age is prominent in preview but there is no birthday field in edit mode and nothing says it is fixed.
- **Fix:** Show 'Birthday · 27' read-only with 'Age can't be changed after sign-up'.

### UX-38 · City picker: cities only, store the city name

**P2 · later** · effort small (≤1 day)

- **Problem:** Suggestions include street addresses and the saved value becomes 'Berlin, Germany'.
- **Fix:** Filter completer results to locality level and store just the city.

### UX-39 · Make the stats strip readable and tappable where it should be

**P2 · later** · effort small (≤1 day)

- **Problem:** '0min / Broadcast' is cryptic; Followers is tappable with no affordance; Likes for others starts at zero until the counter fills.
- **Fix:** 'Time on air 2 h 15 m', chevron on Followers, show '—' while loading or when unknown.

### UX-40 · Make 'This is how others see you' true

**P3 · someday** · effort small (≤1 day)

- **Problem:** Own preview and the visitor layout differ (Follow bar, nav title, likes count source).
- **Fix:** Render the visitor layout for the own preview, or soften the label to 'Preview'.

## Chats & inboxes

_Inboxes must show what needs action and never lie about state._

### UX-41 · Chat delete failure as a toast, not the full-screen error

**P1 · next** · effort small (≤1 day)

- **Problem:** A failed delete shows 'Couldn't load chats' with a Retry that re-subscribes.
- **Fix:** Transient alert like the chat screen already uses.

### UX-42 · Followers tab keeps followers after they are seen

**P1 · next** · effort small (≤1 day)

- **Problem:** The tab only lists followers newer than last-seen; on reopen it says 'No New Followers' even with fifty followers.
- **Fix:** List all recent followers with a 'New' marker; mark seen when the inbox is dismissed, not when a detail is pushed.

### UX-43 · Follow-back must not report success on failure

**P1 · next** · effort small (≤1 day)

- **Problem:** The follow-back row flips to 'Following' even when the write failed; profile follow failures revert silently.
- **Fix:** Optimistic with rollback and a 'Couldn't follow' toast, like Discover already does.

### UX-44 · Message Requests list must reflect accept and decline immediately

**P2 · later** · effort small (≤1 day)

- **Problem:** The list is a value copy; after declining and popping back the row can still be there and opens a declined chat with a composer.
- **Fix:** Drive the list from the view model and give the chat screen an explicit declined state.

### UX-45 · Relative timestamps in chat rows

**P2 · later** · effort small (≤1 day)

- **Problem:** 'Sep 9, 2026, 3:42 PM' under a 'Today' header.
- **Fix:** Time for today, weekday for this week, short date otherwise.

### UX-46 · Find People: tappable rows, real error state, surname search

**P2 · later** · effort small (≤1 day)

- **Problem:** Rows can't open a profile, any error looks like 'No results', and searching by last name finds nothing.
- **Fix:** Row tap opens the profile; distinct error state with Retry; search on first and last name.

### UX-47 · Clear inbox badges per tab and mark new rows

**P3 · someday** · effort small (≤1 day)

- **Problem:** Opening the Likes tab clears the Followers badge too; nothing in the list shows which items are new.
- **Fix:** Per-tab seen state and a 'New' dot on unseen rows.

## Settings

_Every control must do what it says; expected controls must exist._

### UX-48 · Remove or implement the 'New followers' toggle

**P1 · next** · effort small (≤1 day)

- **Problem:** The toggle is connected to nothing.
- **Fix:** Either remove it or add an onFollowCreated push that honours it.

### UX-49 · Spotify connection row in Settings

**P1 · next** · effort small (≤1 day)

- **Problem:** Connect, disconnect and refresh are only reachable through the Now tab's disconnected state.
- **Fix:** Account section row showing connection state with Connect / Disconnect.

### UX-50 · Reflect iOS notification permission in the toggles

**P1 · next** · effort small (≤1 day)

- **Problem:** Toggles stay on when notifications are denied at system level and nothing arrives.
- **Fix:** Inline 'Notifications are off in iOS Settings — Enable' row when permission is denied.

## Copy & polish

_Calm, premium tone means one vocabulary and no debug text._

### UX-51 · Map raw technical errors to human copy everywhere

**P1 · next** · effort small (≤1 day)

- **Problem:** 'Not authenticated.', 'User document not found.' and verbatim Firestore or Storage messages reach the screen.
- **Fix:** One error-to-copy mapping used by all screens; technical detail stays in logs.

### UX-52 · Calm system copy: no emoji toasts, lowercase status pills

**P2 · later** · effort small (≤1 day)

- **Problem:** 'Accepted ✅ Chat created ✅', 'PENDING / IGNORED' pills, 'Say hi 👋', 'Something went wrong' as every alert title.
- **Fix:** Plain-language toasts as overlays, soft pills, specific alert titles.

### UX-53 · Small copy fixes

**P3 · someday** · effort small (≤1 day)

- **Problem:** 'Open for all' capitalisation, 'Your Name' fallback shown as a real name, 'Search city...' under a 'City' label, Chats empty state explains only one way a chat starts.
- **Fix:** 'Open to all', neutral fallback 'New member', 'Which city?', 'Chats start when you accept someone's like or request, or they accept yours.'
