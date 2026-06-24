//
//  SettingsView.swift
//  Flicker
//
//  设置页：菜单栏图标、程序坞、开机自启动。
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("界面") {
                Toggle("在系统菜单栏显示图标", isOn: $settings.showMenuBarIcon)
                    .help("关闭后将从菜单栏移除 Flicker 图标")
                Toggle("在程序坞中显示", isOn: $settings.showInDock)
                    .help("关闭后应用将作为菜单栏/后台应用运行")
            }
            Section("启动") {
                Toggle("开机时自动启动", isOn: $settings.launchAtLogin)
                    .help("登录 macOS 时自动运行 Flicker")
            }
            Section("右键菜单") {
                Toggle("复制绝对路径", isOn: $settings.showCopyAbsolutePath)
                    .help("在右键菜单中显示「复制绝对路径」")
                Toggle("复制相对路径", isOn: $settings.showCopyRelativePath)
                    .help("在右键菜单中显示「复制相对路径」")
                Toggle("复制文件名", isOn: $settings.showCopyFileName)
                    .help("在右键菜单中显示「复制文件名」")
            }
            Section("新建文件") {
                ForEach(NewFileType.defaults) { fileType in
                    Toggle(fileType.name + " (." + fileType.ext + ")", isOn: Binding(
                        get: { settings.newFileEnabledTypes.contains(fileType.id) },
                        set: { enabled in
                            if enabled {
                                if !settings.newFileEnabledTypes.contains(fileType.id) {
                                    settings.newFileEnabledTypes.append(fileType.id)
                                }
                            } else {
                                settings.newFileEnabledTypes.removeAll { $0 == fileType.id }
                            }
                        }
                    ))
                    .help("在右键菜单中显示新建「\(fileType.name)」选项")
                }
                Toggle("创建后自动打开", isOn: $settings.newFileAutoOpen)
                    .help("新建文件后自动用默认应用打开")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .frame(width: 400, height: 480)
    }
}
