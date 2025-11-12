# Feature Addons Implementation Guide

**Last Updated:** December 2024  
**Status:** Integration Guide

---

## Overview

This guide provides step-by-step instructions for integrating two feature addons into the AmbiGlass application:

1. **Host Controls Addon** - iPhone control panel and transport controller for remote control
2. **Watch Remote Addon** - Apple Watch remote control via WatchConnectivity and LAN relay

---

## Feature Addon 1: Host Controls Addon

### Purpose
Adds a transport controller shim and iPhone control panel that allows:
- Local iPhone host control (start/stop recording, IR measurement)
- Remote control integration (receives commands from Watch)
- LAN relay capability (forwards commands to iPad/Mac hosts)

### ⚠️ Dependency Note
**Host Controls Addon depends on Watch Remote Addon** - `HostControlsView` references `PhoneRelay.shared` which is part of the Watch Remote Addon. You should integrate the Watch Remote Addon first, or integrate both addons together.

### Files Structure
```
ambi_glass_host_controls_addon/
├── SharedHost/
│   ├── TransportController.swift          # Transport shim (needs wiring to RecorderEngine/IRKit)
│   └── RemoteMessageObserver.swift        # Observes watch commands, controls TransportController
└── iOS-HostUI/
    └── HostControlsView.swift             # iPhone SwiftUI control panel
```

### Integration Steps

#### Step 1: Add Files to Xcode Project

1. **Add SharedHost folder to all targets:**
   - Drag `SharedHost/` folder into Xcode
   - Add to targets: **iPhone**, **iPad**, **Mac**
   - Ensure both files are included:
     - `TransportController.swift`
     - `RemoteMessageObserver.swift`

2. **Add iOS-HostUI folder to iPhone target only:**
   - Drag `iOS-HostUI/` folder into Xcode
   - Add to target: **iPhone only**
   - Include file:
     - `HostControlsView.swift`

#### Step 2: Wire TransportController to Existing Engines

**File:** `SharedHost/TransportController.swift`

Replace the TODO comments with actual calls to `RecorderEngine` and `IRKit`:

```swift
import Foundation
import Combine

public final class TransportController: ObservableObject {
    public static let shared = TransportController()
    @Published public var status = RemoteStatus(.idle, "")
    
    // Add references to your engines
    private weak var recorder: RecorderEngine?
    private weak var irkit: IRKit?
    
    private init() {}
    
    // Inject engines (call this from your app setup)
    public func configure(recorder: RecorderEngine, irkit: IRKit) {
        self.recorder = recorder
        self.irkit = irkit
    }
    
    public func startRecording() {
        do {
            try recorder?.start()
            status = .init(.recording, "Recording…")
        } catch {
            status = .init(.error, "Record error: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
    
    public func stopRecording() {
        recorder?.stop()
        status = .init(.idle, "Stopped")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
    
    public func startIR() {
        // Note: This needs to trigger IR measurement
        // You may need to adapt based on your IRKit interface
        // For now, this is a placeholder that needs your IR measurement trigger
        status = .init(.irMeasuring, "Sweep running…")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
        
        // TODO: Call your IR measurement start method
        // Example: irkit?.startMeasurement(...)
    }
    
    public func stopIR() {
        // TODO: Stop IR capture/processing as needed
        status = .init(.idle, "IR stopped")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
}
```

#### Step 3: Initialize RemoteMessageObserver on iPhone

**File:** `App/AmbiGlassApp.swift` (iPhone target)

Add initialization to observe watch commands:

