import AppKit
import Combine

/// Tracks global mouse movement to support:
/// 1. Auto-collapse after the cursor leaves the menu bar area.
/// 2. Hover-to-expand when mouse lingers near the notch / menu bar.
///
/// ## Privacy & Security Architecture
/// - **On-Demand Tracking (按需追踪)**: The global monitor is ONLY registered when actively needed.
///   When the bar is collapsed and `triggerMode == .clickOnly`, or when both auto-collapse is "Never"
///   and hover is disabled, tracking is completely dormant and ZERO events are received.
/// - **No Click Events**: Only `.mouseMoved` is listened to — zero clicks, keystrokes, or window focus
///   events are observed.
/// - **Zero Data Persistence**: Mouse coordinates from `NSEvent.mouseLocation` are evaluated
///   ephemerally for a boolean geometric hit-test against the menu bar bounds and discarded immediately.
/// - **Deterministic Teardown**: Monitor is cleanly uninstalled on termination or settings updates.
@MainActor
final class MouseTracker {

    // MARK: - Dependencies

    private let menuBarManager: MenuBarManager
    private weak var floatingPanelController: FloatingPanelController?
    private let notchDetector: NotchDetector

    // MARK: - Configuration

    private var autoCollapseDelay: Double
    private var triggerMode: TriggerMode

    // MARK: - Monitors & Timers

    private var globalMonitor: Any?
    private var autoCollapseTimer: Timer?
    private var hoverExpandTimer: Timer?

    /// Whether the global monitor is currently active in the OS.
    private var isTracking = false

    // MARK: - Init

    init(menuBarManager: MenuBarManager,
         floatingPanelController: FloatingPanelController?,
         notchDetector: NotchDetector) {
        self.menuBarManager = menuBarManager
        self.floatingPanelController = floatingPanelController
        self.notchDetector = notchDetector
        self.autoCollapseDelay = UserDefaults.standard.hairpinAutoCollapseDelay
        self.triggerMode = TriggerMode(rawValue: UserDefaults.standard.hairpinTriggerMode) ?? .clickOnly

        evaluateTrackingRequirement()
    }

    // MARK: - Public API

    func updateAutoCollapseDelay(_ delay: Double) {
        autoCollapseDelay = delay
        evaluateTrackingRequirement()
    }

    func updateTriggerMode(_ mode: TriggerMode) {
        triggerMode = mode
        if mode == .clickOnly {
            hoverExpandTimer?.invalidate()
            hoverExpandTimer = nil
        }
        evaluateTrackingRequirement()
    }

    func handleToggle(isCollapsed: Bool) {
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil

        if !isCollapsed {
            scheduleAutoCollapse()
        }

        evaluateTrackingRequirement()
    }

    // MARK: - Demand-Driven Tracking Control

    /// Determines whether mouse tracking is genuinely needed given current state & settings.
    /// Privacy rule: If no feature requires tracking right now, unregister the monitor immediately.
    private func evaluateTrackingRequirement() {
        let needsTrackingForHover = (triggerMode == .hoverAndClick) && menuBarManager.isCollapsed
        let needsTrackingForAutoCollapse = (autoCollapseDelay >= 0) && !menuBarManager.isCollapsed

        if needsTrackingForHover || needsTrackingForAutoCollapse {
            startTracking()
        } else {
            stopTracking()
        }
    }

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true

        // PRIVACY: Only monitor mouseMoved — no click events are observed.
        // The event argument is discarded; only the static cursor coordinate
        // is checked for hit-testing against the top bar rect.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
        }
    }

    func stopTracking() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil
        hoverExpandTimer?.invalidate()
        hoverExpandTimer = nil
        isTracking = false
    }

    // MARK: - Event Handling

    private func handleMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation

        let inMenuBar = isInMenuBarArea(mouseLocation)
        let nearNotch = isNearNotch(mouseLocation)

        if inMenuBar || nearNotch {
            // Cursor is in menu bar / notch area — reset auto-collapse timer
            autoCollapseTimer?.invalidate()
            autoCollapseTimer = nil

            // Hover-to-expand
            if triggerMode == .hoverAndClick && menuBarManager.isCollapsed {
                startHoverExpandTimer()
            }
        } else {
            // Cursor left menu bar area
            hoverExpandTimer?.invalidate()
            hoverExpandTimer = nil

            if !menuBarManager.isCollapsed {
                scheduleAutoCollapse()
            }
        }
    }

    // MARK: - Menu Bar Area Detection

    private func isInMenuBarArea(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let menuBarHeight = NSStatusBar.system.thickness
        let menuBarMinY = screen.frame.maxY - (notchDetector.hasNotch ? notchDetector.topInset : menuBarHeight)
        return point.y >= menuBarMinY && point.y <= screen.frame.maxY
    }

    private func isNearNotch(_ point: NSPoint) -> Bool {
        guard notchDetector.hasNotch else { return false }
        let notch = notchDetector.notchRect
        guard notch != .zero else { return false }
        // Expand the notch rect downward a bit for easier hover detection
        let expandedNotch = notch.insetBy(dx: -20, dy: -30)
        return expandedNotch.contains(point)
    }

    // MARK: - Auto-Collapse Timer

    private func scheduleAutoCollapse() {
        autoCollapseTimer?.invalidate()

        guard autoCollapseDelay >= 0 else { return } // "never" mode

        let delay = autoCollapseDelay == 0 ? 0.3 : autoCollapseDelay

        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.menuBarManager.isCollapsed else { return }
                self.menuBarManager.collapse()
            }
        }
    }

    // MARK: - Hover Expand Timer

    private func startHoverExpandTimer() {
        guard hoverExpandTimer == nil else { return }

        hoverExpandTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.menuBarManager.isCollapsed {
                    self.menuBarManager.expand()
                }
                self.hoverExpandTimer = nil
            }
        }
    }
}
