import AppKit

@main
struct DesktopPetChecks {
    @MainActor
    static func main() {
        checkDailyProgressAndAnimation()

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        checkClickAndDrag()
        let defaults = UserDefaults.standard
        let keys = ["desktopPetShown", "NSWindow Frame SalaryCounterDesktopPet"]
        let saved = keys.map { defaults.object(forKey: $0) }
        let controller = DesktopPetController.shared

        defer {
            controller.hide()
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        controller.show()
        guard let panel = app.windows.first(where: { $0.title == "小猪桌宠" && $0.isVisible }) else {
            fatalError("Desktop pet did not open")
        }
        precondition(!panel.isOpaque && panel.backgroundColor == .clear)
        precondition(panel.level == .floating && panel.isMovableByWindowBackground)
        precondition(panel.frame.size == NSSize(width: 108, height: 112))
        precondition(SettingsStore.shared.desktopPetShown)
        precondition(defaults.bool(forKey: "desktopPetShown"))
        if NSScreen.screens.isEmpty {
            print("screen placement check skipped: no display available")
        } else {
            precondition(NSScreen.screens.contains { $0.visibleFrame.contains(panel.frame) })
        }

        controller.show()
        precondition(app.windows.filter { $0.title == "小猪桌宠" && $0.isVisible }.count == 1)

        controller.toggle()
        precondition(!panel.isVisible && !SettingsStore.shared.desktopPetShown)
        precondition(!defaults.bool(forKey: "desktopPetShown"))

        controller.toggle()
        precondition(app.windows.contains { $0.title == "小猪桌宠" && $0.isVisible })
        precondition(SettingsStore.shared.desktopPetShown)
        print("desktop pet checks passed")
    }

    @MainActor
    static func checkClickAndDrag() {
        let view = DesktopPetInteractionView()
        var touches = 0
        view.onPet = { touches += 1 }

        func event(_ type: NSEvent.EventType, x: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(
                with: type, location: NSPoint(x: x, y: 10), modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1
            )!
        }

        view.mouseDown(with: event(.leftMouseDown, x: 10))
        view.mouseUp(with: event(.leftMouseUp, x: 10))
        precondition(touches == 1)

        view.mouseDown(with: event(.leftMouseDown, x: 10))
        view.mouseDragged(with: event(.leftMouseDragged, x: 11))
        view.mouseUp(with: event(.leftMouseUp, x: 11))
        precondition(touches == 2)

        view.mouseDown(with: event(.leftMouseDown, x: 10))
        view.mouseDragged(with: event(.leftMouseDragged, x: 20))
        view.mouseUp(with: event(.leftMouseUp, x: 20))
        precondition(touches == 2)
        precondition(view.menu(for: event(.rightMouseDown, x: 10))?.items.first?.title == "收起小猪桌宠")
    }

    static func checkDailyProgressAndAnimation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 12))!
        var settings = SalarySettings()
        settings.lunchEnabled = false
        settings.startMinutes = 9 * 60
        settings.endMinutes = 17 * 60
        let daily = SalaryCalculator(settings: settings, calendar: calendar).snapshot(at: noon)
        precondition(daily.progress == 3.0 / 8)

        settings.bonusMonths = 12
        let withBonus = SalaryCalculator(settings: settings, calendar: calendar).snapshot(at: noon)
        precondition(withBonus.progress == daily.progress && withBonus.todayEarned == daily.todayEarned)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: noon))!
        precondition(SalaryCalculator(settings: settings, calendar: calendar).snapshot(at: tomorrow).progress == 0)

        let touch = Date(timeIntervalSinceReferenceDate: 100)
        let now = touch.addingTimeInterval(0.25)
        let happy = DesktopPetPose(date: now, touchedAt: touch, status: .working, reduceMotion: false)
        precondition(happy.lift > 0 && happy.heartOpacity > 0)
        let settled = DesktopPetPose(date: touch.addingTimeInterval(2), touchedAt: touch, status: .working, reduceMotion: false)
        precondition(settled.lift == 0 && settled.heartOpacity == 0)
        let resting = DesktopPetPose(date: now, touchedAt: nil, status: .lunch, reduceMotion: false)
        precondition(resting.eyesClosed && resting.sway == 0)
        let quiet = DesktopPetPose(date: now, touchedAt: touch, status: .working, reduceMotion: true)
        precondition(quiet.lift == 0 && quiet.breath == 0 && quiet.sway == 0 && quiet.heartRise == 0)
        precondition(quiet.heartOpacity > 0)
        let quietSettled = DesktopPetPose(date: touch.addingTimeInterval(2), touchedAt: touch, status: .working, reduceMotion: true)
        precondition(quietSettled.heartOpacity == 0)
    }
}
