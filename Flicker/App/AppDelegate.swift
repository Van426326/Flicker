//
//  AppDelegate.swift
//  Flicker
//
//  管理 URL 启动检测、窗口复用策略，并按用户设置应用
//  程序坞 / 菜单栏 / 开机自启动。
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 是否因处理自定义 URL 而被拉起（扩展触发"打开方式"）。
    /// 仅在主线程读写。
    nonisolated(unsafe) static var launchedByURL = false
    nonisolated(unsafe) static var launchedByOpenURL = false

    /// 主窗口引用；关闭时不销毁，便于从菜单栏重新打开。
    private var mainWindow: NSWindow?
    private var pendingRoute: URLOpener.Route?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // 通过 URL 启动时，系统会带上 kAEGetURL Apple Event，direct object 即 URL 字符串。
        let event = NSAppleEventManager.shared().currentAppleEvent
        if let event,
           let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
           let parsedURL = URL(string: url),
           let route = URLOpener.route(for: parsedURL) {
            Self.launchedByURL = true
            Self.launchedByOpenURL = {
                if case .open = route { return true }
                return false
            }()
            pendingRoute = route
        }
        if Self.launchedByOpenURL {
            // 扩展拉起时保持静默：不抢焦点、不显窗口。
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 捕获主窗口引用，关闭时不销毁，便于从菜单栏重新打开。
        if let window = NSApp.windows.first {
            window.isReleasedWhenClosed = false
            mainWindow = window
        }

        if Self.launchedByOpenURL {
            // 静默运行：隐藏窗口，不应用界面设置，仅同步登录项。
            NSApp.windows.forEach { $0.orderOut(nil) }
            AppSettings.shared.applyLoginItem()
        } else {
            AppSettings.shared.applyAll()
        }
        if let pendingRoute {
            handle(route: pendingRoute)
            self.pendingRoute = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 用户再次打开已运行的应用（如从 Dock / Finder 点击）：显示主窗口并应用界面设置。
        showMainWindow()
        AppSettings.shared.applyAll()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 有菜单栏图标时保留进程（可随时重新打开窗口）；否则关闭即退出。
        return !AppSettings.shared.showMenuBarIcon
    }

    @objc func showMainWindow() {
        let window = mainWindow ?? NSApp.windows.first
        AppSettings.shared.applyAll()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              let route = URLOpener.route(for: url) else { return }
        handle(route: route)
    }

    private func handle(route: URLOpener.Route) {
        switch route {
        case let .open(target, app):
            URLOpener.open(target: target, with: app)
        case .showMainWindow:
            showMainWindow()
        }
    }
}