```swift
@main
struct AmbiGlassApp: App {
    @StateObject private var devices = AudioDeviceManager()
    @StateObject private var recorder = RecorderEngine()
    @StateObject private var transcoder = Transcoder()
    @StateObject private var irkit = IRKit()
    @StateObject private var calibrator = CalibrationKit()
    @StateObject private var micCal = MicCalLoader()
    @StateObject private var theme = ThemeManager.shared
    
    // Add observer for watch commands
    private let remoteObserver = RemoteMessageObserver()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(devices)
                .environmentObject(recorder)
                .environmentObject(transcoder)
                .environmentObject(irkit)
                .environmentObject(calibrator)
                .environmentObject(micCal)
                .environmentObject(theme)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Configure transport controller with engines
                    TransportController.shared.configure(recorder: recorder, irkit: irkit)
                }
        }
    }
}
```

#### Step 4: Add HostControlsView to iPhone UI

**Option A: Add as a new tab in ContentView**

**File:** `App/ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("Record", systemImage: "dot.radiowaves.left.and.right") }
            MeasureIRView()
                .tabItem { Label("Measure IR", systemImage: "waveform") }
            BatchTranscodeView()
                .tabItem { Label("Transcode", systemImage: "arrow.2.squarepath") }
            CalibrationView()
                .tabItem { Label("Calibrate", systemImage: "gauge") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
            
            // Add Host Controls tab (iPhone only)
            #if os(iOS)
            HostControlsView()
                .tabItem { Label("Remote", systemImage: "applewatch") }
            #endif
        }
        .background(GlassBackground())
    }
}
```

**Option B: Add to Settings view (recommended for production)**

**File:** `UI/SettingsView.swift`

Add a section for remote controls:

```swift
// In SettingsView body, add:
#if os(iOS)
Divider().opacity(0.4)
Text("Remote Control").font(.headline)
HostControlsView()
#endif
```

#### Step 5: Update HostControlsView to Use PhoneRelay

**File:** `iOS-HostUI/HostControlsView.swift`

⚠️ **Important:** This view references `PhoneRelay.shared` which is part of the **Watch Remote Addon**. You must integrate the Watch Remote Addon first (see Feature Addon 2 below) before `HostControlsView` will compile and work correctly.

The view already references `PhoneRelay.shared`, so once you've integrated the Watch Remote Addon, this view will work automatically.

---

## Feature Addon 2: Watch Remote Addon

### ⚠️ Integration Order
**Integrate this addon FIRST** or together with Host Controls Addon, as `HostControlsView` depends on `PhoneRelay` from this addon.

### Purpose
Enables Apple Watch remote control of AmbiGlass via:
- WatchConnectivity for iPhone-to-Watch communication
- LAN relay for iPad/Mac host control
- Real-time status updates from host to watch

### Files Structure
```
ambi_glass_watch_remote_addon/
├── SharedRemote/
│   ├── RemoteProtocol.swift              # Command/status message definitions
│   └── LANListener.swift                 # UDP listener for iPad/Mac hosts
├── iOS-Relay/
│   └── PhoneRelay.swift                  # WatchConnectivity + LAN forwarding
└── watchOS-App/
    ├── WatchRemote.swift                 # Watch-side connectivity
    └── WatchTransportView.swift          # Watch UI
```

### Integration Steps

#### Step 1: Add Files to Xcode Project

1. **Add SharedRemote folder to all targets:**
   - Drag `SharedRemote/` folder into Xcode
   - Add to targets: **iPhone**, **iPad**, **Mac**, **watchOS**
   - Ensure both files are included:
     - `RemoteProtocol.swift`
     - `LANListener.swift`

2. **Add iOS-Relay folder to iPhone target only:**
   - Drag `iOS-Relay/` folder into Xcode
   - Add to target: **iPhone only**
   - Include file:
     - `PhoneRelay.swift`

3. **Add watchOS-App folder to watchOS target:**
   - Drag `watchOS-App/` folder into Xcode
   - Add to target: **watchOS only**
   - Include files:
     - `WatchRemote.swift`
     - `WatchTransportView.swift`

#### Step 2: Add Info.plist Entry for iOS

**File:** `Info.plist` (or in Xcode project settings)

