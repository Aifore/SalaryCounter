import SwiftUI
import AppKit

@main
struct SalaryCounterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = SettingsStore.shared
    @StateObject private var ticker = Ticker.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
                .environmentObject(ticker)
        } label: {
            // 菜单栏上只显示一个不断上涨的数字
            Text(menuBarText)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarText: String {
        let s = store.settings
        let snap = SalaryCalculator(settings: s).snapshot(at: ticker.now)
        let value = s.menuBarMode == .today ? snap.todayEarned : snap.monthEarned
        return Fmt.money(value, symbol: s.currencySymbol, decimals: s.decimals)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 用 `swift run` 直接跑（没有 Info.plist）时也不出现在 Dock
        NSApp.setActivationPolicy(.accessory)
        if SettingsStore.shared.desktopShown {
            DesktopWindowController.shared.show()
        }
    }
}
