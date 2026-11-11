import Foundation

var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures += 1
        fputs("FAIL \(message)\n", stderr)
    }
}

func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

func day(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0,
    calendar: Calendar
) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    parts.minute = minute
    parts.second = second
    guard let date = calendar.date(from: parts) else {
        fputs("FAIL could not build date \(year)-\(month)-\(day)\n", stderr)
        exit(1)
    }
    return date
}

let calendar = utcCalendar()

check(YearBonus.sanitizedMonths(1.5) == 1.5, "keep fraction")
check(YearBonus.sanitizedMonths(0) == 0, "zero stays zero")
check(YearBonus.sanitizedMonths(-2) == 0, "negative months")
check(YearBonus.sanitizedMonths(.nan) == 0, "nan months")
check(YearBonus.sanitizedMonths(.infinity) == 0, "infinite months")
check(YearBonus.sanitizedMonths(-.infinity) == 0, "negative infinite months")

check(YearBonus.targetAmount(monthlySalary: 10_000, bonusMonths: 1.5) == 15_000, "one and a half months")
check(YearBonus.targetAmount(monthlySalary: 20_000, bonusMonths: 2.5) == 50_000, "two and a half months")
check(YearBonus.targetAmount(monthlySalary: 10_000, bonusMonths: 0) == 0, "unconfigured target")
check(YearBonus.targetAmount(monthlySalary: 10_000, bonusMonths: -3) == 0, "negative months target")
check(YearBonus.targetAmount(monthlySalary: -5, bonusMonths: 2) == 0, "negative salary")
check(YearBonus.targetAmount(monthlySalary: .infinity, bonusMonths: 2) == 0, "infinite salary")
check(YearBonus.targetAmount(monthlySalary: 10_000, bonusMonths: .nan) == 0, "nan months target")

check(YearBonus.clampedProgress(elapsed: -1, total: 10) == 0, "clamp below zero")
check(YearBonus.clampedProgress(elapsed: 11, total: 10) == 1, "clamp above one")
check(YearBonus.clampedProgress(elapsed: 4, total: 8) == 0.5, "half progress")
check(YearBonus.clampedProgress(elapsed: .nan, total: 10) == 0, "nan elapsed")
check(YearBonus.clampedProgress(elapsed: 1, total: 0) == 0, "zero year length")
check(YearBonus.clampedProgress(elapsed: 1, total: .infinity) == 0, "infinite year length")

func yearSeconds(_ year: Int) -> TimeInterval {
    let start = day(year, 1, 1, calendar: calendar)
    let next = day(year + 1, 1, 1, calendar: calendar)
    return next.timeIntervalSince(start)
}

check(yearSeconds(2024) == 366 * 86_400, "2024 is a leap year")
check(yearSeconds(2025) == 365 * 86_400, "2025 is a common year")
check(yearSeconds(1900) == 365 * 86_400, "1900 is not a leap year")
check(yearSeconds(2000) == 366 * 86_400, "2000 is a leap year")

check(YearBonus.progress(at: day(2024, 1, 1, calendar: calendar), calendar: calendar) == 0, "leap year starts at 0")
check(YearBonus.progress(at: day(2025, 1, 1, calendar: calendar), calendar: calendar) == 0, "new year resets to 0")

let almostNextYear = day(2025, 1, 1, calendar: calendar).addingTimeInterval(-1)
let almostProgress = YearBonus.progress(at: almostNextYear, calendar: calendar)
check(almostProgress > 0.999 && almostProgress < 1, "last second of 2024 is almost full, got \(almostProgress)")
check(YearBonus.progress(at: day(2025, 1, 1, calendar: calendar), calendar: calendar) == 0, "the next instant belongs to the new year")

let leapMid = day(2024, 1, 1, calendar: calendar).addingTimeInterval(yearSeconds(2024) / 2)
let commonMid = day(2025, 1, 1, calendar: calendar).addingTimeInterval(yearSeconds(2025) / 2)
check(YearBonus.progress(at: leapMid, calendar: calendar) == 0.5, "leap-year midpoint")
check(YearBonus.progress(at: commonMid, calendar: calendar) == 0.5, "common-year midpoint")
check(leapMid != commonMid, "the two midpoints are not the same instant")

let leapDayProgress = YearBonus.progress(at: day(2024, 2, 29, hour: 12, calendar: calendar), calendar: calendar)
check(leapDayProgress > 0 && leapDayProgress < 1, "29 February stays inside 2024")

