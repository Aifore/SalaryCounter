import AppKit
import SwiftUI

@MainActor
final class DesktopPetController {
    static let shared = DesktopPetController()

    private var panel: FloatingPanel?
    private let autosaveName = "SalaryCounterDesktopPet"

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.orderFrontRegardless()
        SettingsStore.shared.desktopPetShown = true
    }

    func hide() {
        panel?.close()
        panel = nil
        SettingsStore.shared.desktopPetShown = false
    }

    private func makePanel() -> FloatingPanel {
        let size = NSSize(width: 156, height: 144)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: DesktopPetView()
            .environmentObject(SettingsStore.shared)
            .environmentObject(Ticker.shared))
        panel.title = "小猪桌宠"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let restored = panel.setFrameUsingName(autosaveName)
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.contains(panel.frame) }
        if !restored || !onScreen, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 24, y: frame.minY + 24))
        }
        panel.setFrameAutosaveName(autosaveName)
        return panel
    }
}

struct DesktopPetView: View {
    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var ticker: Ticker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let estimate = YearBonus.estimate(
            monthlySalary: store.settings.monthlySalary,
            bonusMonths: store.settings.bonusMonths,
            at: ticker.now
        )

        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let lift = reduceMotion ? 0 : sin(context.date.timeIntervalSinceReferenceDate * .pi / 2) * 3

            PiggyBankFigure(progress: estimate.progress, filled: estimate.configured)
                .scaleEffect(1.6)
                .offset(y: lift)
                .frame(width: 156, height: 144)
        }
        .contentShape(Rectangle())
        .help("拖动小猪可以移动，右键可以收起")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("小猪桌宠")
        .accessibilityHint("可以拖动位置，或在概览中收起")
        .accessibilityAction(named: "收起小猪桌宠") { DesktopPetController.shared.hide() }
        .contextMenu {
            Button("收起小猪桌宠") { DesktopPetController.shared.hide() }
        }
    }
}
