import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - 设置

enum MenuBarMode: String, Codable, CaseIterable, Hashable {
    case today   // 今日已赚
    case month   // 本月已赚

    var title: String {
        switch self {
        case .today: return "今日已赚"
        case .month: return "本月已赚"
        }
    }
}

struct SalarySettings: Codable, Equatable {
    /// 月薪
    var monthlySalary: Double = 10000
    /// 每月计薪天数（国内常用 21.75）
    var workDaysPerMonth: Double = 21.75
    /// 上下班时间，单位：从 0 点起的分钟数
    var startMinutes: Int = 9 * 60
    var endMinutes: Int = 18 * 60
    /// 午休（不计薪）
    var lunchEnabled: Bool = true
    var lunchStartMinutes: Int = 12 * 60
    var lunchEndMinutes: Int = 13 * 60
    /// 工作日，使用 Calendar 的 weekday：1=周日, 2=周一 … 7=周六
    var workWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    /// 显示
    var currencySymbol: String = "¥"
    var decimals: Int = 2
    var menuBarMode: MenuBarMode = .today
    /// 桌面窗口是否置顶
    var desktopAlwaysOnTop: Bool = true
    /// 年终奖按月薪折算的月数。0 表示未设置，可以是小数。
    var bonusMonths: Double = 0 {
        didSet {
            let clean = YearBonus.sanitizedMonths(bonusMonths)
            if clean != bonusMonths {
                bonusMonths = clean
            }
        }
    }

    init() {}

    // 逐字段解码：以后新增字段时，旧配置也能读出来
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        monthlySalary = try c.decodeIfPresent(Double.self, forKey: .monthlySalary) ?? monthlySalary
        workDaysPerMonth = try c.decodeIfPresent(Double.self, forKey: .workDaysPerMonth) ?? workDaysPerMonth
        startMinutes = try c.decodeIfPresent(Int.self, forKey: .startMinutes) ?? startMinutes
        endMinutes = try c.decodeIfPresent(Int.self, forKey: .endMinutes) ?? endMinutes
        lunchEnabled = try c.decodeIfPresent(Bool.self, forKey: .lunchEnabled) ?? lunchEnabled
        lunchStartMinutes = try c.decodeIfPresent(Int.self, forKey: .lunchStartMinutes) ?? lunchStartMinutes
        lunchEndMinutes = try c.decodeIfPresent(Int.self, forKey: .lunchEndMinutes) ?? lunchEndMinutes
        workWeekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .workWeekdays) ?? workWeekdays
        currencySymbol = try c.decodeIfPresent(String.self, forKey: .currencySymbol) ?? currencySymbol
        decimals = try c.decodeIfPresent(Int.self, forKey: .decimals) ?? decimals
        menuBarMode = try c.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode) ?? menuBarMode
        desktopAlwaysOnTop = try c.decodeIfPresent(Bool.self, forKey: .desktopAlwaysOnTop) ?? desktopAlwaysOnTop
        // 旧配置没有这个字段；类型不对时也不要让整份设置读失败
        let decodedMonths = try? c.decodeIfPresent(Double.self, forKey: .bonusMonths)
        if let raw = decodedMonths ?? nil {
            bonusMonths = YearBonus.sanitizedMonths(raw)
        } else {
            bonusMonths = 0
        }
    }
}

// MARK: - 设置存储（UserDefaults）

#if canImport(Combine)
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let settingsKey = "salarySettings.v1"
    private let desktopKey = "desktopWindowShown"
    private let desktopPetKey = "desktopPetShown"

    @Published var settings: SalarySettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: settingsKey)
            }
        }
    }

    /// 桌面窗口是否打开（下次启动时恢复）
    @Published var desktopShown: Bool {
        didSet { UserDefaults.standard.set(desktopShown, forKey: desktopKey) }
    }

    @Published var desktopPetShown: Bool {
        didSet { UserDefaults.standard.set(desktopPetShown, forKey: desktopPetKey) }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let s = try? JSONDecoder().decode(SalarySettings.self, from: data) {
            settings = s
        } else {
            settings = SalarySettings()
        }
        desktopShown = UserDefaults.standard.bool(forKey: desktopKey)
        desktopPetShown = UserDefaults.standard.bool(forKey: desktopPetKey)
    }
}

// MARK: - 时钟

/// 每 0.1 秒发布一次当前时间，驱动数字上涨
final class Ticker: ObservableObject {
    static let shared = Ticker()

    @Published private(set) var now = Date()
    private var timer: Timer?

