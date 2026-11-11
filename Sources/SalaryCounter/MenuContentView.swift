import SwiftUI
import ServiceManagement

/// 点击菜单栏数字后弹出的面板
struct MenuContentView: View {
    enum Page: Hashable { case overview, settings }
    @State private var page: Page = .overview

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $page) {
                Text("概览").tag(Page.overview)
                Text("设置").tag(Page.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 4)

            switch page {
            case .overview: OverviewView()
            case .settings: SettingsView()
            }
        }
        .frame(width: 330)
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

            Divider()

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
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    // 周一 … 周日 对应 Calendar weekday
    private let weekdays: [(Int, String)] = [(2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")]

    var body: some View {
        Form {
            Section("工资") {
                TextField("月薪", value: $store.settings.monthlySalary, format: .number)
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
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 480)
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
            launchAtLogin = on
            loginError = nil
        } catch {
            loginError = "设置失败：\(error.localizedDescription)（请先把 App 放到“应用程序”文件夹再试）"
        }
    }
}
