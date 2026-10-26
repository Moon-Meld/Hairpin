import AppKit
import Combine

/// Detects whether the current main display has a notch and computes
/// the available menu-bar real estate to the right of the notch.
@MainActor
final class NotchDetector: ObservableObject {

    // MARK: - Published State

    /// `true` when the main screen has a physical notch (camera housing).
    @Published private(set) var hasNotch: Bool = false

    /// The usable rect to the right of the notch (menu-bar status-item area).
    /// On non-notch screens this equals the full screen width at menu-bar height.
    @Published private(set) var availableStatusBarRect: CGRect = .zero

    /// The safe-area top inset of the main screen (> 0 means notch present).
    @Published private(set) var topInset: CGFloat = 0

    /// The full frame of the main screen.
    @Published private(set) var screenFrame: CGRect = .zero

    /// The rect of the notch area itself (zero on non-notch screens).
    @Published private(set) var notchRect: CGRect = .zero

    // MARK: - Private

    private var screenObserver: Any?

    // MARK: - Init

    init() {
        refresh()
        // Re-detect when displays change (external monitor plugged in, etc.)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Force a refresh of notch metrics (call when the active screen changes).
    func refresh() {
        guard let screen = NSScreen.main else { return }

        screenFrame = screen.frame
        let insets = screen.safeAreaInsets
        topInset = insets.top

        // A top inset > 0 indicates the camera housing / notch
        hasNotch = insets.top > 0

        if hasNotch {
            // auxiliaryTopRightArea gives us the rect to the right of the notch
            if let auxRight = screen.auxiliaryTopRightArea {
                availableStatusBarRect = auxRight
                // The notch occupies the gap between the left safe area and the right auxiliary area
                let notchMinX = insets.left > 0 ? insets.left : 0
                let notchMaxX = auxRight.minX
                let notchY = screen.frame.maxY - insets.top
                notchRect = CGRect(
                    x: screen.frame.origin.x + notchMinX,
                    y: notchY,
                    width: max(0, notchMaxX - notchMinX),
                    height: insets.top
                )
            } else {
                // Fallback: estimate notch width ~200pt centered
                let notchWidth: CGFloat = 200
                let notchX = screen.frame.midX - notchWidth / 2
                notchRect = CGRect(
                    x: notchX,
                    y: screen.frame.maxY - insets.top,
                    width: notchWidth,
                    height: insets.top
                )
                let rightX = notchX + notchWidth
                availableStatusBarRect = CGRect(
                    x: rightX,
                    y: screen.frame.maxY - insets.top,
                    width: screen.frame.maxX - rightX,
                    height: insets.top
                )
            }
        } else {
            // Non-notch screen: the entire top bar is available
            let menuBarHeight: CGFloat = NSStatusBar.system.thickness
            availableStatusBarRect = CGRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
            notchRect = .zero
        }
    }

    /// Width in points available for status items to the right of the notch.
    var availableWidth: CGFloat {
        return availableStatusBarRect.width
    }

    /// The menu bar height on the main screen.
    var menuBarHeight: CGFloat {
        return NSStatusBar.system.thickness
    }

    /// The Y coordinate for the bottom edge of the menu bar (top of content area).
    var menuBarBottomY: CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        if hasNotch {
            return screen.frame.maxY - topInset
        } else {
            return screen.frame.maxY - menuBarHeight
        }
    }
}
