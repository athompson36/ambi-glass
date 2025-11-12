# Watch Remote Addon - Xcode Setup Quick Reference

**Date:** December 2024

---

## Quick Checklist

### Files to Add

**SharedRemote** (ALL targets: iPhone, iPad, Mac, watchOS):
- ✅ `RemoteProtocol.swift`
- ✅ `LANListener.swift`

**iOS-Relay** (iPhone ONLY):
- ✅ `PhoneRelay.swift`

**watchOS-App** (watchOS ONLY):
- ✅ `WatchRemote.swift`
- ✅ `WatchTransportView.swift`
- ✅ `AmbiGlassWatchApp.swift`

---

## Target Membership Summary

| File | iPhone | iPad | Mac | watchOS |
|------|--------|------|-----|---------|
| `SharedRemote/RemoteProtocol.swift` | ✅ | ✅ | ✅ | ✅ |
| `SharedRemote/LANListener.swift` | ✅ | ✅ | ✅ | ✅ |
| `iOS-Relay/PhoneRelay.swift` | ✅ | ❌ | ❌ | ❌ |
| `watchOS-App/WatchRemote.swift` | ❌ | ❌ | ❌ | ✅ |
| `watchOS-App/WatchTransportView.swift` | ❌ | ❌ | ❌ | ✅ |
| `watchOS-App/AmbiGlassWatchApp.swift` | ❌ | ❌ | ❌ | ✅ |

---

## Required Frameworks

### iPhone Target (AmbiStudio)
- `WatchConnectivity.framework`
- `Network.framework`

### watchOS Target (AmbiGlassWatch)
- `WatchConnectivity.framework`

---

## Info.plist Entry

**iPhone Target Only:**
- Key: `Privacy - Local Network Usage Description`
- Value: `AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac.`

---

## Quick Steps

1. **Open Xcode**: `ios/AmbiStudio/AmbiStudio.xcodeproj`
2. **Create Groups**: SharedRemote, iOS-Relay, watchOS-App
3. **Add Files**: Drag files into groups, check target memberships
4. **Add Frameworks**: Add WatchConnectivity and Network to targets
5. **Info.plist**: Add network usage description
6. **Build**: Verify no errors

---

## Verification

After setup, verify:
- [ ] All files compile without errors
- [ ] Target memberships are correct
- [ ] Frameworks are linked
- [ ] Info.plist entry added
- [ ] watchOS target exists (create if needed)

---

## Run Helper Script

```bash
./Scripts/add_watch_remote_to_xcode.sh
```

This script verifies files exist and provides detailed instructions.

---

**For detailed instructions, see the output of the helper script or `IMPLEMENTATION_GUIDE.md`**

