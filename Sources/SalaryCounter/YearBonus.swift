import Foundation

struct YearBonusEstimate: Equatable {
    var configured: Bool
    var progress: Double
    var target: Double
    /// 预估已存 = 目标 × 今年进度。未设置时为 0，不计入工资。
    var accumulated: Double
}

enum YearBonus {
    static func sanitizedMonths(_ value: Double) -> Double {
        guard value.isFinite, value >= 0 else { return 0 }
        return value
    }

    static func targetAmount(monthlySalary: Double, bonusMonths: Double) -> Double {
        let months = sanitizedMonths(bonusMonths)
        guard months > 0, monthlySalary.isFinite, monthlySalary >= 0 else { return 0 }
        let value = monthlySalary * months
        guard value.isFinite else { return 0 }
        return value
    }

    static func clampedProgress(elapsed: Double, total: Double) -> Double {
        guard elapsed.isFinite, total.isFinite, total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    /// 本地日历年已经过的比例，从当年 1 月 1 日 0 点到下一年 1 月 1 日 0 点。闰年和夏令时按日历的真实间隔计算。
    static func progress(at date: Date, calendar: Calendar = .current) -> Double {
        let year = calendar.component(.year, from: date)
        var startParts = DateComponents()
        startParts.year = year
        startParts.month = 1
        startParts.day = 1
        startParts.hour = 0
        startParts.minute = 0
        startParts.second = 0
        var nextParts = startParts
        nextParts.year = year + 1
        guard let start = calendar.date(from: startParts),
              let next = calendar.date(from: nextParts) else {
            return 0
        }
        return clampedProgress(elapsed: date.timeIntervalSince(start), total: next.timeIntervalSince(start))
    }

    static func estimate(
        monthlySalary: Double,
        bonusMonths: Double,
        at date: Date,
        calendar: Calendar = .current
    ) -> YearBonusEstimate {
        let months = sanitizedMonths(bonusMonths)
        let target = targetAmount(monthlySalary: monthlySalary, bonusMonths: months)
        let yearProgress = progress(at: date, calendar: calendar)
        let accumulated = target * yearProgress
        return YearBonusEstimate(
            configured: months > 0,
            progress: yearProgress,
            target: target,
            accumulated: accumulated.isFinite ? accumulated : 0
        )
    }
}
