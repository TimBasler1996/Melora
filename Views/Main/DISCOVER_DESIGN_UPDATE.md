# Discover View Design Update

## Overview
Updated the entire Discover section to match the modern dark gradient aesthetic used in NowPlayingView, LikesInboxView, ProfileView, and the onboarding flow.

## Changes Made

### 1. DiscoverView.swift
**Background:**
- ❌ Removed: Bright gradient background (purple to cyan)
- ✅ Added: Dark gradient background
  - Color(red: 0.15, green: 0.15, blue: 0.2) → Color.black.opacity(0.95)
  - Top to bottom gradient
- Added `.toolbarColorScheme(.dark, for: .navigationBar)` for proper navbar appearance

**Empty States:**
- **Loading**: Enhanced with larger ProgressView (1.2 scale) and better text styling
- **Error**: 
  - Added large warning triangle icon
  - Improved typography hierarchy (title: 20pt bold, body: 14pt medium)
  - Updated retry button to white capsule on dark background
  - Better spacing with Spacer() top and bottom
- **No Broadcasts**:
  - Added large music.note.list icon (64pt, thin weight)
  - Updated title to 24pt bold
  - Improved subtitle styling with better opacity
  - Enhanced overall empty state presentation

**Card Container:**
- Updated padding from `AppLayout.screenPadding` to consistent `20px`

### 2. DiscoverCardView.swift
**Card Background:**
- ❌ Removed: `AppColors.cardBackground` (light card)
- ✅ Added: `Color.white.opacity(0.08)` - subtle glass effect
- Updated corner radius to 20 for more modern look
- Enhanced shadow: `Color.black.opacity(0.3), radius: 20`

**Track Module:**
- **Title**: Changed from `AppColors.primaryText` to pure white
- **Artist**: Changed to `Color.white.opacity(0.7)`
- **Album**: Changed to `Color.white.opacity(0.5)`
- **Spotify Pill**:
  - Background: `Color.white.opacity(0.1)`
  - Text: `Color.white.opacity(0.7)`

**Artwork:**
- Placeholder gradient: Now uses white opacity gradients
  - From: `Color.white.opacity(0.15)` 
  - To: `Color.white.opacity(0.1)`
- Icon color: `Color.white.opacity(0.4)`
- Border: `Color.white.opacity(0.15)`

**Profile Module:**
- **Name & Age**: Pure white text
- **Location**: `Color.white.opacity(0.7)`
- **Gender/Country Badge**:
  - Background: `Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.2)` (green with transparency)
  - Text: Green accent color
- **Chevron**: `Color.white.opacity(0.3)`

**Divider:**
- Updated from `Color.black.opacity(0.06)` to `Color.white.opacity(0.1)`

**Hero Photo:**
- Background: `Color.white.opacity(0.08)`
- Placeholder: White opacity gradient
- Person icon: `Color.white.opacity(0.4)`
- Border: `Color.white.opacity(0.15)`

### 3. DiscoverDetailSheetView.swift
**Background:**
- ✅ Added: Full dark gradient background matching other views
  - Wrapped ScrollView in ZStack with gradient
  - Same gradient as main Discover view

**Track Header Card:**
- Background: `Color.white.opacity(0.08)` (glass effect)
- Corner radius: 16
- **Title**: Pure white
- **Artist**: `Color.white.opacity(0.7)`
- **Album**: `Color.white.opacity(0.5)`
- **Spotify link**: Green accent `Color(red: 0.2, green: 0.85, blue: 0.4)`

**Artwork Placeholder:**
- Gradient: White opacity gradients
- Icon: `Color.white.opacity(0.4)`

**Actions Section:**
- **Like Button**:
  - Background: Green accent `Color(red: 0.2, green: 0.85, blue: 0.4)`
  - Font weight: Bold (was semibold)
  - Larger padding for better touch target
- **Label**: `Color.white.opacity(0.6)` (was AppColors.secondaryText)
- **TextField**:
  - Background: `Color.white.opacity(0.08)`
  - Text color: Pure white
- **Send Button**:
  - Background: `Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8)`
  - Font weight: Bold

**Profile Section:**
- Background: `Color.white.opacity(0.08)`
- Label: `Color.white.opacity(0.6)`
- Corner radius: 16

## Design Consistency

### Color Palette
All Discover screens now use:
- **Background**: Dark gradient (Color(red: 0.15, green: 0.15, blue: 0.2) → Color.black.opacity(0.95))
- **Primary Accent**: Green `Color(red: 0.2, green: 0.85, blue: 0.4)`
- **Glass Effects**: `Color.white.opacity(0.08)` for cards
- **Borders**: `Color.white.opacity(0.15)` for subtle definition
- **Dividers**: `Color.white.opacity(0.1)`
- **Text (Primary)**: Pure white
- **Text (Secondary)**: `Color.white.opacity(0.7)`
- **Text (Tertiary)**: `Color.white.opacity(0.5)` - `0.6)`
- **Icons (Inactive)**: `Color.white.opacity(0.4)`
- **Icons (Subtle)**: `Color.white.opacity(0.3)`

### Typography
- **Large Titles**: `.system(size: 24, weight: .bold, design: .rounded)`
- **Section Titles**: `.system(size: 20, weight: .bold, design: .rounded)`
- **Card Titles**: `.system(size: 18, weight: .bold, design: .rounded)`
- **Body Text**: `.system(size: 14-17, weight: .medium/.semibold, design: .rounded)`
- **Small Labels**: `.system(size: 12-13, weight: .medium/.semibold, design: .rounded)`
- **Buttons**: `.system(size: 14-16, weight: .bold, design: .rounded)`

### Card Design
- Corner radius: 16-20px (larger for main cards)
- Background: Glass effect with 8% white opacity
- Shadows: More pronounced (`opacity: 0.3, radius: 20`)
- Padding: Consistent 16-20px
- Dividers: Subtle white opacity (10%)

### Empty States
- Large icons: 48-64pt with thin weight
- Icon opacity: 40%
- Vertical centering with Spacer()
- Clear hierarchy with title (20-24pt bold) and subtitle (14-15pt medium)
- Retry buttons: White capsule on dark background

## Benefits
1. ✅ **Visual Consistency**: Perfectly matches NowPlayingView, LikesInboxView, ProfileView, and Onboarding
2. ✅ **Modern Aesthetic**: Dark gradient with sophisticated glass-morphism effects
3. ✅ **Better Contrast**: White text on dark backgrounds provides excellent readability
4. ✅ **Cohesive Brand**: Green accent color used consistently throughout
5. ✅ **Professional Look**: Premium, music-focused aesthetic
6. ✅ **Improved Empty States**: More engaging and informative
7. ✅ **Enhanced Cards**: Glass effect creates depth without being distracting

## Testing Recommendations
- Test Discover view with and without broadcasts
- Verify card tap interactions and sheet presentation
- Test error states and retry functionality
- Confirm empty states display correctly
- Verify all text is readable on dark background
- Test sheet presentation with dark gradient background
- Confirm like and message actions work properly
- Test swipe-to-dismiss on cards
