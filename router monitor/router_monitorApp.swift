//
//  router_monitorApp.swift
//  router monitor
//
//  Created by maysam torabi on 22.03.2026.
//

import AppKit
import SwiftUI

@main
struct router_monitorApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: RouterMonitorAppDelegate

    init() {
        AppLog.info("app", "router monitor launched")
        AppRuntimeDiagnostics.logLaunchDetails()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class RouterMonitorAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationIcon()
    }

    private func configureApplicationIcon() {
        let namedImage = NSImage(named: NSImage.Name("AppIcon"))
        let resourceImage = Bundle.main.image(forResource: NSImage.Name("AppIcon"))
        let icnsImage = Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))

        guard let iconImage = namedImage ?? resourceImage ?? icnsImage else {
            AppLog.warning("app", "Unable to load AppIcon from the main bundle for Dock icon")
            return
        }

        NSApplication.shared.applicationIconImage = iconImage
        AppLog.info(
            "app",
            "Application icon configured for Dock from bundle resource size=\(Int(iconImage.size.width))x\(Int(iconImage.size.height))"
        )
    }
}
