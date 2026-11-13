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
        let size = NSSize(width: 108, height: 112)
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
        panel.setContentSize(size)
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
    @StateObject private var touchedAt = UIBox<Date?>(nil)
    @StateObject private var hovering = UIBox(false)

    var body: some View {
        let settings = store.settings
        let snapshot = SalaryCalculator(settings: settings).snapshot(at: ticker.now)
        let earned = Fmt.money(snapshot.todayEarned, symbol: settings.currencySymbol, decimals: settings.decimals)

        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let pose = DesktopPetPose(
                date: reduceMotion ? ticker.now : context.date,
                touchedAt: touchedAt.value,
                status: snapshot.status,
                reduceMotion: reduceMotion
            )

            ZStack(alignment: .bottom) {
                PiggyBankFigure(progress: snapshot.progress, filled: true, isPet: true, eyesClosed: pose.eyesClosed)
                    .scaleEffect(x: 1 + pose.breath, y: 1 - pose.breath, anchor: .bottom)
                    .rotationEffect(.degrees(pose.sway), anchor: .bottom)
                    .offset(y: -pose.lift - 6)

                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.pink)
                    .offset(x: 26, y: -68 - pose.heartRise)
                    .opacity(pose.heartOpacity)

                if hovering.value {
                    Text("今日 " + earned)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(width: 108, height: 112)
        }
        .overlay { DesktopPetInteraction { touchedAt.value = Date() } }
        .onHover { hovering.value = $0 }
        .help("\(snapshot.status.title) · 今日已赚 \(earned)\n点击摸摸，拖动搬家，右键收起")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("每日小猪，\(snapshot.status.title)，今日已赚 \(earned)")
        .accessibilityHint("点击摸摸，拖动移动位置")
        .accessibilityAction(named: "摸摸小猪") { touchedAt.value = Date() }
        .accessibilityAction(named: "收起小猪桌宠") { DesktopPetController.shared.hide() }
    }
}

struct DesktopPetPose {
    let eyesClosed: Bool
    let breath: Double
    let sway: Double
    let lift: Double
    let heartOpacity: Double
    let heartRise: Double

    init(date: Date, touchedAt: Date?, status: WorkStatus, reduceMotion: Bool) {
        let time = date.timeIntervalSinceReferenceDate
        let elapsed = touchedAt.map { max(0, date.timeIntervalSince($0)) } ?? 2
        let reacting = elapsed < 1.4
        let resting = status == .lunch || status == .offWork || status == .restDay

        eyesClosed = (!reacting && resting) || (!reduceMotion && time.truncatingRemainder(dividingBy: 5.2) < 0.16)
        breath = reduceMotion ? 0 : sin(time * .pi) * 0.018
        sway = reduceMotion || resting ? 0 : sin(time * .pi / 2) * 3
        lift = reduceMotion ? 0 : (reacting ? abs(sin(elapsed * .pi * 2)) * 9 * (1 - elapsed / 1.4) : 0)
        heartOpacity = reacting ? 1 - elapsed / 1.4 : 0
        heartRise = reduceMotion ? 0 : min(elapsed / 1.4, 1) * 15
    }
}

private struct DesktopPetInteraction: NSViewRepresentable {
    var onPet: () -> Void

    func makeNSView(context: Context) -> DesktopPetInteractionView {
        let view = DesktopPetInteractionView()
        view.onPet = onPet
        return view
    }

    func updateNSView(_ view: DesktopPetInteractionView, context: Context) {
        view.onPet = onPet
    }
}

final class DesktopPetInteractionView: NSView {
    var onPet: () -> Void = {}
    private var mouseDownEvent: NSEvent?

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownEvent else { return }
        let distance = hypot(event.locationInWindow.x - start.locationInWindow.x,
                             event.locationInWindow.y - start.locationInWindow.y)
        guard distance >= 3 else { return }
        mouseDownEvent = nil
        // 原生拖动负责跨屏坐标换算；清空按下事件，避免松手时又触发摸摸。
        window?.performDrag(with: start)
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownEvent != nil else { return }
        mouseDownEvent = nil
        onPet()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "收起小猪桌宠", action: #selector(hidePet), keyEquivalent: "")
        item.target = self
        return menu
    }

    @objc private func hidePet() {
        DesktopPetController.shared.hide()
    }
}
