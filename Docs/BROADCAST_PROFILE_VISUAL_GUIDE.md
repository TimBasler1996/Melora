# Broadcast Profile View - Visual Structure

## Layout Hierarchy

```
┌─────────────────────────────────────────┐
│  [X]                            (Close) │  ← Floating close button
│                                         │
│         HERO IMAGE (480pt)              │
│                                         │
│     [Blurred background fill]           │
│     [Main image - scaledToFit]          │
│                                         │
│     ┌─────────────────────────────┐     │
│     │ Gradient Overlay (bottom)   │     │
│     │                             │     │
│     │ Sarah, 28                   │ 32pt bold
│     │ 📍 Berlin · 450m away       │ 16pt medium
│     └─────────────────────────────┘     │
└─────────────────────────────────────────┘
         ↓ Scroll begins here ↓
┌─────────────────────────────────────────┐
│  [Padding: 24pt top, 20pt sides]        │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ [Female] [DE]               Info  │  │ ← Info Chips
│  └───────────────────────────────────┘  │
│                                         │
│  CURRENTLY BROADCASTING          13pt   │
│  ┌───────────────────────────────────┐  │
│  │  ┌──┐                            │  │
│  │  │  │  Electric Feel        17pt│  │
│  │  │♪│  MGMT                  15pt│  │
│  │  │  │  Oracular Spectacular 13pt│  │
│  │  └──┘                     [🎵]   │  │
│  │   64x64                     Spotify│  │
│  └───────────────────────────────────┘  │
│                                         │
│  YOUR INTERACTION                 13pt  │ ← Only if interacted
│  ┌───────────────────────────────────┐  │
│  │ [❤️ Liked] [💬 Messaged]         │  │
│  └───────────────────────────────────┘  │
│                                         │
│  MORE PHOTOS                      13pt  │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │      Photo 2 (280pt height)      │  │
│  │   [Blurred bg + fitted image]    │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │      Photo 3 (280pt height)      │  │
│  │   [Blurred bg + fitted image]    │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ ❤️ Like                    50pt   │  │ ← Action buttons
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ 💬 Send message            50pt   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [If message tapped]                    │
│  ┌───────────────────────────────────┐  │
│  │ Your message              Caption │  │
│  │ ┌─────────────────────────────┐   │  │
│  │ │ Say something nice…         │   │  │
│  │ │                             │   │  │
│  │ └─────────────────────────────┘   │  │
│  │                                   │  │
│  │ ┌─────────────────────────────┐   │  │
│  │ │    ✈️ Send            Button│   │  │
│  │ └─────────────────────────────┘   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [Padding: 32pt bottom]                 │
└─────────────────────────────────────────┘
```

## Color Scheme

### Backgrounds
```
Main Background:
  LinearGradient(
    colors: [
      Color(red: 0.12, green: 0.12, blue: 0.18),  // Dark blue-grey
      Color.black.opacity(0.98)                     // Near black
    ],
    startPoint: .top,
    endPoint: .bottom
  )

Card Backgrounds: 
  Color.white.opacity(0.06)    // Very subtle white tint

Hero Gradient Overlay:
  [Clear → Black 30% → Black 75%]
```

### Interaction Colors
```
Like Button:
  Active:   Color(red: 1.0, green: 0.27, blue: 0.33)    // Red
  Disabled: Same with 60% opacity
  
Message Button:
  Active:   Color(red: 0.2, green: 0.85, blue: 0.4)     // Green
  Disabled: Same with 40% opacity

Like Badge:
  Color:      Red (same as button)
  Background: Red with 15% opacity

Message Badge:
  Color:      Green (same as button)
  Background: Green with 15% opacity
```

### Text Colors
```
Primary (Name):      white
Secondary (Details): white.opacity(0.9)
Muted (Labels):      white.opacity(0.6)
```

## Interaction States

### State 1: No Interaction (First View)
```
┌────────────────────────────────┐
│ ❤️ Like                        │  ← Red, enabled
└────────────────────────────────┘
┌────────────────────────────────┐
│ 💬 Send message                │  ← Green, enabled
└────────────────────────────────┘

[No "Your Interaction" section shown]
```

### State 2: Already Liked
```
YOUR INTERACTION
┌────────────────────────────────┐
│ ❤️ Liked                       │  ← Red badge
└────────────────────────────────┘

┌────────────────────────────────┐
│ ❤️ Liked                       │  ← Red (muted), disabled
└────────────────────────────────┘
┌────────────────────────────────┐
│ 💬 Send message                │  ← Green, enabled
└────────────────────────────────┘
```