    private init() {
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        t.tolerance = 0.02
        // .common：菜单展开、拖动窗口时也继续走
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
#endif

// MARK: - 计算

enum WorkStatus {
    case invalid, restDay, beforeWork, working, lunch, offWork

    var title: String {
        switch self {
        case .invalid: return "请检查设置"
        case .restDay: return "休息日"
        case .beforeWork: return "还没上班"
        case .working: return "搬砖中"
        case .lunch: return "午休中"
        case .offWork: return "已下班"
        }
    }

    var symbol: String {
        switch self {
        case .invalid: return "exclamationmark.triangle"
        case .restDay: return "cup.and.saucer"
        case .beforeWork: return "sunrise"
        case .working: return "hammer"
        case .lunch: return "fork.knife"
        case .offWork: return "moon.stars"
        }
    }
}

struct SalarySnapshot {
    var status: WorkStatus
    var todayEarned: Double
    var monthEarned: Double
    var dailySalary: Double
    var hourly: Double
    var perSecond: Double
    /// 今日工作进度 0...1
    var progress: Double
    /// 状态说明，如 “距下班 02:13:45”
    var hint: String
}

struct SalaryCalculator {
    let settings: SalarySettings
    var calendar = Calendar.current

    private var start: Double { Double(settings.startMinutes * 60) }
    private var end: Double { Double(settings.endMinutes * 60) }
    private var lunchStart: Double { Double(settings.lunchStartMinutes * 60) }
    private var lunchEnd: Double { Double(settings.lunchEndMinutes * 60) }

    private func overlap(_ a1: Double, _ a2: Double, _ b1: Double, _ b2: Double) -> Double {
        max(0, min(a2, b2) - max(a1, b1))
    }

    /// 一天中实际计薪的秒数（扣除午休）
    var totalWorkSeconds: Double {
        guard end > start else { return 0 }
        var total = end - start
        if settings.lunchEnabled, lunchEnd > lunchStart {
            total -= overlap(start, end, lunchStart, lunchEnd)
        }
        return max(0, total)
    }

    var dailySalary: Double {
        settings.workDaysPerMonth > 0 ? settings.monthlySalary / settings.workDaysPerMonth : 0
    }

    func isWorkday(_ date: Date) -> Bool {
        settings.workWeekdays.contains(calendar.component(.weekday, from: date))
    }

    /// 到当天第 t 秒为止已工作的秒数
    func workedSeconds(atSecondOfDay t: Double) -> Double {
        guard end > start else { return 0 }
        let clamped = min(max(t, start), end)
        var worked = clamped - start
        if settings.lunchEnabled, lunchEnd > lunchStart {
            worked -= overlap(start, clamped, lunchStart, lunchEnd)
        }
        return max(0, worked)
    }

    func snapshot(at now: Date) -> SalarySnapshot {
        let dayStart = calendar.startOfDay(for: now)
        let t = now.timeIntervalSince(dayStart)
        let total = totalWorkSeconds
        let daily = dailySalary
        let perSecond = total > 0 ? daily / total : 0
        let workday = isWorkday(now)

        let worked = workday ? workedSeconds(atSecondOfDay: t) : 0
        let today = worked * perSecond
        let progress = total > 0 ? worked / total : 0

        // 本月：今天之前的工作日按整天计 + 今天的部分
        var month = today
        if let monthStart = calendar.dateInterval(of: .month, for: now)?.start {
            var d = monthStart
            while d < dayStart {
                if isWorkday(d) { month += daily }
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
        }

        let status: WorkStatus
        let hint: String
        if total <= 0 || settings.workDaysPerMonth <= 0 {
            status = .invalid
            hint = "下班时间需晚于上班时间"
        } else if !workday {
            status = .restDay
            hint = "好好休息"
        } else if t < start {
            status = .beforeWork
            hint = "距上班 " + Fmt.duration(start - t)
        } else if t >= end {
            status = .offWork
            hint = "今日工资已到账"
        } else if settings.lunchEnabled, t >= lunchStart, t < lunchEnd {
            status = .lunch
            hint = "距下班 " + Fmt.duration(end - t)
        } else {
            status = .working
            hint = "距下班 " + Fmt.duration(end - t)
        }

        return SalarySnapshot(
            status: status,
            todayEarned: today,
            monthEarned: month,
            dailySalary: daily,
            hourly: perSecond * 3600,
            perSecond: perSecond,
            progress: min(max(progress, 0), 1),
            hint: hint
        )
    }
}

// MARK: - 格式化

enum Fmt {
    private static var cache: [Int: NumberFormatter] = [:]

    static func money(_ value: Double, symbol: String, decimals: Int) -> String {
        let d = min(max(decimals, 0), 6)
        let f: NumberFormatter
        if let cached = cache[d] {
            f = cached
        } else {
            f = NumberFormatter()
            f.numberStyle = .decimal
            f.usesGroupingSeparator = true
            f.minimumFractionDigits = d
            f.maximumFractionDigits = d
            f.roundingMode = .down // 只显示真正“赚到”的部分
            cache[d] = f
        }
        return symbol + (f.string(from: NSNumber(value: value)) ?? "0")
    }

    static func duration(_ seconds: Double) -> String {
        let s = Int(max(0, seconds).rounded(.up))
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}

// MARK: - 视图局部状态

#if canImport(Combine)
/// 代替 @State 的小盒子。新 SDK 中 @State 是宏，
/// 只装 Command Line Tools（没有完整 Xcode）时宏插件缺失会编译失败。
final class UIBox<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}
#endif