let leapEstimate = YearBonus.estimate(monthlySalary: 20_000, bonusMonths: 2.5, at: leapMid, calendar: calendar)
check(leapEstimate.configured, "positive months are configured")
check(leapEstimate.target == 50_000, "estimate uses salary times months")
check(abs(leapEstimate.accumulated - 25_000) < 0.001, "accumulated is target times progress, got \(leapEstimate.accumulated)")

let unconfigured = YearBonus.estimate(monthlySalary: 20_000, bonusMonths: 0, at: leapMid, calendar: calendar)
check(!unconfigured.configured, "zero months is not configured")
check(unconfigured.target == 0 && unconfigured.accumulated == 0, "unconfigured estimate is zero")

let atStart = YearBonus.estimate(monthlySalary: 8_000, bonusMonths: 1, at: day(2024, 1, 1, calendar: calendar), calendar: calendar)
check(atStart.accumulated == 0, "nothing has accumulated at midnight on 1 January")
check(atStart.target == 8_000, "the target is still the full bonus at the start of the year")

var edited = SalarySettings()
edited.bonusMonths = -4
check(edited.bonusMonths == 0, "assignment rejects a negative month count")
edited.bonusMonths = .nan
check(edited.bonusMonths == 0, "assignment rejects a non-finite month count")
edited.bonusMonths = 1.25
check(edited.bonusMonths == 1.25, "assignment keeps a fraction")

do {
    let oldJSON = #"{"monthlySalary":8000,"currencySymbol":"$","decimals":0}"#
    let old = try JSONDecoder().decode(SalarySettings.self, from: Data(oldJSON.utf8))
    check(old.monthlySalary == 8_000, "old salary is kept")
    check(old.currencySymbol == "$", "old currency symbol is kept")
    check(old.decimals == 0, "old decimal preference is kept")
    check(old.bonusMonths == 0, "old settings without bonus months default to 0")
    check(old.workDaysPerMonth == 21.75, "unrelated defaults stay in place")

    let negativeJSON = #"{"monthlySalary":9000,"bonusMonths":-4}"#
    let negative = try JSONDecoder().decode(SalarySettings.self, from: Data(negativeJSON.utf8))
    check(negative.monthlySalary == 9_000, "salary survives an invalid bonus value")
    check(negative.bonusMonths == 0, "a stored negative month count becomes 0")

    let textJSON = #"{"monthlySalary":7000,"bonusMonths":"nope"}"#
    let mismatched = try JSONDecoder().decode(SalarySettings.self, from: Data(textJSON.utf8))
    check(mismatched.monthlySalary == 7_000, "a mistyped bonus field does not drop the salary")
    check(mismatched.bonusMonths == 0, "a mistyped bonus field becomes 0")

    var saved = SalarySettings()
    saved.monthlySalary = 12_345
    saved.bonusMonths = 1.25
    saved.currencySymbol = "€"
    saved.decimals = 3
    let loaded = try JSONDecoder().decode(SalarySettings.self, from: JSONEncoder().encode(saved))
    check(loaded.bonusMonths == 1.25, "a fractional month count round-trips")
    check(loaded.monthlySalary == 12_345, "salary round-trips with the bonus")
    check(loaded.currencySymbol == "€", "currency symbol round-trips with the bonus")
    check(loaded.decimals == 3, "decimal preference round-trips with the bonus")
} catch {
    check(false, "settings codec threw \(error)")
}

var plainSettings = SalarySettings()
plainSettings.monthlySalary = 10_000
plainSettings.bonusMonths = 0
var bonusSettings = plainSettings
bonusSettings.bonusMonths = 3
var plain = SalaryCalculator(settings: plainSettings)
plain.calendar = calendar
var bonus = SalaryCalculator(settings: bonusSettings)
bonus.calendar = calendar
let duringWork = day(2024, 6, 12, hour: 15, calendar: calendar)
let withoutBonus = plain.snapshot(at: duringWork)
let withBonus = bonus.snapshot(at: duringWork)
check(withoutBonus.todayEarned == withBonus.todayEarned, "today's earnings ignore the bonus")
check(withoutBonus.monthEarned == withBonus.monthEarned, "this month's earnings ignore the bonus")
check(withoutBonus.dailySalary == withBonus.dailySalary, "daily rate ignores the bonus")
check(withoutBonus.hourly == withBonus.hourly, "hourly rate ignores the bonus")
check(withoutBonus.perSecond == withBonus.perSecond, "per-second rate ignores the bonus")
check(withoutBonus.progress == withBonus.progress, "workday progress ignores the bonus")
check(withoutBonus.perSecond > 0, "the existing rate is still calculated")

if failures == 0 {
    print("year bonus checks passed")
} else {
    fputs("\(failures) failed\n", stderr)
    exit(1)
}
