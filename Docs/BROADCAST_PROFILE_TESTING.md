# Quick Testing Guide - Broadcast Profile View

## What to Test

### 1. Basic Display ✓
**Flow:** Open Discover → Tap any broadcast card

**Expected:**
- [ ] Profile sheet opens smoothly from bottom
- [ ] Hero image loads and displays without cropping distortion
- [ ] Name and age visible over hero image with good contrast
- [ ] Location and distance (e.g., "Berlin · 450m away") clearly shown
- [ ] Gender and country chips appear below hero
- [ ] Close button (X) visible in top-right corner

**What Good Looks Like:**
- Images are centered and well-fitted (no awkward cropping)
- All text is readable against gradient overlay
- Layout feels spacious, not cramped

---

### 2. Track Information ✓
**Expected:**
- [ ] "CURRENTLY BROADCASTING" section visible
- [ ] Track artwork thumbnail (64x64) displays
- [ ] Track title, artist, and album clearly shown
- [ ] Spotify icon button appears (if track has Spotify link)
- [ ] Tapping Spotify button opens track in app/web

**What Good Looks Like:**
- Track info is prominent but not overwhelming
- Artwork has rounded corners and subtle border
- Text hierarchy is clear (title bigger than artist)

---

### 3. First Interaction (No Previous History) ✓
**Flow:** View a broadcast you haven't liked or messaged

**Expected:**
- [ ] NO "Your Interaction" section appears
- [ ] Like button shows "❤️ Like" in red, fully enabled
- [ ] Message button shows "💬 Send message" in green, fully enabled
- [ ] Tapping Like button:
  - Dismisses sheet
  - Marks broadcast as liked (test by reopening)
- [ ] Tapping Message button:
  - Shows message input field with animation
  - Field has placeholder "Say something nice…"
  - Send button appears below
  - Send button is disabled when field is empty

**What Good Looks Like:**
- Buttons are large and easy to tap
- Colors are vibrant and inviting
- Interaction feels responsive

---

### 4. After Liking ✓
**Flow:** Like a broadcast → Close sheet → Reopen same broadcast

**Expected:**
- [ ] "YOUR INTERACTION" section appears
- [ ] Red badge shows "❤️ Liked"
- [ ] Like button shows "❤️ Liked" with muted color (60% opacity)
- [ ] Like button is disabled (not tappable)
- [ ] Message button still active and green
- [ ] Can still send a message if desired

**What Good Looks Like:**
- Clear visual feedback that you already liked
- Badge is prominent but not intrusive
- Message option still inviting

---

### 5. After Sending Message ✓
**Flow:** Send message to a broadcast → Close sheet → Reopen same broadcast

**Expected:**
- [ ] "YOUR INTERACTION" section appears
- [ ] Green badge shows "💬 Messaged"
- [ ] Message button shows "💬 Already sent message" with muted color
- [ ] Message button is disabled
- [ ] Like button still active if not liked yet

**What Good Looks Like:**
- Clear indication that message was sent
- Prevents accidental duplicate messages
- Like still available as separate action

---

### 6. After Both Like and Message ✓
**Flow:** Like AND message same broadcast → Reopen

**Expected:**
- [ ] "YOUR INTERACTION" section appears
- [ ] TWO badges shown: "❤️ Liked" and "💬 Messaged"
- [ ] Both action buttons disabled and muted
- [ ] Clear indication of complete interaction

**What Good Looks Like:**
- Both badges side by side
- Obvious that all interactions are complete
- User knows they already engaged fully

---

### 7. Additional Photos ✓
**Flow:** View profile with multiple photos

**Expected:**
- [ ] "MORE PHOTOS" section appears
- [ ] Photos display in vertical stack
- [ ] Each photo is 280pt tall, full width
- [ ] Photos use same blurred background + fitted image technique
- [ ] Up to 6 additional photos shown (beyond hero)
- [ ] Smooth scrolling through photos

**What Good Looks Like:**
- All photos same size (consistent)
- No cropping issues or distortion
- Spacing is even between photos

---

### 8. Message Input Flow ✓
**Flow:** Tap "Send message" button

**Expected:**
- [ ] Message field appears with smooth animation
- [ ] Caption text "Your message" appears
- [ ] Text field has placeholder "Say something nice…"
- [ ] Field expands vertically (3-6 lines)
- [ ] Send button disabled when empty
- [ ] Send button enabled when text entered
- [ ] Typing works smoothly
- [ ] Tapping Send:
  - Sends message
  - Clears field
  - Collapses message section
  - Dismisses sheet
  - Marks broadcast as messaged

**What Good Looks Like:**
- Animation is smooth (0.25s ease)
- Field is easy to type in
- Clear feedback on send
- Can't send empty message

---

