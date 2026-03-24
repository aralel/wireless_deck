//
//  router_monitorApp.swift
//  router monitor
//
//  Created by maysam torabi on 22.03.2026.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class WirelessDeckAppModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let wifiScanner: WiFiScannerController
    let bluetoothScanner: BluetoothScannerController
    let telemetry: WirelessTelemetryStore
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let wifiScanner = WiFiScannerController()
        let bluetoothScanner = BluetoothScannerController()
        let telemetry = WirelessTelemetryStore()

        self.wifiScanner = wifiScanner
        self.bluetoothScanner = bluetoothScanner
        self.telemetry = telemetry

        wifiScanner.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        bluetoothScanner.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        telemetry.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        wifiScanner.onScanCompleted = { [weak self] networks, capturedAt in
            self?.telemetry.recordWiFiScan(networks, at: capturedAt)
        }

        bluetoothScanner.onSweepCompleted = { [weak self] devices, capturedAt in
            self?.telemetry.recordBluetoothSweep(devices, at: capturedAt)
        }

        telemetry.bootstrap(
            wifiNetworks: wifiScanner.networks,
            bluetoothDevices: bluetoothScanner.devices
        )

        wifiScanner.prepare()
        bluetoothScanner.prepare()
    }

    var totalAlertCount: Int {
        telemetry.wifiAlerts.count + telemetry.bluetoothAlerts.count
    }

    var menuBarSymbolName: String {
        if wifiScanner.isScanning {
            return "wifi.circle.fill"
        }

        if let currentNetwork = wifiScanner.networks.first(where: \.isCurrentNetwork) {
            switch currentNetwork.signalBars {
            case 4:
                return "wifi"
            case 3:
                return "wifi"
            case 2:
                return "wifi"
            default:
                return "wifi.exclamationmark"
            }
        }

        return "wifi.square"
    }

    var menuBarLabel: String {
        if let currentNetwork = wifiScanner.networks.first(where: \.isCurrentNetwork) {
            return "\(currentNetwork.signalPercent)%"
        }

        if wifiScanner.isScanning {
            return "Scan"
        }

        return "Deck"
    }

    var currentNetworkSummary: String {
        if let currentNetwork = wifiScanner.networks.first(where: \.isCurrentNetwork) {
            return "\(currentNetwork.ssid) • \(currentNetwork.signalDescription) • \(currentNetwork.signalStrength) dBm"
        }

        if let strongestNetwork = wifiScanner.networks.max(by: { $0.signalStrength < $1.signalStrength }) {
            return "Nearest: \(strongestNetwork.ssid) • \(strongestNetwork.signalDescription)"
        }

        return wifiScanner.statusLine
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }
}

@main
struct router_monitorApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: RouterMonitorAppDelegate
    @StateObject private var appModel = WirelessDeckAppModel()

    init() {
        AppLog.info("app", "router monitor launched")
        AppRuntimeDiagnostics.logLaunchDetails()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: appModel)
        }

        MenuBarExtra {
            MenuBarDeckView(model: appModel)
        } label: {
            Label(appModel.menuBarLabel, systemImage: appModel.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarDeckView: View {
    @ObservedObject var model: WirelessDeckAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Wireless Deck")
                    .font(.headline)

                Text(model.currentNetworkSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                quickMetric(title: "Wi-Fi", value: "\(model.wifiScanner.networks.count)")
                quickMetric(title: "Bluetooth", value: "\(model.bluetoothScanner.devices.count)")
                quickMetric(title: "Alerts", value: "\(model.totalAlertCount)")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(model.telemetry.wifiHealth.headline)
                    .font(.subheadline.weight(.semibold))

                Text(model.telemetry.wifiHealth.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Button("Open Deck") {
                    model.openMainWindow()
                }
                .buttonStyle(.borderedProminent)

                Button("Scan Wi-Fi") {
                    model.wifiScanner.refresh()
                }
                .buttonStyle(.bordered)

                Button(model.bluetoothScanner.isScanning ? "Stop BLE" : "Sweep BLE") {
                    if model.bluetoothScanner.isScanning {
                        model.bluetoothScanner.stop()
                    } else {
                        model.bluetoothScanner.refresh()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func quickMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
