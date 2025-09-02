//
//  DanmakuApp.swift
//  Danmaku
//
//  Created by maa on 2025/09/02.
//

import SwiftUI
import AppKit

@main
struct DanmakuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
