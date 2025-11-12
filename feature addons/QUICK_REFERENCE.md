# Feature Addons Quick Reference

**Last Updated:** December 2024

---

## Integration Order

1. **Watch Remote Addon FIRST** (required for Host Controls)
2. **Host Controls Addon SECOND** (depends on PhoneRelay)

---

## Files to Add by Target

### All Targets (iPhone, iPad, Mac, watchOS)
```
SharedHost/
├── TransportController.swift
└── RemoteMessageObserver.swift

SharedRemote/
├── RemoteProtocol.swift
└── LANListener.swift
```

### iPhone Only
```
iOS-HostUI/
└── HostControlsView.swift

iOS-Relay/
└── PhoneRelay.swift
```

### watchOS Only
```
watchOS-App/
├── WatchRemote.swift
└── WatchTransportView.swift
```

---

## Key Integration Points

### 1. Wire TransportController
**File:** `SharedHost/TransportController.swift`

```swift
public func configure(recorder: RecorderEngine, irkit: IRKit) {
    self.recorder = recorder
    self.irkit = irkit
}
```

### 2. Initialize in App
**File:** `App/AmbiGlassApp.swift`

```swift
.onAppear {
    TransportController.shared.configure(recorder: recorder, irkit: irkit)
    #if os(iOS)
    let _ = PhoneRelay.shared  // Initialize relay
    #endif
}
```

### 3. Add HostControlsView (iPhone)
**File:** `App/ContentView.swift` or `UI/SettingsView.swift`

```swift
#if os(iOS)
HostControlsView()
#endif
```

### 4. Set Up LAN Listener (iPad/Mac)
**File:** `App/AmbiGlassApp.swift`

```swift
#if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
lanListener = try LANListener(port: 47655) { message in
    // Handle commands
}
#endif
```

---

## Info.plist Requirement

**iOS Target:**
- Key: `NSLocalNetworkUsageDescription`
- Value: `AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac.`

---

## Testing Quick Checklist

- [ ] Watch app builds and runs
- [ ] Commands from watch reach iPhone
- [ ] Status updates on watch (< 1s)
- [ ] HostControlsView displays (iPhone)
- [ ] Local buttons work (iPhone)
- [ ] LAN relay connects (iPhone → iPad/Mac)
- [ ] Commands forwarded over LAN
- [ ] TransportController controls RecorderEngine
- [ ] TransportController controls IRKit

---

## Common Issues

### HostControlsView won't compile
- **Fix:** Integrate Watch Remote Addon first (PhoneRelay dependency)

### Watch not receiving commands
- **Fix:** Check WCSession.isReachable, ensure watch app is running

### LAN relay not working
- **Fix:** Check network connectivity, firewall (UDP 47655), use IP instead of hostname

### Status not updating
- **Fix:** Ensure `PhoneRelay.shared.pushStatus()` is called on state changes

---

## Documentation

- **Full Guide:** [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)
- **Summary:** [INTEGRATION_SUMMARY.md](./INTEGRATION_SUMMARY.md)
- **Original Patches:** See `DOCS/PATCHES/` in each addon folder

---

**Estimated Integration Time:** 4-8 hours  
**Complexity:** Medium  
**Dependencies:** WatchConnectivity, Network frameworks