### 9. Close and Dismiss ✓
**Flow:** Various ways to close the sheet

**Expected:**
- [ ] Tapping X button closes sheet
- [ ] Swiping down closes sheet
- [ ] After sending like: sheet auto-closes
- [ ] After sending message: sheet auto-closes
- [ ] Sheet state resets on next open

**What Good Looks Like:**
- Closing is intuitive and smooth
- Returns to Discover feed properly
- No lingering state issues

---

### 10. State Persistence ✓
**Flow:** Like/message → Close app → Reopen app → View same broadcast

**Expected:**
- [ ] Liked state remembered across app launches
- [ ] Messaged state remembered across app launches
- [ ] Badges appear immediately on reopen
- [ ] Button states correct after restart

**What Good Looks Like:**
- State loads instantly from UserDefaults
- No need to re-download interaction history
- Consistent experience across sessions

---

## Edge Cases to Test

### Empty States
- [ ] User with no additional photos (only hero)
  - "More Photos" section should not appear
  
- [ ] User with no gender or country
  - Info chips section should handle gracefully
  
- [ ] Track with no album info
  - Track card should adjust layout
  
- [ ] Track with no artwork
  - Placeholder with music note icon appears

### Long Text
- [ ] Very long user name
  - Should scale down slightly (0.9x) to fit
  - Should not overflow container
  
- [ ] Long track title
  - Should truncate with ellipsis
  - Still readable
  
- [ ] Long city name
  - Should truncate if needed

### Network Issues
- [ ] Images fail to load
  - Placeholder should appear
  - No blank spaces or broken icons
  
- [ ] Slow image loading
  - Placeholder visible during load
  - Smooth transition when loaded

### Interactions
- [ ] Tap Like multiple times quickly
  - Should only register once
  - Button should disable after first tap
  
- [ ] Tap Message while Like is sending
  - Should work independently
  
- [ ] Type message then tap outside field
  - Field should stay visible with content

## Device & Orientation

### Screen Sizes to Test
- [ ] iPhone SE (smallest)
- [ ] iPhone 15/16 Pro (standard)
- [ ] iPhone 15/16 Pro Max (largest)
- [ ] iPad (if supported)

### Orientation
- [ ] Portrait (primary)
- [ ] Landscape (if supported)
  - Hero should adapt height
  - Content should remain readable

## Performance Checks

- [ ] Sheet opens smoothly (<0.3s)
- [ ] Images load without blocking UI
- [ ] Scrolling is smooth (60fps)
- [ ] No lag when tapping buttons
- [ ] Memory usage reasonable (check Instruments)
- [ ] No retain cycles (check leaks)

## Accessibility Checks

- [ ] VoiceOver reads all elements correctly
- [ ] All buttons have proper labels
- [ ] Text size respects system settings
- [ ] High contrast mode works
- [ ] Reduce motion respected (if animations added)
- [ ] All tap targets ≥44pt

## Common Issues & Solutions

### Issue: Hero image looks stretched
**Check:** 
- Background should be blurred scaledToFill
- Foreground should be clear scaledToFit
- Both should be in ZStack

### Issue: Interaction badges not showing
**Check:**
- viewModel.isLiked() returns true
- viewModel.hasMessage() returns true
- UserDefaults keys are correct

### Issue: State not persisting
**Check:**
- saveLikedBroadcastsToCache() is called after like
- saveMessagedBroadcastsToCache() is called after message
- Keys include user ID: "discover.likedBroadcasts.{uid}"

### Issue: Buttons still enabled after interaction
**Check:**
- .disabled(hasAlreadyLiked) on like button
- Button state updates when viewModel publishes changes

### Issue: Message field doesn't appear
**Check:**
- showMessageField state toggles on button tap
- withAnimation wrapper is present
- transition modifier is on message section

## Quick Smoke Test Checklist

30-second verification that everything works:

1. [ ] Open Discover
2. [ ] Tap any broadcast card → Sheet opens
3. [ ] Verify hero image + name visible
4. [ ] Scroll down → See track info
5. [ ] Tap Like → Sheet closes
6. [ ] Reopen same card → See "Liked" badge
7. [ ] Tap Message → Input appears
8. [ ] Type text → Tap Send → Sheet closes
9. [ ] Reopen same card → See both badges
10. [ ] Tap X → Returns to feed

**All 10 steps work = ✅ Ready to ship**

---

## Reporting Issues

When reporting a bug, include:
- Device model and iOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots or screen recording
- Console logs (if relevant)

## Testing Sign-off

**Tester:** ___________________
**Date:** ___________________
**Version:** 1.0
**Status:** ⬜ Pass  ⬜ Fail  ⬜ Needs Review

**Notes:**
_______________________________________
_______________________________________
_______________________________________
