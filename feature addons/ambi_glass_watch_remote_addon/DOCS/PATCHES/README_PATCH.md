# Watch Remote Feature (Drop-in) — 2025-11-11

This zip adds a watchOS remote transport for Ambi-A IR / AmbiGlass.

## Files (relative to repo root)
- SharedRemote/RemoteProtocol.swift
- SharedRemote/LANListener.swift
- iOS-Relay/PhoneRelay.swift
- watchOS-App/WatchRemote.swift
- watchOS-App/WatchTransportView.swift

## Integrate
1. Drag folders into Xcode; add to targets:
   - iPhone: iOS-Relay, SharedRemote
   - iPad/Mac (host): SharedRemote (use LANListener)
   - watchOS: watchOS-App, SharedRemote
2. Info.plist:
   - iOS: NSLocalNetworkUsageDescription
3. Host wiring:
   - Observe `Notification.Name("RemoteMessage")` (on iPhone), or use `LANListener` (iPad/Mac) to trigger your TransportController.
4. Status:
   - Call `PhoneRelay.shared.pushStatus(RemoteStatus(...))` when the host changes state.
