import SwiftUI
import AppKit

/// 无边框、可拖动、可置顶的桌面小窗
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class DesktopWindowController {
    static let shared = DesktopWindowController()

    private var panel: FloatingPanel?
    private let autosaveName = "SalaryCounterDesktopWindow"

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        applyLevel()
        panel.orderFrontRegardless()
        SettingsStore.shared.desktopShown = true
    }

    func hide() {
        panel?.orderOut(nil)
        SettingsStore.shared.desktopShown = false
    }

    func applyLevel() {
        guard let panel else { return }
        let onTop = SettingsStore.shared.settings.desktopAlwaysOnTop
        panel.level = onTop ? .floating : .normal
        panel.isFloatingPanel = onTop
    }

    private func makePanel() -> FloatingPanel {
        let root = DesktopView()
            .environmentObject(SettingsStore.shared)
            .environmentObject(Ticker.shared)
        let hosting = NSHostingView(rootView: root)
        let size = hosting.fittingSize

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 恢复上次位置；没有的话放在屏幕右上角
        if !panel.setFrameUsingName(autosaveName), let screen = NSScreen.main {
            let vf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: vf.maxX - size.width - 24, y: vf.maxY - size.height - 24))
        }
        panel.setFrameAutosaveName(autosaveName)
        return panel
    }
}

struct DesktopView: View {
    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var ticker: Ticker
    // 不用 @State：只装了 Command Line Tools 时，新 SDK 里的 @State 宏无法展开
    @StateObject private var hover = UIBox(false)

    var body: some View {
        let s = store.settings
        let snap = SalaryCalculator(settings: s).snapshot(at: ticker.now)
        let value = s.menuBarMode == .today ? snap.todayEarned : snap.monthEarned

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(snap.status.title, systemImage: snap.status.symbol)
                Spacer()
                Text(snap.hint).monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(Fmt.money(value, symbol: s.currencySymbol, decimals: max(s.decimals, 2)))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            ProgressView(value: snap.progress)

            HStack {
                Text(s.menuBarMode == .today ? "今日已赚" : "本月已赚")
                Spacer()
                Text("时薪 " + Fmt.money(snap.hourly, symbol: s.currencySymbol, decimals: 2))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 270)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if hover.value {
                Button {
                    DesktopWindowController.shared.hide()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("关闭桌面窗口")
            }
        }
        .onHover { hover.value = $0 }
        .contextMenu {
            Toggle("置顶", isOn: Binding(
                get: { store.settings.desktopAlwaysOnTop },
                set: {
                    store.settings.desktopAlwaysOnTop = $0
                    DesktopWindowController.shared.applyLevel()
                }
            ))
            Picker("显示", selection: $store.settings.menuBarMode) {
                ForEach(MenuBarMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Divider()
            Button("关闭桌面窗口") { DesktopWindowController.shared.hide() }
        }
    }
}

/// 毛玻璃背景
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
