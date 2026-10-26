import AppKit
import SwiftUI

/// A floating panel that appears just below the notch / menu bar to display
/// the hidden status-bar icons region.  On notch screens this lets users
/// access icons that would otherwise be swallowed by the camera housing.
///
/// ## Visual Design
/// Frosted-glass pill with a spring animation and subtle glow — inspired by
/// the macOS Dynamic Island aesthetic. The panel hugs the bottom edge of the
/// notch and adapts its width to the available auxiliary area.
@MainActor
final class FloatingPanelController {

    // MARK: - Dependencies

    private let notchDetector: NotchDetector
    private let menuBarManager: MenuBarManager

    // MARK: - Panel

    private var panel: NSPanel?
    private var isVisible = false
    private var clickOutsideMonitor: Any?
    private var keyMonitor: Any?

    // MARK: - Init

    init(notchDetector: NotchDetector, menuBarManager: MenuBarManager) {
        self.notchDetector = notchDetector
        self.menuBarManager = menuBarManager
    }

    // MARK: - Public API

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard !isVisible else { return }

        notchDetector.refresh()

        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 56

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let xOrigin: CGFloat
        let yOrigin: CGFloat

        if notchDetector.hasNotch {
            let notch = notchDetector.notchRect
            xOrigin = notch.midX - panelWidth / 2
            // Tuck snugly under the notch
            yOrigin = screen.frame.maxY - notchDetector.topInset - panelHeight - 2
        } else {
            xOrigin = screen.frame.midX - panelWidth / 2
            yOrigin = screen.frame.maxY - NSStatusBar.system.thickness - panelHeight - 4
        }

        let panelFrame = CGRect(x: xOrigin, y: yOrigin, width: panelWidth, height: panelHeight)

        let p = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false // we draw our own shadow in SwiftUI
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.animationBehavior = .none

        let contentView = FloatingPanelView(
            hasNotch: notchDetector.hasNotch,
            onExpandTapped: { [weak self] in
                self?.menuBarManager.expand()
                self?.hidePanel()
            },
            onDismiss: { [weak self] in
                self?.hidePanel()
            }
        )
        p.contentView = NSHostingView(rootView: contentView)

        // Start slightly above final position for a slide-down effect
        var startFrame = panelFrame
        startFrame.origin.y += 8
        p.setFrame(startFrame, display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
            p.animator().setFrame(panelFrame, display: true)
            p.animator().alphaValue = 1.0
        }

        self.panel = p
        self.isVisible = true

        // Dismiss on ESC or click outside
        installDismissMonitors()
    }

    func hidePanel() {
        guard isVisible, let p = panel else { return }
        removeDismissMonitors()

        var endFrame = p.frame
        endFrame.origin.y += 6

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().setFrame(endFrame, display: true)
            p.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            p.orderOut(nil)
            self?.panel = nil
            self?.isVisible = false
        })
    }

    // MARK: - Auto-Dismiss Monitors

    private func installDismissMonitors() {
        if UserDefaults.standard.hairpinAutoDismissPanel {
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, let p = self.panel else { return }
                    let mouseLoc = NSEvent.mouseLocation
                    if !p.frame.contains(mouseLoc) && !self.menuBarManager.toggleItemFrame.contains(mouseLoc) {
                        self.hidePanel()
                    }
                }
            }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 /* ESC */ {
                Task { @MainActor in
                    self?.hidePanel()
                }
                return nil
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let m = clickOutsideMonitor {
            NSEvent.removeMonitor(m)
            clickOutsideMonitor = nil
        }
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }
}

// MARK: - SwiftUI Floating Panel View

struct FloatingPanelView: View {
    let hasNotch: Bool
    let onExpandTapped: () -> Void
    let onDismiss: () -> Void

    @State private var isHoveringExpand = false
    @State private var isHoveringDismiss = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            // Animated indicator dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange, Color.orange.opacity(0.3)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 6
                    )
                )
                .frame(width: 8, height: 8)
                .scaleEffect(appeared ? 1.0 : 0.3)
                .opacity(appeared ? 1.0 : 0.0)

            // Info label
            VStack(alignment: .leading, spacing: 1) {
                Text(hasNotch ? "Behind the Notch" : "Hidden Icons")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))

                Text(hasNotch ? "Tap to reveal" : "Folded items")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            // Expand button — pill shape
            Button(action: onExpandTapped) {
                Text("Show All")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(nsColor: NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 1)),
                                        Color(nsColor: NSColor(red: 0.83, green: 0.47, blue: 0.42, alpha: 1))
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .scaleEffect(isHoveringExpand ? 1.06 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.25)) { isHoveringExpand = h }
            }

            // Dismiss
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(isHoveringDismiss ? 0.9 : 0.4))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(isHoveringDismiss ? 0.1 : 0.05))
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.easeOut(duration: 0.15)) { isHoveringDismiss = h }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                // Subtle warm tint overlay
                Color.orange.opacity(0.03)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        .shadow(color: .orange.opacity(0.08), radius: 24, x: 0, y: 4)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - NSVisualEffectView Wrapper

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