Add network usage description:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac.</string>
```

Or in Xcode:
1. Select project → Target (iPhone) → Info tab
2. Add key: `Privacy - Local Network Usage Description`
3. Value: `AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac.`

#### Step 3: Initialize PhoneRelay on iPhone

**File:** `App/AmbiGlassApp.swift` (iPhone target)

Ensure `PhoneRelay.shared` is initialized (it's a singleton, so just accessing it initializes it):

```swift
@main
struct AmbiGlassApp: App {
    // ... existing code ...
    
    // PhoneRelay initializes itself as singleton
    // Just ensure it's accessed early
    private let _ = PhoneRelay.shared
    
    var body: some Scene {
        // ... existing code ...
    }
}
```

#### Step 4: Update TransportController to Push Status

**File:** `SharedHost/TransportController.swift`

Update status changes to push to watch via PhoneRelay:

```swift
import Foundation
import Combine

public final class TransportController: ObservableObject {
    public static let shared = TransportController()
    @Published public var status = RemoteStatus(.idle, "")
    
    private weak var recorder: RecorderEngine?
    private weak var irkit: IRKit?
    
    private init() {}
    
    public func configure(recorder: RecorderEngine, irkit: IRKit) {
        self.recorder = recorder
        self.irkit = irkit
    }
    
    private func updateStatus(_ newStatus: RemoteStatus) {
        status = newStatus
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
        
        // Push status to watch (iPhone only)
        #if os(iOS)
        PhoneRelay.shared.pushStatus(newStatus)
        #endif
    }
    
    public func startRecording() {
        do {
            try recorder?.start()
            updateStatus(.init(.recording, "Recording…"))
        } catch {
            updateStatus(.init(.error, "Record error: \(error.localizedDescription)"))
        }
    }
    
    public func stopRecording() {
        recorder?.stop()
        updateStatus(.init(.idle, "Stopped"))
    }
    
    public func startIR() {
        // TODO: Trigger IR measurement
        updateStatus(.init(.irMeasuring, "Sweep running…"))
    }
    
    public func stopIR() {
        // TODO: Stop IR measurement
        updateStatus(.init(.idle, "IR stopped"))
    }
}
```

#### Step 5: Set Up LAN Listener for iPad/Mac Hosts

**File:** `App/AmbiGlassApp.swift` (iPad/Mac targets)

Add LAN listener to receive commands from iPhone relay:

```swift
@main
struct AmbiGlassApp: App {
    // ... existing code ...
    
    #if os(macOS) || os(iOS) && !targetEnvironment(macCatalyst)
    // For iPad/Mac: Set up LAN listener
    private var lanListener: LANListener?
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // ... existing environment objects ...
                .onAppear {
                    TransportController.shared.configure(recorder: recorder, irkit: irkit)
                    
                    // Set up LAN listener for iPad/Mac
                    #if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
                    do {
                        lanListener = try LANListener(port: 47655) { [weak self] message in
                            // Handle incoming remote command
                            DispatchQueue.main.async {
                                let transport = TransportController.shared
                                switch message.cmd {
                                case .startRecording:
                                    transport.startRecording()
                                case .stopRecording:
                                    transport.stopRecording()
                                case .startIR:
                                    transport.startIR()
                                case .stopIR:
                                    transport.stopIR()
                                case .ping:
                                    break
                                }
                            }
                        }
                    } catch {
                        print("Failed to start LAN listener: \(error)")
                    }
                    #endif
                }
        }
    }
}
```

#### Step 6: Create Watch App Target (if not exists)

If you don't have a watchOS target:

1. **File → New → Target**
2. Select **watchOS → App**
3. Name: `AmbiGlassWatch`
4. Language: Swift
5. Interface: SwiftUI

#### Step 7: Set Up Watch App

**File:** `watchOS-App/AmbiGlassWatchApp.swift` (create if needed)

```swift
import SwiftUI