### State 3: Already Messaged
```
YOUR INTERACTION
┌────────────────────────────────┐
│ 💬 Messaged                    │  ← Green badge
└────────────────────────────────┘

┌────────────────────────────────┐
│ ❤️ Like                        │  ← Red, enabled
└────────────────────────────────┘
┌────────────────────────────────┐
│ 💬 Already sent message        │  ← Grey, disabled
└────────────────────────────────┘
```

### State 4: Liked AND Messaged
```
YOUR INTERACTION
┌────────────────────────────────┐
│ ❤️ Liked    💬 Messaged        │  ← Both badges
└────────────────────────────────┘

┌────────────────────────────────┐
│ ❤️ Liked                       │  ← Red (muted), disabled
└────────────────────────────────┘
┌────────────────────────────────┐
│ 💬 Already sent message        │  ← Grey, disabled
└────────────────────────────────┘
```

## Typography Scale

```
Hero Name:           32pt, bold, rounded
Hero Location:       16pt, medium, rounded
Section Labels:      13pt, semibold, rounded, uppercase, tracking: 0.5
Track Title:         17pt, semibold, rounded
Track Artist:        15pt, medium, rounded
Track Album:         13pt, regular, rounded
Button Text:         17pt, bold, rounded
Chip Text:           13pt, semibold, rounded
Badge Text:          14pt, semibold, rounded
Message Caption:     13pt, semibold, rounded
Message Input:       16pt, regular, rounded
```

## Spacing System

```
Outer Padding:         20pt (horizontal)
Section Spacing:       24pt (between major sections)
Card Internal:         16pt
Button Vertical:       16pt
Button Horizontal:     20pt
Chip Horizontal:       12pt
Chip Vertical:         8pt
Badge Horizontal:      14pt
Badge Vertical:        10pt
Photo Gap:             12pt
```

## Corner Radius System

```
Large Cards:         16pt (photos, track card, interaction card)
Buttons:             16pt
Medium:              14pt (message input, send button)
Artwork:             12pt
Chips:               Capsule
Badges:              Capsule
Close Button:        Circle
```

## Shadow System

```
Photo Cards:
  color:   Color.black.opacity(0.2)
  radius:  12pt
  x:       0
  y:       6

Close Button:
  color:   Color.black.opacity(0.3)
  radius:  8pt
  x:       0
  y:       4
```

## Animation Specifications

```
Message Field Appearance:
  animation: .easeInOut(duration: 0.25)
  transition: .opacity.combined(with: .move(edge: .top))

Image Transitions:
  transaction: animation = nil  (instant)
  
Sheet Presentation:
  presentationDetents: [.large]
  presentationDragIndicator: .visible
```

## Responsive Behavior

### Image Handling
```
Hero Image:
  - Background: Blurred, scaledToFill
  - Foreground: Clear, scaledToFit
  - Result: Always fills space, never cropped awkwardly

Additional Photos:
  - Same approach as hero
  - Fixed 280pt height ensures consistency
  - Blur prevents letterboxing issues
```

### Text Handling
```
Name:
  - lineLimit: 1
  - minimumScaleFactor: 0.9
  - Ensures long names scale down slightly

Track Info:
  - All lineLimit: 1
  - Truncates with ellipsis if too long
```

## Accessibility

```
Close Button:
  - accessibilityLabel: "Close"
  - Minimum tap target: 36x36pt

All Buttons:
  - Minimum tap target: 44pt height
  - Clear visual feedback
  - Proper disabled states

Text Contrast:
  - White on dark gradient: Pass (WCAG AAA)
  - Red on 15% red background: Pass
  - Green on 15% green background: Pass
```

## Component Breakdown

### Main View
- `BroadcastProfileView` - Container and coordinator

### Sub-views
- `InfoChip` - Gender, country code display
- `InteractionBadge` - Like and message state indicators

### Sections
1. Hero Section (heroSection)
2. Content Section (contentSection)
   - Info Chips (infoChipsSection)
   - Currently Playing (currentlyPlayingSection)
   - Interaction State (interactionStateSection) - conditional
   - Additional Photos (additionalPhotosSection) - conditional
   - Action Buttons (actionButtonsSection)
   - Message Section (messageSection) - conditional, animated

---

This visual structure ensures:
✅ Clean, uncluttered layout
✅ Clear information hierarchy
✅ Obvious interaction affordances
✅ Premium aesthetic
✅ Excellent readability
✅ Smooth user experience
