import SwiftUI
import AppKit
import ServiceManagement

/// 点击菜单栏数字后弹出的面板
struct MenuContentView: View {
    enum Page: Hashable { case overview, settings }
    // 不用 @State：只装了 Command Line Tools 时，新 SDK 里的 @State 宏无法展开
    @StateObject private var page = UIBox(Page.overview)
    @StateObject private var panelHeight = UIBox(CGFloat.zero)

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $page.value) {
                Text("概览").tag(Page.overview)
                Text("设置").tag(Page.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 4)

            switch page.value {
            case .overview: OverviewView()
            case .settings: SettingsView()
            }
        }
        .frame(width: 330, alignment: .top)
        // 高度锁定为当前这一页的理想高度。否则面板给出的大高度会被再量回去，空白就消不掉。
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: PanelHeightKey.self, value: proxy.size.height)
            }
            .allowsHitTesting(false)
        }
        .onPreferenceChange(PanelHeightKey.self) { newHeight in
            let rounded = newHeight.rounded(.toNearestOrAwayFromZero)
            guard rounded > 1, abs(panelHeight.value - rounded) >= 1 else { return }
            panelHeight.value = rounded
        }
        .background {
            MenuBarPanelSizer(contentHeight: panelHeight.value)
        }
    }
}

/// 弹出面板只跟着内容变高，不会自己缩回内容高度。
/// 根视图原先只锁了宽度，面板比这一页高时，内容会被垂直居中，
/// 上下就各留一块菜单栏面板自带的半透明空白，看起来也不再贴着状态栏图标。
/// AppKit 窗口原点在左下角，缩短高度时要把 origin.y 上移同样的量，上边缘才不动。
private enum MenuBarPanelGeometry {
    static func frame(windowFrame: CGRect, contentViewHeight: CGFloat, swiftUIHeight: CGFloat) -> CGRect {
        let content = swiftUIHeight.rounded(.toNearestOrAwayFromZero)
        guard content > 1 else { return windowFrame }
        let chrome = contentViewHeight > 1 ? max(0, windowFrame.height - contentViewHeight) : 0
        let target = content + chrome
        guard abs(windowFrame.height - target) >= 1 else { return windowFrame }
        var next = windowFrame
        next.origin.y += windowFrame.height - target
        next.size.height = target
        return next
    }
}

private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MenuBarPanelSizer: NSViewRepresentable {
    var contentHeight: CGFloat

    func makeNSView(context: Context) -> MenuBarPanelSizerView {
        let view = MenuBarPanelSizerView()
        view.contentHeight = contentHeight
        return view
    }

    func updateNSView(_ nsView: MenuBarPanelSizerView, context: Context) {
        nsView.contentHeight = contentHeight
    }
}

private final class MenuBarPanelSizerView: NSView {
    var contentHeight: CGFloat = 0 {
        didSet { schedule() }
    }

    private var scheduled = false
    /// 同一个内容高度只写一次 min/max。写不进去时也不要每个布局周期再写，避免和面板抢高度。
    private var lockedHeight: CGFloat = 0

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        schedule()
    }

    override func layout() {
        super.layout()
        guard needsApply else { return }
        schedule()
    }

    private var needsApply: Bool {
        guard contentHeight > 1, let window else { return false }
        let next = MenuBarPanelGeometry.frame(
            windowFrame: window.frame,
            contentViewHeight: window.contentView?.bounds.height ?? 0,
            swiftUIHeight: contentHeight
        )
        if next.height != window.frame.height || abs(next.origin.y - window.frame.origin.y) >= 1 {
            return true
        }
        let content = contentHeight.rounded(.toNearestOrAwayFromZero)
        guard lockedHeight != content else { return false }
        return abs(window.contentMinSize.height - content) >= 1
            || abs(window.contentMaxSize.height - content) >= 1
    }

    private func schedule() {
        guard contentHeight > 1, !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            self.apply()
        }
    }

    private func apply() {
        guard contentHeight > 1, let window else { return }
        let content = contentHeight.rounded(.toNearestOrAwayFromZero)
        guard content.isFinite else { return }
        // 先按当前 frame 算好上边缘，再改 min/max。反过来的话，系统会先按左下角原点缩短窗口，面板就掉到菜单栏下面。
        let next = MenuBarPanelGeometry.frame(
            windowFrame: window.frame,
            contentViewHeight: window.contentView?.bounds.height ?? 0,
            swiftUIHeight: content
        )
        let frameNeedsUpdate = next != window.frame
        var minSize = window.contentMinSize
        var maxSize = window.contentMaxSize
        let locksNeedUpdate = lockedHeight != content
            && (abs(minSize.height - content) >= 1 || abs(maxSize.height - content) >= 1)
        guard frameNeedsUpdate || locksNeedUpdate else { return }

        if locksNeedUpdate {
            if content >= maxSize.height {
                maxSize.height = content
                window.contentMaxSize = maxSize
                minSize.height = content
                window.contentMinSize = minSize
            } else {
                minSize.height = content
                window.contentMinSize = minSize
                maxSize.height = content
                window.contentMaxSize = maxSize
            }
            lockedHeight = content
        }
        if frameNeedsUpdate {
            window.setFrame(next, display: true, animate: false)
        }
    }
}