@main
struct AmbiGlassWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchTransportView()
        }
    }
}
```

**File:** `watchOS-App/WatchTransportView.swift`

The view is already provided in the addon. Ensure it's added to your watchOS target.

#### Step 8: Wire IR Measurement Start/Stop

**File:** `SharedHost/TransportController.swift`

You need to properly wire IR measurement. Based on your `IRKit` interface, you may need to:

1. **Store IR measurement state:**
```swift
private var isIRMeasuring = false
private var irMeasurementTask: Task<Void, Never>?
```

2. **Implement startIR properly:**
```swift
public func startIR() {
    guard !isIRMeasuring else { return }
    isIRMeasuring = true
    
    updateStatus(.init(.irMeasuring, "Sweep running…"))
    
    // Trigger IR measurement
    // This depends on your IRKit interface
    // You may need to post a notification that MeasureIRView observes
    NotificationCenter.default.post(
        name: NSNotification.Name("StartIRMeasurement"),
        object: nil
    )
}
```

3. **Update MeasureIRView to respond to remote commands:**

**File:** `UI/MeasureIRView.swift`

Add observer for remote IR start command:

```swift
struct MeasureIRView: View {
    // ... existing code ...
    
    var body: some View {
        // ... existing UI ...
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartIRMeasurement"))) { _ in
        // Trigger IR measurement when remote command received
        if !isMeasuring {
            isMeasuring = true
            exportStatus = "Measuring..."
            DispatchQueue.global(qos: .userInitiated).async {
                let irs = irkit.runSweep(seconds: sweepSeconds, f0: f0, f1: f1)
                DispatchQueue.main.async {
                    measuredIRs = irs
                    isMeasuring = false
                    exportStatus = "IR measured: \(irs.first?.count ?? 0) samples"
                    // Update transport status
                    TransportController.shared.updateStatus(.init(.idle, "IR measurement complete"))
                }
            }
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StopIRMeasurement"))) { _ in
        // Stop IR measurement if in progress
        if isMeasuring {
            // Cancel measurement if possible
            isMeasuring = false
            exportStatus = "IR measurement aborted"
            TransportController.shared.updateStatus(.init(.idle, "IR measurement aborted"))
        }
    }
}
```

---

## Testing the Integration

### Test Watch Remote Control

1. **Build and run on iPhone**
2. **Build and run watch app on paired Apple Watch**
3. **Test commands:**
   - Tap "Rec" on watch → Should start recording on iPhone
   - Tap "Stop" on watch → Should stop recording
   - Tap "IR" on watch → Should start IR measurement
   - Tap "Abort" on watch → Should stop IR measurement
4. **Verify status updates:**
   - Watch should show status text updates within 1 second
   - Status should reflect current operation (Recording, IR Measuring, etc.)

### Test LAN Relay (iPad/Mac Host)

1. **Build and run on iPad or Mac** (host)
2. **Build and run on iPhone** (relay)
3. **On iPhone HostControlsView:**
   - Enable "Relay commands to LAN host"
   - Enter iPad/Mac hostname or IP (e.g., "ipad.local" or "192.168.1.100")
   - Tap "Connect"
4. **On watch:**
   - Send commands (Rec, Stop, IR, Abort)
   - Commands should reach iPad/Mac host
   - Host should respond to commands

### Test iPhone Host Control

1. **Build and run on iPhone**
2. **Open Host Controls tab/view**
3. **Test buttons:**
   - "Start Rec" → Should start recording
   - "Stop" → Should stop recording
   - "Start IR" → Should start IR measurement
   - "Abort IR" → Should stop IR measurement
4. **Verify status updates flow to watch**

---

## Known Issues & Limitations

### Current Limitations

1. **IR Measurement Integration:**
   - `TransportController.startIR()` needs proper wiring to your IR measurement system
   - May need to adapt based on whether you use `IRKit.runSweep()` or a different interface
   - Consider adding a notification-based system for remote IR triggers

2. **Status Updates:**
   - Status updates depend on `PhoneRelay.shared.pushStatus()` being called
   - Ensure all state changes in `RecorderEngine` and `IRKit` update `TransportController.status`

3. **LAN Relay:**
   - Requires network connectivity between iPhone and iPad/Mac
   - Firewall may block UDP port 47655
   - Hostname resolution may fail (use IP address as fallback)

### Future Enhancements

1. **Better IR Integration:**
   - Add proper IR measurement state management
   - Support for IR measurement progress updates
   - IR measurement cancellation

2. **Enhanced Status:**
   - More detailed status information
   - Progress indicators for long operations
   - Error reporting to watch

3. **Security:**
   - Add authentication for LAN relay
   - Encrypt LAN communication
   - Rate limiting for commands

---

## File Organization After Integration

After integration, your project structure should include:

```
AmbiGlass/
├── App/
│   ├── AmbiGlassApp.swift          # Updated with TransportController setup
│   └── ContentView.swift            # Updated with HostControlsView tab (iPhone)
├── Audio/
│   └── RecorderEngine.swift         # Existing (no changes needed)
├── DSP/
│   └── IRKit.swift                  # Existing (may need notification support)
├── UI/
│   ├── RecordView.swift             # Existing (no changes needed)
│   ├── MeasureIRView.swift          # Updated with remote command observers
│   └── SettingsView.swift           # Optionally add HostControlsView here
├── SharedHost/                      # NEW - From addon
│   ├── TransportController.swift    # Updated with engine wiring
│   └── RemoteMessageObserver.swift  # From addon
├── iOS-HostUI/                      # NEW - From addon (iPhone only)
│   └── HostControlsView.swift       # From addon
├── SharedRemote/                    # NEW - From addon
│   ├── RemoteProtocol.swift         # From addon
│   └── LANListener.swift            # From addon
├── iOS-Relay/                       # NEW - From addon (iPhone only)
│   └── PhoneRelay.swift             # From addon
└── watchOS-App/                     # NEW - From addon (watchOS only)
    ├── WatchRemote.swift             # From addon
    └── WatchTransportView.swift      # From addon
```

---

## Acceptance Criteria

### Watch Remote Control
- ✅ Rec/Stop and IR/Abort commands reach host
- ✅ Status text updates on watch within 1 second
- ✅ Watch UI is responsive and clear

### LAN Relay
- ✅ iPhone forwards commands to iPad/Mac over LAN
- ✅ Host triggers start/stop without UI focus
- ✅ Status flows back through relay to watch

### iPhone Host Control
- ✅ HostControlsView displays and functions correctly
- ✅ Local control works (buttons trigger actions)
- ✅ Status updates display correctly
- ✅ LAN relay toggle works

---

## Troubleshooting

### Watch Not Receiving Commands

1. **Check WatchConnectivity:**
   - Ensure watch app is running
   - Verify `WCSession.isReachable` is true
   - Check that `PhoneRelay.shared` is initialized

2. **Check Notification Center:**
   - Verify `RemoteMessageObserver` is initialized
   - Check that notifications are being posted

### LAN Relay Not Working

1. **Network Issues:**
   - Verify iPhone and iPad/Mac are on same network
   - Check firewall settings (UDP port 47655)
   - Try using IP address instead of hostname

2. **Host Not Receiving:**
   - Verify `LANListener` is initialized on host
   - Check that port 47655 is not blocked
   - Verify host app is running

### Status Not Updating

1. **Check Status Push:**
   - Verify `PhoneRelay.shared.pushStatus()` is being called
   - Check that status changes trigger updates
   - Verify watch app is receiving status messages

2. **Check TransportController:**
   - Ensure `updateStatus()` is called on all state changes
   - Verify status is being published correctly

---

## Next Steps

After integration:

1. **Test thoroughly** on all platforms (iPhone, iPad, Mac, Watch)
2. **Update documentation** to include remote control features
3. **Add to production roadmap** as completed feature
4. **Consider enhancements** based on user feedback

---

**Document Maintained By:** Development Team  
**Last Updated:** December 2024

