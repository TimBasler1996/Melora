# 🏗️ Project Restructuring Guide

**Date:** January 30, 2026  
**Purpose:** Reorganize project files into a clean, maintainable architecture

---

## 📁 Recommended Folder Structure

```
YourProject/
├── Models/
│   ├── LocationPoint.swift
│   ├── AppUser.swift
│   ├── Track.swift
│   ├── TrackLike.swift
│   └── TrackLikesCluster.swift
│
├── Services/
│   ├── CurrentUserStore.swift
│   ├── TrackLikesService.swift
│   └── LocationService.swift (if exists)
│
├── ViewModels/
│   ├── TrackLikesDetailViewModel.swift
│   └── (other ViewModels)
│
├── Views/
│   ├── TrackLikes/
│   │   ├── TrackLikesDetailView.swift
│   │   └── (related views)
│   └── (other view folders)
│
├── Utilities/
│   └── (helper classes, extensions)
│
└── Resources/
    └── (assets, config files)
```

---

## 🎯 Phase-by-Phase Restructuring Instructions

### **PHASE 1: Create Folder Groups** 📂

1. **In Xcode Project Navigator (left sidebar):**
   - Right-click on your project's main folder (where all your Swift files are)
   - Select **"New Group"**
   - Name it: `Models`

2. **Repeat to create these groups:**
   - `Services`
   - `ViewModels`
   - `Views`
   - `Views/TrackLikes` (create `Views` first, then right-click it to add `TrackLikes` subfolder)
   - `Utilities` (optional)
   - `Resources` (optional)

---

### **PHASE 2: Move Core Models** 🎯

**Order matters!** Move these files into the `Models` group:

1. **LocationPoint.swift**
   - Drag and drop into `Models` folder
   - ✅ Build project (Cmd+B) - should succeed

2. **AppUser.swift**
   - Drag into `Models` folder
   - ✅ Build project - should succeed

3. **Track.swift**
   - Drag into `Models` folder
   - ✅ Build project - should succeed

4. **TrackLike.swift**
   - Drag into `Models` folder
   - ✅ Build project - should succeed

5. **TrackLikesCluster.swift**
   - Drag into `Models` folder
   - ✅ Build project - should succeed

**⚠️ After each file move, build the project to catch any issues early!**

---

### **PHASE 3: Move Services** 🔧

Move these files into the `Services` group:

1. **CurrentUserStore.swift**
   - Drag into `Services` folder
   - ✅ Build project

2. **TrackLikesService.swift**
   - Drag into `Services` folder
   - ✅ Build project

3. **LocationService.swift** (if you have it)
   - Drag into `Services` folder
   - ✅ Build project

---

### **PHASE 4: Move ViewModels** 🧠

Move these files into the `ViewModels` group:

1. **TrackLikesDetailViewModel.swift**
   - Drag into `ViewModels` folder
   - ✅ Build project

2. **Any other ViewModel files**
   - Drag each into `ViewModels` folder
   - ✅ Build after each move

---

### **PHASE 5: Move Views** 🎨

Move these files into the `Views` structure:

1. **TrackLikesDetailView.swift**
   - Drag into `Views/TrackLikes` folder
   - ✅ Build project

2. **Other TrackLikes-related views**
   - Drag into `Views/TrackLikes` folder
   - ✅ Build after each

3. **Other views**
   - Create subfolders as needed (e.g., `Views/Profile`, `Views/Map`)
   - Move related views together
   - ✅ Build after each group

---

### **PHASE 6: Move Utilities & Resources** 🛠️

1. **Extensions, Helpers, Utilities**
   - Move into `Utilities` folder
   - ✅ Build project

2. **Asset catalogs, config files, plists**
   - Move into `Resources` folder (if they're not already in a good spot)
   - ✅ Build project

---

## ✅ Post-Restructure Checklist

After moving everything:

- [ ] **Build succeeds** (Cmd+B)
- [ ] **Run the app** - verify it launches
- [ ] **Test key features** - make sure nothing broke
- [ ] **Check target membership** - if files aren't found:
  - Select file in Project Navigator
  - Open File Inspector (right sidebar)
  - Verify your app target is checked under "Target Membership"
- [ ] **Check Git status** - Xcode should have preserved file history
- [ ] **Commit changes** - `git add .` and `git commit -m "Restructure project folders"`

---

## 🆘 Troubleshooting

### **Problem: "Cannot find 'TypeName' in scope"**

**Solution:**
1. Select the file in Project Navigator
2. Open File Inspector (Cmd+Option+1)
3. Under "Target Membership", ensure your app target is checked
4. Clean build folder (Cmd+Shift+K)
5. Rebuild (Cmd+B)

### **Problem: Files won't drag into groups**

**Solution:**
- Make sure you're dragging in Xcode's Project Navigator (not Finder)
- If stuck, right-click the file → Show in Finder
- Then drag from Project Navigator to the group

### **Problem: Circular dependencies**

**Solution:**
- This means you moved files out of order
- Check the dependency chain:
  - Models depend on: nothing
  - Services depend on: Models
  - ViewModels depend on: Models + Services
  - Views depend on: Models + Services + ViewModels

### **Problem: Group doesn't match file system**

**Solution:**
- Xcode groups don't have to match folders on disk
- If you want them to match:
  - Select group → File Inspector → check path
  - Can create actual folders in Finder and re-add files

---

## 📝 Best Practices Going Forward

1. **New files always go in the right group**
   - Model? → `Models/`
   - Service? → `Services/`
   - And so on...

2. **One file per type**
   - Don't mix multiple models in one file
   - Keep related extensions in separate files

3. **Naming conventions**
   - Models: `ThingName.swift` (e.g., `AppUser.swift`)
   - Services: `ThingNameService.swift` (e.g., `TrackLikesService.swift`)
   - ViewModels: `ViewNameViewModel.swift` (e.g., `TrackLikesDetailViewModel.swift`)
   - Views: `ThingNameView.swift` (e.g., `TrackLikesDetailView.swift`)

4. **Keep dependencies clean**
   - Views should NOT import/use other Views' ViewModels directly
   - Services should NOT import SwiftUI
   - Models should be pure data (no business logic)

---

## 🎉 Benefits of This Structure

✅ **Easier to find files** - know exactly where to look  
✅ **Clearer dependencies** - understand what depends on what  
✅ **Better collaboration** - team members know where to put new code  
✅ **Simpler testing** - can test layers independently  
✅ **Easier refactoring** - contained changes  
✅ **Scalable** - works for small and large projects  

---

## 📞 Need Help?

If you run into issues:
1. Note which phase you're on
2. Note which file you're trying to move
3. Copy any error messages
4. Ask for help!

---

**Good luck with the restructure! Take it one phase at a time and build frequently! 🚀**
