# Photo System Improvements

## Summary of Changes

I've fixed the photo display issues and implemented a dual-photo system for hero images to ensure the profile view shows uncropped photos while discovery cards use cropped versions.

## Key Issues Resolved

### 1. **Hero Photo Cropping Problem** ✅
**Problem**: During onboarding, the first photo was cropped to a square/circle for avatar use, but this cropped version was also being used as the large hero image in the profile view, which looked poor.

**Solution**: Implemented a dual-photo system:
- `heroPhotoURL` - Stores the **uncropped, full-size** image for profile display
- `photoURLs[0]` - Stores the **cropped/square** version for discovery cards and small avatars

### 2. **"More Photos" Display Issues** ✅
**Problem**: The photo gallery was not displaying well - unclear feedback and no visual polish.

**Solution**: Enhanced the gallery with:
- Photo counter ("X of 5")
- Loading states with ProgressView
- Error states with helpful messages
- Photo number badges
- Helper text when photos are missing
- Better spacing (14pt)
- Improved error handling

## Technical Implementation

### Updated Models

#### UserProfile.swift
```swift
struct UserProfile {
    var photoURLs: [String]       // Cropped versions for cards/avatars
    var heroPhotoURL: String?     // NEW: Uncropped hero image
    
    // Returns uncropped hero, falls back to first photo, then Spotify avatar
    var displayHeroPhotoURL: String? { ... }
    
    // Returns cropped profile photo (for discovery cards)
    var croppedProfilePhotoURL: String? { ... }
}
```

### Updated Services

#### OnboardingProfileService.swift
Added new methods:
- `uploadHeroPhoto(image:uid:)` - Uploads uncropped hero photo to `hero_photo.jpg`
- `saveHeroPhotoURL(_:uid:)` - Saves hero URL to Firestore field `heroPhotoURL`

#### ProfileService.swift
Exposed the new hero photo methods for profile editing.

### Updated ViewModels

#### ProfileViewModel.swift
- Added `heroImageChanged: Bool` to `ProfileDraft` to track hero photo changes
- Updated `setDraftSelectedImage` to flag when hero image (index 0) is changed
- Enhanced `saveDraftChanges` to:
  - Upload uncropped version as hero photo
  - Upload cropped version to photoURLs[0]
  - Handle other photos normally (indices 1-5)

#### OnboardingStepPhotosView.swift
- Added `originalHeroImage` state to preserve uncropped image
- Updated cropper callback to store both versions
- Passes original to ViewModel for upload

### Updated Views

#### ProfileView.swift

**Preview Mode - Photo Gallery:**
- 2-column grid with 14pt spacing
- Photo counter header ("X of 5")
- Individual photo badges (#2, #3, etc.)
- Loading states with spinner
- Error states with icon and message
- Helper text when < 5 photos
- Better aspect ratio (3:4 portrait)

**Preview Mode - Hero Image:**
- Uses `displayHeroPhotoURL` (uncropped version)
- Large 420pt height display
- Gradient overlay for text readability
- Name, age, city, gender overlaid

**Edit Mode - Hero Photo:**
- Large 280pt preview (not tiny circle)
- Clear "Tap to change" prompt
- Tracks if changed with `heroImageChanged` flag

## Photo Storage Structure

### Firebase Storage
```
userPhotos/
  {uid}/
    hero_photo.jpg        # NEW: Uncropped hero image (high quality, 90% compression)
    photo_0.jpg          # Cropped square avatar (for discovery cards)
    photo_1.jpg          # Additional photos
    photo_2.jpg
    photo_3.jpg
    photo_4.jpg
    photo_5.jpg
```

### Firestore Document
```javascript
{
  heroPhotoURL: "https://..../hero_photo.jpg",  // NEW: Uncropped
  photoURLs: [
    "https://..../photo_0.jpg",  // Cropped avatar
    "https://..../photo_1.jpg",  // Additional photos
    "https://..../photo_2.jpg",
    // ... up to 6 total
  ]
}
```

## User Flow

### During Onboarding:
1. User selects profile photo
2. `AvatarCropperView` appears to crop it
3. **Original image** stored as `originalHeroImage`
4. **Cropped image** stored in `selectedImages[0]`
5. On save:
   - Upload original → `hero_photo.jpg` → `heroPhotoURL`
   - Upload cropped → `photo_0.jpg` → `photoURLs[0]`

### During Profile Editing:
1. User taps hero photo to change it
2. PhotoPicker opens (no cropper in edit mode currently)
3. New image selected → `heroImageChanged = true`
4. On save:
   - Upload uncropped → `heroPhotoURL`
   - Upload same (or cropped) → `photoURLs[0]`

### During Display:
- **Profile View (hero)**: Uses `displayHeroPhotoURL` (uncropped, full size)
- **Discovery Cards**: Uses `croppedProfilePhotoURL` (square, cropped)
- **Small Avatars**: Uses `croppedProfilePhotoURL` (square, cropped)

## Benefits

✅ **Profile view shows full, uncropped photos** - looks professional and premium
✅ **Discovery cards use cropped square photos** - consistent with card design
✅ **Better photo gallery** - clear, polished, with helpful feedback
✅ **Backward compatible** - Falls back gracefully if heroPhotoURL is missing
✅ **No data loss** - Original photos preserved, cropped versions for cards
✅ **Better compression** - Hero photo uses 90% quality, others use 85%

## Future Enhancements

Consider adding in the future:
1. **Cropper in edit mode** - Currently edit mode doesn't crop hero photos
2. **Automatic cropping** - Generate square crop from uncropped image server-side
3. **Multiple sizes** - Generate thumbnails for different use cases
4. **Photo reordering** - Drag to reorder gallery photos
5. **Photo zoom** - Tap to view full-size in preview mode

## Migration Notes

For existing users without `heroPhotoURL`:
- `displayHeroPhotoURL` falls back to `photoURLs.first`
- No breaking changes
- Encourage users to re-upload hero photo for best quality
