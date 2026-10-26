import SwiftUI
import ServiceManagement

// MARK: - Design Tokens

/// Centralised design constants for visual consistency across the app.
enum DesignTokens {
    // Brand gradient (matches app icon gold → coral)
    static let brandGradient = LinearGradient(
        colors: [
            Color(nsColor: NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 1)),  // warm gold
            Color(nsColor: NSColor(red: 0.83, green: 0.47, blue: 0.42, alpha: 1))   // coral
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color.primary.opacity(0.03)
    static let subtleStroke    = Color.primary.opacity(0.06)
}

// MARK: - Settings View

struct SettingsView: View {

    @AppStorage("com.hairpin.autoCollapseDelay") private var autoCollapseDelay: Double = 5.0
    @AppStorage("com.hairpin.triggerMode")       private var triggerMode: Int = 0
    @AppStorage("com.hairpin.separatorStyle")    private var separatorStyle: Int = 1
    @AppStorage("com.hairpin.launchAtLogin")     private var launchAtLogin: Bool = false
    @AppStorage("com.hairpin.clickAction")       private var clickAction: Int = 1
    @AppStorage("com.hairpin.hapticFeedback")    private var hapticFeedback: Bool = true
    @AppStorage("com.hairpin.autoDismissPanel")  private var autoDismissPanel: Bool = true

    @State private var loginItemError: String?
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented tab bar
            tabBar
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider().opacity(0.3)

            // Tab content
            Group {
                switch selectedTab {
                case 0: generalTab
                case 1: appearanceTab
                case 2: privacyTab
                case 3: aboutTab
                default: generalTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(width: 420, height: 480)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "General",    icon: "gearshape",    index: 0)
            tabButton(title: "Appearance", icon: "paintbrush",   index: 1)
            tabButton(title: "Privacy",    icon: "lock.shield",  index: 2)
            tabButton(title: "About",      icon: "info.circle",  index: 3)
        }
        .padding(.horizontal, 20)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == index ? .medium : .regular, design: .rounded))
            }
            .foregroundColor(selectedTab == index ? .primary : .secondary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selectedTab == index ? DesignTokens.cardBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Startup card
                settingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Startup")

                        Toggle(isOn: $launchAtLogin) {
                            Label("Launch at Login", systemImage: "power")
                                .font(.system(size: 13))
                        }
                        .toggleStyle(.switch)
                        .tint(Color.orange)
                        .onChange(of: launchAtLogin) { newValue in
                            setLaunchAtLogin(newValue)
                        }

                        if let error = loginItemError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }

                // Behavior card
                settingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeader("Behavior")

                        Picker("Auto-Collapse", selection: $autoCollapseDelay) {
                            ForEach(AutoCollapseDelay.allCases) { delay in
                                Text(delay.label).tag(delay.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 13))

                        Picker("Trigger Mode", selection: $triggerMode) {
                            ForEach(TriggerMode.allCases) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 13))

                        Picker("Left-Click Action", selection: $clickAction) {
                            ForEach(ClickAction.allCases) { action in
                                Text(action.label).tag(action.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 13))

                        Toggle(isOn: $hapticFeedback) {
                            Label("Haptic Feedback on Click", systemImage: "hand.tap")
                                .font(.system(size: 13))
                        }
                        .toggleStyle(.switch)
                        .tint(Color.orange)

                        Toggle(isOn: $autoDismissPanel) {
                            Label("Auto-Dismiss Drawer on Click Outside", systemImage: "cursorarrow.and.square.on.square.dashed")
                                .font(.system(size: 13))
                        }
                        .toggleStyle(.switch)
                        .tint(Color.orange)
                    }
                }

                // Shortcut card
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Keyboard Shortcut")

                        HStack {
                            Text("Toggle Hidden Icons")
                                .font(.system(size: 13))
                            Spacer()
                            HStack(spacing: 3) {
                                keyCapView("⌘")
                                keyCapView("⇧")
                                keyCapView("B")
                            }
                        }

                        Text("Quickly show or hide your folded menu bar icons.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                settingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeader("Separator Style")

                        VStack(spacing: 8) {
                            ForEach(SeparatorStyle.allCases) { style in
                                separatorOption(style)
                            }
                        }
                    }
                }

                // Tip card with accent
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.brandGradient)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Drag to Reposition")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("Hold ⌘ and drag the separator in the menu bar. Icons to its left will be hidden when collapsed.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }
            .padding(20)
        }
    }

    private func separatorOption(_ style: SeparatorStyle) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                separatorStyle = style.rawValue
            }
        } label: {
            HStack {
                // Preview
                Text(style.expandedSymbol.isEmpty ? "   " : style.expandedSymbol)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                Text(style.label)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.primary.opacity(0.85))

                Spacer()

                if separatorStyle == style.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.brandGradient)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(separatorStyle == style.rawValue ? Color.orange.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Privacy Tab

    private var privacyTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                privacyRow(icon: "network.slash",             color: .green,  title: "No Network Access",  detail: "Zero internet connections. No telemetry or analytics.")
                privacyRow(icon: "keyboard.badge.ellipsis",   color: .blue,   title: "Zero Key Logging",   detail: "Only ⌘⇧B is registered via Carbon API. No keystrokes are observed.")
                privacyRow(icon: "cursorarrow.motionlines",   color: .purple, title: "Ephemeral Tracking",  detail: "Mouse position is checked transiently for menu-bar hit-testing only.")
                privacyRow(icon: "externaldrive.badge.xmark", color: .orange, title: "Minimal Storage",     detail: "Only UI preferences are saved. Zero activity logs.")
                privacyRow(icon: "eye.slash",                 color: .pink,   title: "No Screen Capture",   detail: "Hairpin never requests screen recording permissions.")
            }
            .padding(20)
        }
    }

    private func privacyRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(DesignTokens.subtleStroke, lineWidth: 0.5)
                )
        )
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "paperclip")
                    .font(.system(size: 42, weight: .thin))
                    .foregroundStyle(DesignTokens.brandGradient)
                    .rotationEffect(.degrees(-30))
            }

            Text("Hairpin")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.top, 8)

            Text("Menu Bar Manager for Notch Macs")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Text("v1.0.0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.top, 6)

            Spacer()

            Text("Tame your menu bar. Reclaim the notch.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(DesignTokens.brandGradient)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Reusable Components

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(DesignTokens.subtleStroke, lineWidth: 0.5)
                    )
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.5))
            .tracking(1.2)
    }

    private func keyCapView(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .frame(minWidth: 22, minHeight: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Could not \(enabled ? "enable" : "disable") launch at login. Please check System Settings → General → Login Items."
            launchAtLogin = !enabled
        }
    }
}
