import AppKit

@main
struct DesktopPetChecks {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
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
}
