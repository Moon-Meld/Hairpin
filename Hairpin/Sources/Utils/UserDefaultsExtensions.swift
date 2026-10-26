import Foundation

// MARK: - UserDefaults Keys & Extensions
//
// ## Privacy Design
// - All keys use an app-specific `com.hairpin.` prefix to prevent cross-app
//   key collisions and make it obvious which preferences belong to Hairpin.
// - Only UI-preference values are persisted (delay, style, boolean flags).
//   No user-identifiable data, timestamps, or activity logs are ever stored.

extension UserDefaults {

    // MARK: Keys — prefixed to prevent cross-app collision

    private enum Keys {
        static let autoCollapseDelay = "com.hairpin.autoCollapseDelay"
        static let triggerMode       = "com.hairpin.triggerMode"
        static let separatorStyle    = "com.hairpin.separatorStyle"
        static let launchAtLogin     = "com.hairpin.launchAtLogin"
        static let showOnboardingTip = "com.hairpin.showOnboardingTip"
        static let isCollapsed       = "com.hairpin.isCollapsed"
        static let clickAction       = "com.hairpin.clickAction"
        static let hapticFeedback    = "com.hairpin.hapticFeedback"
        static let autoDismissPanel  = "com.hairpin.autoDismissPanel"
    }

    // MARK: - Defaults Registration

    static func registerHairpinDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.autoCollapseDelay: AutoCollapseDelay.fiveSeconds.rawValue,
            Keys.triggerMode: TriggerMode.clickOnly.rawValue,
            Keys.separatorStyle: SeparatorStyle.verticalLine.rawValue,
            Keys.launchAtLogin: false,
            Keys.showOnboardingTip: true,
            Keys.isCollapsed: false,
            Keys.clickAction: ClickAction.notchDrawerWhenCollapsed.rawValue,
            Keys.hapticFeedback: true,
            Keys.autoDismissPanel: true,
        ])
    }

    // MARK: - Typed Accessors

    @objc dynamic var hairpinAutoCollapseDelay: Double {
        get { double(forKey: Keys.autoCollapseDelay) }
        set { set(newValue, forKey: Keys.autoCollapseDelay) }
    }

    @objc dynamic var hairpinTriggerMode: Int {
        get { integer(forKey: Keys.triggerMode) }
        set { set(newValue, forKey: Keys.triggerMode) }
    }

    @objc dynamic var hairpinSeparatorStyle: Int {
        get { integer(forKey: Keys.separatorStyle) }
        set { set(newValue, forKey: Keys.separatorStyle) }
    }

    @objc dynamic var hairpinClickAction: Int {
        get { integer(forKey: Keys.clickAction) }
        set { set(newValue, forKey: Keys.clickAction) }
    }

    var hairpinHapticFeedback: Bool {
        get { bool(forKey: Keys.hapticFeedback) }
        set { set(newValue, forKey: Keys.hapticFeedback) }
    }

    var hairpinAutoDismissPanel: Bool {
        get { bool(forKey: Keys.autoDismissPanel) }
        set { set(newValue, forKey: Keys.autoDismissPanel) }
    }

    var hairpinLaunchAtLogin: Bool {
        get { bool(forKey: Keys.launchAtLogin) }
        set { set(newValue, forKey: Keys.launchAtLogin) }
    }

    var showOnboardingTip: Bool {
        get { bool(forKey: Keys.showOnboardingTip) }
        set { set(newValue, forKey: Keys.showOnboardingTip) }
    }

    var hairpinIsCollapsed: Bool {
        get { bool(forKey: Keys.isCollapsed) }
        set { set(newValue, forKey: Keys.isCollapsed) }
    }
}
