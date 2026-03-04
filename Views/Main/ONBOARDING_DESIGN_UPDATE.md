# Onboarding Design Update

## Overview
Updated the entire onboarding flow to match the modern dark gradient aesthetic used in NowPlayingView, LikesInboxView, and ProfileView.

## Changes Made

### 1. OnboardingFlowView.swift
**Background:**
- ❌ Removed: Bright gradient background (purple to cyan)
- ✅ Added: Dark gradient background matching the app's aesthetic
  - Color(red: 0.15, green: 0.15, blue: 0.2) → Color.black.opacity(0.95)
  - Top to bottom gradient

**Progress Bar:**
- Updated back button style to match likes inbox (circular with white opacity background)
- Changed progress bar colors:
  - Track: `Color.white.opacity(0.15)` (darker)
  - Fill: `Color(red: 0.2, green: 0.85, blue: 0.4)` (green accent)
  - Added smooth animation to progress changes

**Content Layout:**
- Removed white card container with shadow
- Content now sits directly on dark background for cleaner look
- Consistent padding of 20px horizontal

**Buttons:**
- Changed from rounded rectangles to Capsule shape
- Updated color to green accent: `Color(red: 0.2, green: 0.85, blue: 0.4)`
- Increased height from 52 to 54 points
- Improved disabled state opacity (0.4 vs 0.55)
- Updated font weight from .semibold to .bold

### 2. OnboardingStepBasicsView.swift
**Typography:**
- Title: Now pure white instead of AppColors.primaryText
- Subtitle: White with 60% opacity for better contrast
- Field labels: White with 50% opacity

**Input Fields:**
- Background: `Color.white.opacity(0.08)` - subtle glass-like effect
- Removed stroke overlay (cleaner look)
- Text color: Pure white
- Font weight: Updated to .medium for better readability

**Date Picker:**
- Added `.colorScheme(.dark)` for proper dark mode support
- Age badge: White text on `Color.white.opacity(0.15)` background

**Gender Selector:**
- Selected state:
  - Background: Green accent with 30% opacity
  - Border: Green accent (2px)
  - Text: White
- Unselected state:
  - Background: `Color.white.opacity(0.08)`
  - Border: `Color.white.opacity(0.15)` (1px)
  - Text: White
- Corner radius: 12 (slightly smaller for modern look)

### 3. OnboardingStepPhotosView.swift
**Typography:**
- Title: Pure white
- Subtitle: White with 60% opacity

**Photo Counter:**
- Background: `Color.white.opacity(0.08)` (glass effect)
- Text colors match new theme

**Photo Cards:**
- Background: `Color.white.opacity(0.08)` for empty states
- Empty state icons: White with 40% opacity
- Empty state text: White (varying opacities)
- "Profile" badge: Green accent `Color(red: 0.2, green: 0.85, blue: 0.4)`
- Border (empty): `Color.white.opacity(0.15)`
- Border (profile required): Green accent with 50% opacity

### 4. OnboardingStepSpotifyView.swift
**Typography:**
- Title: Pure white
- Subtitle: White with 60% opacity
- All body text: White with varying opacities

**Status Circle:**
- Connected: Green accent with 15% opacity background
- Not connected: `Color.white.opacity(0.08)`
- Icon colors updated to match theme

**Status Icon:**
- Checkmark (connected): Green accent `Color(red: 0.2, green: 0.85, blue: 0.4)`
- Music note (not connected): White with 40% opacity

**Feature List:**
- Icon color: Green accent
- Title: Pure white
- Description: White with 60% opacity

## Design Consistency

### Color Palette
All onboarding screens now use:
- **Background**: Dark gradient (Color(red: 0.15, green: 0.15, blue: 0.2) → Color.black.opacity(0.95))
- **Primary Accent**: Green `Color(red: 0.2, green: 0.85, blue: 0.4)`
- **Glass Effects**: `Color.white.opacity(0.08)` for backgrounds
- **Borders**: `Color.white.opacity(0.15)` for subtle definition
- **Text (Primary)**: Pure white
- **Text (Secondary)**: `Color.white.opacity(0.6)`
- **Text (Tertiary)**: `Color.white.opacity(0.5)`

### Typography
- **Headers**: `.system(size: 32, weight: .bold, design: .rounded)`
- **Subtitles**: `.system(size: 17, weight: .medium)`
- **Body**: `.system(size: 15-16, weight: .semibold/.medium)`
- **Labels**: `.system(size: 13, weight: .medium, design: .rounded)`
- **Buttons**: `.system(size: 17, weight: .bold, design: .rounded)`

### Spacing & Layout
- Screen padding: 20px horizontal
- Section spacing: 24px
- Element spacing: 12-16px
- Button height: 54px

## Benefits
1. ✅ **Visual Consistency**: Matches NowPlayingView, LikesInboxView, and ProfileView
2. ✅ **Modern Aesthetic**: Dark gradient with glass-morphism effects
3. ✅ **Better Contrast**: White text on dark backgrounds is easier to read
4. ✅ **Cohesive Brand**: Green accent color used throughout
5. ✅ **Professional Look**: Cleaner, more premium feel
6. ✅ **Reduced Visual Noise**: Removed unnecessary borders and shadows

## Testing Recommendations
- Test all three onboarding steps in sequence
- Verify text input is visible and keyboard behavior works correctly
- Confirm photo picker works on dark background
- Test Spotify connection flow
- Verify progress bar animation is smooth
- Test on various device sizes (especially smaller iPhones)
