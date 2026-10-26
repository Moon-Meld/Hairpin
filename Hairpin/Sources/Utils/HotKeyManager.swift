import Carbon
import AppKit

/// Manages global hotkeys using the Carbon `RegisterEventHotKey` API.
///
/// ## Privacy & Security Advantages over `NSEvent.addGlobalMonitorForEvents`:
/// 1. **Zero Keystroke Snooping**: The Carbon HotKey API registers a specific key combination
///    with the Window Server. The OS only notifies our process when the exact combo is pressed.
///    Our application has literally no code execution or visibility into any other keystrokes.
/// 2. **No Accessibility Permissions Required**: Unlike global `NSEvent` key monitoring which
///    requires `kTCCServiceAccessibility` (often flagging security scanners as keylogger-like behavior),
///    `RegisterEventHotKey` requires zero elevated privileges.
/// 3. **Process Isolation**: The callback contains zero text or context from other running applications.
final class HotKeyManager: @unchecked Sendable {

    // MARK: - Private State

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onHotKeyDown: (@MainActor () -> Void)?

    // MARK: - Init / Deinit

    init() {
        installCarbonEventHandler()
    }

    deinit {
        unregister()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    // MARK: - Public API

    /// Registers the global shortcut (Default: ⌘⇧B).
    /// - Parameters:
    ///   - keyCode: Carbon virtual key code (e.g. `kVK_ANSI_B` = 11).
    ///   - modifiers: Carbon modifier mask (e.g. `cmdKey | shiftKey`).
    ///   - action: Closure executed on MainActor when the hotkey is triggered.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_B),
                  modifiers: UInt32 = UInt32(cmdKey | shiftKey),
                  action: @escaping @MainActor () -> Void) {
        unregister() // Clear any existing registration
        self.onHotKeyDown = action

        let hotKeyID = EventHotKeyID(signature: OSType(0x4850494E), id: 1) // "HPIN" signature
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            NSLog("[Hairpin] Warning: RegisterEventHotKey returned status code %d", status)
        }
    }

    /// Unregisters the current hotkey from the window server.
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        self.onHotKeyDown = nil
    }

    // MARK: - Carbon Event Handler

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.onHotKeyDown?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
