import AppKit
import SwiftUI
import Combine

/// Main application delegate — bootstraps the menu bar agent app.
/// Since LSUIElement = YES, the app has no Dock icon and lives entirely in the menu bar.
///
/// ## Privacy Hardening Design
/// - **Zero Accessibility Privilege Required**: Uses system Carbon `RegisterEventHotKey`
///   so macOS dispatches only the exact ⌘⇧B key combination to Hairpin. Zero keystroke
///   interception, zero keylogging risk, zero Accessibility permissions prompt.
/// - **On-Demand Mouse Tracking**: Mouse tracking is deactivated whenever not required.
/// - **Zero Network Activity**: No analytics, telemetry, crash reporters, or outbound requests.
/// - **Isolated Preferences**: Prefixed UserDefaults without any sensitive or activity data.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Core Components

    private var menuBarManager: MenuBarManager!
    private var notchDetector: NotchDetector!
    private var settingsWindowController: NSWindowController?
    private var floatingPanelController: FloatingPanelController?
    private var mouseTracker: MouseTracker?
    private var hotKeyManager: HotKeyManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize notch detection
        notchDetector = NotchDetector()

        // Initialize the core menu bar folding engine
        menuBarManager = MenuBarManager(notchDetector: notchDetector)
        menuBarManager.delegate = self

        // Initialize floating panel for notch overflow
        floatingPanelController = FloatingPanelController(
            notchDetector: notchDetector,
            menuBarManager: menuBarManager
        )

        // Initialize mouse tracking for auto-collapse
        mouseTracker = MouseTracker(
            menuBarManager: menuBarManager,
            floatingPanelController: floatingPanelController,
            notchDetector: notchDetector
        )

        // Initialize hotkey manager using privacy-preserving Carbon API
        setupGlobalHotKey()

        // Observe settings changes
        observeSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()
        mouseTracker?.stopTracking()
    }

    // MARK: - Settings Observation

    private func observeSettings() {
        UserDefaults.standard.publisher(for: \.hairpinAutoCollapseDelay)
            .sink { [weak self] delay in
                self?.mouseTracker?.updateAutoCollapseDelay(delay)
            }
            .store(in: &cancellables)

        UserDefaults.standard.publisher(for: \.hairpinTriggerMode)
            .sink { [weak self] mode in
                self?.mouseTracker?.updateTriggerMode(TriggerMode(rawValue: mode) ?? .clickOnly)
            }
            .store(in: &cancellables)
    }

    // MARK: - Privacy-Preserving Global HotKey

    private func setupGlobalHotKey() {
        let manager = HotKeyManager()
        // Register Cmd + Shift + B (Carbon keyCode 11 for 'b')
        manager.register { [weak self] in
            Task { @MainActor in
                self?.menuBarManager.toggle()
            }
        }
        self.hotKeyManager = manager
    }

    // MARK: - Settings Window

    func showSettingsWindow() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Hairpin Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        let controller = NSWindowController(window: window)
        self.settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - MenuBarManagerDelegate

extension AppDelegate: MenuBarManagerDelegate {
    func menuBarManagerDidRequestSettings() {
        showSettingsWindow()
    }

    func menuBarManagerDidToggle(isCollapsed: Bool) {
        if isCollapsed {
            floatingPanelController?.hidePanel()
        }
        mouseTracker?.handleToggle(isCollapsed: isCollapsed)
    }

    func menuBarManagerDidRequestFloatingPanel() {
        floatingPanelController?.togglePanel()
    }
}
