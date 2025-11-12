# Host Controls + Transport Shim (Drop-in) — 2025-11-11

Adds a tiny iPhone control panel and a shared TransportController you can call from any platform target.

## Files (relative to repo root)
- `SharedHost/TransportController.swift` — status publisher + start/stop methods
- `SharedHost/RemoteMessageObserver.swift` — binds incoming watch commands to TransportController
- `iOS-HostUI/HostControlsView.swift` — iPhone SwiftUI panel for local host control + optional LAN relay

## Integration
1. Drag **SharedHost** into all app targets (iPhone, iPad, Mac).
2. Drag **iOS-HostUI** into the iPhone app target.
3. In your iPhone app, present `HostControlsView()` somewhere (e.g., a Debug tab or Settings).
4. In your actual engines, replace the TODOs in `TransportController` with calls to `RecorderEngine` and `IRKit`.
5. Status propagation:
   - `TransportController` publishes changes and pushes status to the Watch via `PhoneRelay.shared.pushStatus(...)` (already wired in the view).
6. If your host is on **iPad/Mac**, enable "Relay commands to LAN host" and set the host address. Ensure the host app is running a `LANListener`.

Done. Your watch can now control sessions; your iPhone can host or relay; status flows back to the watch.
