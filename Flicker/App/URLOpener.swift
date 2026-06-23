//
//  URLOpener.swift
//  Flicker
//
//  Handles custom URL scheme `flicker://` invoked by the Finder extension.
//
//  背景：Finder Sync 扩展运行在沙箱内，直接调用
//  `NSWorkspace.shared.open([target], withApplicationAt:)` 会被系统拦截，
//  报“应用程序 Flicker 没有权限打开 xxx”。因此扩展改为通过 URL scheme
//  把目标文件与应用路径交给非沙箱的容器 App，由容器 App 真正执行打开。
//

import AppKit

enum URLOpener {
    static let scheme = "flicker"

    /// 处理 `flicker://open?target=<路径>&app=<路径>`。
    static func handle(_ url: URL) {
        guard url.scheme?.lowercased() == scheme else { return }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.host?.lowercased() == "open" else { return }

        let targetPath = comps.queryItems?.first(where: { $0.name == "target" })?.value?
            .removingPercentEncoding
        let appPath = comps.queryItems?.first(where: { $0.name == "app" })?.value?
            .removingPercentEncoding
        guard let targetPath, let appPath else { return }

        let targetURL = URL(fileURLWithPath: targetPath)
        let appURL = URL(fileURLWithPath: appPath)

        // 容器 App 非沙盒，可自由用任意应用打开任意文件。
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // 不要激活目标应用的窗口
        NSWorkspace.shared.open([targetURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                NSLog("[Flicker] open via container failed: \(error.localizedDescription)")
            }
        }

        // 扩展通过 NSWorkspace.open(url) 投递自定义 URL 时，系统已将容器 App 激活到前台。
        // 此处主动把自己隐藏/退到后台，避免主窗口抢占焦点。
        if AppDelegate.launchedByURL {
            // 冷启动场景：保持 accessory 策略，隐藏残留窗口。
            NSApp.windows.forEach { $0.orderOut(nil) }
        } else {
            // 已在运行的场景：隐藏整个应用，让用户继续留在 Finder。
            NSApp.hide(nil)
        }
    }
}
