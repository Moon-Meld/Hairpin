import AppKit
import Combine

// MARK: - Delegate Protocol

@MainActor
protocol MenuBarManagerDelegate: AnyObject {
    func menuBarManagerDidRequestSettings()
    func menuBarManagerDidToggle(isCollapsed: Bool)
    func menuBarManagerDidRequestFloatingPanel()
}

// MARK: - MenuBarManager

/// Core folding engine using the "dual NSStatusItem variable-width spacer" technique.
///
/// - `toggleItem`: always-visible control button (rightmost of our two items).
/// - `separatorItem`: draggable anchor to the left of `toggleItem`.
///   In **collapsed** state its length is set to 10 000, pushing everything
///   to its left off-screen.  In **expanded** state the length shrinks back
///   to a thin separator so the hidden icons reappear.
@MainActor
final class MenuBarManager: ObservableObject {

    // MARK: - Public State

    @Published private(set) var state: CollapseState = .expanded
    weak var delegate: MenuBarManagerDelegate?

    // MARK: - Status Items

    private var toggleItem: NSStatusItem!
    private var separatorItem: NSStatusItem!
    private let notchDetector: NotchDetector

    /// The extreme width used to push icons off-screen.
    private let collapsedWidth: CGFloat = 10_000

    /// Timer to periodically verify ordering.
    private var orderingTimer: Timer?

    // MARK: - Init

    init(notchDetector: NotchDetector) {
        self.notchDetector = notchDetector

        UserDefaults.registerHairpinDefaults()

        setupStatusItems()
        applyOrderingGuard()

        // Restore persisted state
        if UserDefaults.standard.hairpinIsCollapsed {
            collapse(animated: false)
        }
    }

    // MARK: - Setup

    private func setupStatusItems() {
        // --- Toggle Item (right-most, always visible) ---
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = toggleItem.button {
            btn.image = NSImage(systemSymbolName: "line.3.horizontal.decrease",
                                accessibilityDescription: "Hairpin Toggle")
            btn.image?.size = NSSize(width: 18, height: 18)
            btn.image?.isTemplate = true
            btn.action = #selector(handleToggleClick(_:))
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // --- Separator Item (left of toggle, user-draggable with Cmd) ---
        separatorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateSeparatorAppearance()
        separatorItem.autosaveName = "HairpinSeparator"
    }

    // MARK: - Public API

    /// Toggle between collapsed / expanded.
    func toggle() {
        switch state {
        case .collapsed: expand()
        case .expanded:  collapse()
        }
    }

    /// Collapse — push all icons to the left of the separator off-screen.
    func collapse(animated: Bool = true) {
        state = .collapsed
        UserDefaults.standard.hairpinIsCollapsed = true

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                separatorItem.length = collapsedWidth
            }
        } else {
            separatorItem.length = collapsedWidth
        }

        updateToggleIcon()
        delegate?.menuBarManagerDidToggle(isCollapsed: true)
    }

    /// Expand — restore the separator to its thin width so hidden icons reappear.
    func expand(animated: Bool = true) {
        state = .expanded
        UserDefaults.standard.hairpinIsCollapsed = false

        let targetWidth = separatorDisplayWidth

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                separatorItem.length = targetWidth
            }
        } else {
            separatorItem.length = targetWidth
        }

        updateSeparatorAppearance()
        updateToggleIcon()
        delegate?.menuBarManagerDidToggle(isCollapsed: false)
    }

    /// Whether the bar is currently collapsed.
    var isCollapsed: Bool { state == .collapsed }

    // MARK: - Separator Display Width

    /// The visible width of the separator when expanded, based on user preference.
    private var separatorDisplayWidth: CGFloat {
        let style = SeparatorStyle(rawValue: UserDefaults.standard.hairpinSeparatorStyle) ?? .verticalLine
        switch style {
        case .invisible: return 1
        default:         return 20
        }
    }

    // MARK: - Appearance Updates

    func updateSeparatorAppearance() {
        let style = SeparatorStyle(rawValue: UserDefaults.standard.hairpinSeparatorStyle) ?? .verticalLine

        guard let btn = separatorItem.button else { return }

        if style == .invisible {
            btn.title = ""
            btn.image = nil
        } else {
            btn.title = style.expandedSymbol
            btn.image = nil
            btn.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }
    }

    private func updateToggleIcon() {
        guard let btn = toggleItem.button else { return }
        let symbolName: String
        switch state {
        case .collapsed:
            symbolName = "chevron.left.2"   // indicates "expand left"
        case .expanded:
            symbolName = "line.3.horizontal.decrease"
        }
        btn.image = NSImage(systemSymbolName: symbolName,
                            accessibilityDescription: "Hairpin Toggle")
        btn.image?.size = NSSize(width: 18, height: 18)
        btn.image?.isTemplate = true
    }

    // MARK: - Click Handling

    @objc private func handleToggleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            // Left click — if notch screen and collapsed, offer floating panel
            if notchDetector.hasNotch && isCollapsed {
                delegate?.menuBarManagerDidRequestFloatingPanel()
            } else {
                toggle()
            }
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        let toggleTitle = isCollapsed ? "Show Hidden Icons" : "Hide Icons"
        let toggleAction = NSMenuItem(title: toggleTitle, action: #selector(menuToggle), keyEquivalent: "")
        toggleAction.target = self
        menu.addItem(toggleAction)

        menu.addItem(.separator())

        let autoItem = NSMenuItem(title: "Auto-Collapse", action: nil, keyEquivalent: "")
        let autoSub = NSMenu()
        for delay in AutoCollapseDelay.allCases {
            let item = NSMenuItem(title: delay.label, action: #selector(setAutoCollapseDelay(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(delay.rawValue * 10)  // encode as int
            if UserDefaults.standard.hairpinAutoCollapseDelay == delay.rawValue {
                item.state = .on
            }
            autoSub.addItem(item)
        }
        autoItem.submenu = autoSub
        menu.addItem(autoItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Hairpin", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        // Clear menu so left-click works normally next time
        DispatchQueue.main.async { [weak self] in
            self?.toggleItem.menu = nil
        }
    }

    @objc private func menuToggle() { toggle() }

    @objc private func setAutoCollapseDelay(_ sender: NSMenuItem) {
        let value = Double(sender.tag) / 10.0
        UserDefaults.standard.hairpinAutoCollapseDelay = value
    }

    @objc private func openSettings() {
        delegate?.menuBarManagerDidRequestSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Ordering Guard

    /// Periodically check that `separatorItem` is left of `toggleItem`.
    /// If a user accidentally drags them out of order, we fix it.
    private func applyOrderingGuard() {
        orderingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.verifyOrdering()
            }
        }
    }

    private func verifyOrdering() {
        guard let sepX = separatorItem.button?.window?.frame.origin.x,
              let togX = toggleItem.button?.window?.frame.origin.x else { return }
        // separator must be to the LEFT of toggle (lower x in LTR menu bar)
        if sepX > togX && state == .expanded {
            // Items are out of order — recreate them
            NSStatusBar.system.removeStatusItem(separatorItem)
            NSStatusBar.system.removeStatusItem(toggleItem)
            setupStatusItems()
            if UserDefaults.standard.hairpinIsCollapsed {
                collapse(animated: false)
            }
        }
    }

    // MARK: - Toggle Item Frame (for mouse tracking)

    /// The screen-coordinate frame of the toggle button.
    var toggleItemFrame: CGRect {
        toggleItem.button?.window?.frame ?? .zero
    }

    /// The screen-coordinate frame of the separator button.
    var separatorItemFrame: CGRect {
        separatorItem.button?.window?.frame ?? .zero
    }
}