// MARK: - 概览

struct OverviewView: View {
    @EnvironmentObject private var store: SettingsStore
    @EnvironmentObject private var ticker: Ticker

    var body: some View {
        let s = store.settings
        let snap = SalaryCalculator(settings: s).snapshot(at: ticker.now)
        let money = { (v: Double, d: Int) in Fmt.money(v, symbol: s.currencySymbol, decimals: d) }

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(snap.status.title, systemImage: snap.status.symbol)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(snap.hint)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("今日已赚")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(money(snap.todayEarned, max(s.decimals, 2)))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: snap.progress)
                HStack {
                    Text("今日进度")
                    Spacer()
                    Text(String(format: "%.1f%%", snap.progress * 100)).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    StatCell(title: "本月已赚", value: money(snap.monthEarned, 2))
                    StatCell(title: "日薪", value: money(snap.dailySalary, 2))
                }
                GridRow {
                    StatCell(title: "时薪", value: money(snap.hourly, 2))
                    StatCell(title: "每秒", value: money(snap.perSecond, 4))
                }
            }

            YearBonusSection(
                monthlySalary: s.monthlySalary,
                bonusMonths: s.bonusMonths,
                currencySymbol: s.currencySymbol,
                decimals: s.decimals,
                now: ticker.now
            )

            Divider()

            Button {
                DesktopPetController.shared.toggle()
            } label: {
                Label(store.desktopPetShown ? "收起小猪桌宠" : "召唤小猪桌宠", systemImage: "pawprint")
            }

            HStack {
                Button {
                    DesktopWindowController.shared.toggle()
                } label: {
                    Label(store.desktopShown ? "关闭桌面窗口" : "打开桌面窗口",
                          systemImage: "macwindow")
                }
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
    }
}

struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 设置

struct SettingsView: View {
    @EnvironmentObject private var store: SettingsStore
    @StateObject private var launchAtLogin = UIBox(SMAppService.mainApp.status == .enabled)
    @StateObject private var loginError = UIBox<String?>(nil)

    // 周一 … 周日 对应 Calendar weekday
    private let weekdays: [(Int, String)] = [(2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")]

    var body: some View {
        Form {
            Section("工资") {
                TextField("月薪", value: $store.settings.monthlySalary, format: .number)
                TextField(
                    "年终奖月数",
                    value: bonusMonthsBinding,
                    format: .number.precision(.fractionLength(0...2))
                )
                .help("按当前月薪折算。填 0 表示不设置，可以写 1.5 这样的小数。")
                TextField("每月计薪天数", value: $store.settings.workDaysPerMonth, format: .number)
                LabeledContent("工作日") {
                    HStack(spacing: 4) {
                        ForEach(weekdays, id: \.0) { day, name in
                            Toggle(name, isOn: weekdayBinding(day))
                                .toggleStyle(.button)
                        }
                    }
                }
            }

            Section("时间") {
                DatePicker("上班时间", selection: timeBinding(\.startMinutes), displayedComponents: .hourAndMinute)
                DatePicker("下班时间", selection: timeBinding(\.endMinutes), displayedComponents: .hourAndMinute)
                Toggle("扣除午休（不计薪）", isOn: $store.settings.lunchEnabled)
                if store.settings.lunchEnabled {
                    DatePicker("午休开始", selection: timeBinding(\.lunchStartMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("午休结束", selection: timeBinding(\.lunchEndMinutes), displayedComponents: .hourAndMinute)
                }
                if store.settings.endMinutes <= store.settings.startMinutes {
                    Text("⚠️ 下班时间需要晚于上班时间").foregroundStyle(.red)
                }
            }

            Section("显示") {
                Picker("菜单栏显示", selection: $store.settings.menuBarMode) {
                    ForEach(MenuBarMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField("货币符号", text: $store.settings.currencySymbol)
                Stepper("小数位数：\(store.settings.decimals)", value: $store.settings.decimals, in: 0...4)
                Toggle("桌面窗口置顶", isOn: Binding(
                    get: { store.settings.desktopAlwaysOnTop },
                    set: {
                        store.settings.desktopAlwaysOnTop = $0
                        DesktopWindowController.shared.applyLevel()
                    }
                ))
            }

            Section("系统") {
                Toggle("开机自动启动", isOn: Binding(
                    get: { launchAtLogin.value },
                    set: { setLaunchAtLogin($0) }
                ))
                if let message = loginError.value {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }

    private var bonusMonthsBinding: Binding<Double> {
        Binding(
            get: { store.settings.bonusMonths },
            set: { store.settings.bonusMonths = YearBonus.sanitizedMonths($0) }
        )
    }

    private func weekdayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { store.settings.workWeekdays.contains(day) },
            set: { on in
                if on { store.settings.workWeekdays.insert(day) }
                else { store.settings.workWeekdays.remove(day) }
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<SalarySettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let m = store.settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.settings[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin.value = on
            loginError.value = nil
        } catch {
            loginError.value = "设置失败：\(error.localizedDescription)（请先把 App 放到“应用程序”文件夹再试）"
        }
    }
}
