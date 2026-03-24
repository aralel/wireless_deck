//
//  ContentView.swift
//  router monitor
//
//  Created by maysam torabi on 22.03.2026.
//

import AppKit
import SwiftUI

private enum RadarSurface: String, CaseIterable, Identifiable {
    case wifi
    case bluetooth

    var id: Self { self }

    var title: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .bluetooth:
            return "Bluetooth"
        }
    }

    var subtitle: String {
        switch self {
        case .wifi:
            return "Nearby access points, vendors, alerts, and channel drift"
        case .bluetooth:
            return "Nearby BLE devices, proximity, alerts, and live trends"
        }
    }

    var symbolName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .bluetooth:
            return "bolt.horizontal.circle"
        }
    }

    var tint: Color {
        switch self {
        case .wifi:
            return .blue
        case .bluetooth:
            return .teal
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: WirelessDeckAppModel
    @StateObject private var debugLogStore = DebugLogStore.shared

    @State private var selectedSurface: RadarSurface = .wifi
    @State private var isDebugConsoleVisible = false
    @State private var selectedPlaceID: SavedPlace.ID?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color.teal.opacity(0.10),
                    Color.orange.opacity(0.05),
                    Color.white.opacity(0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                workspaceDeck

                if isDebugConsoleVisible {
                    debugConsoleSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(24)
            .frame(minWidth: 1180, minHeight: 780, alignment: .topLeading)
        }
        .animation(.snappy(duration: 0.22), value: isDebugConsoleVisible)
        .animation(.snappy(duration: 0.26), value: selectedSurface)
        .task {
            AppLog.info("ui", "Wireless dashboard appeared")
            prepare(selectedSurface)
        }
        .onChange(of: selectedSurface) { _, surface in
            prepare(surface)
        }
        .onChange(of: model.telemetry.savedPlaces) { _, places in
            guard let selectedPlaceID else {
                return
            }

            if !places.contains(where: { $0.id == selectedPlaceID }) {
                self.selectedPlaceID = nil
            }
        }
    }

    private var workspaceDeck: some View {
        VStack(alignment: .leading, spacing: 16) {
            deckHeader

            selectedSurfaceView
                .id(selectedSurface)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var deckHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedSurface.tint.opacity(0.14))
                            .frame(width: 52, height: 52)

                        Image(systemName: selectedSurface.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(selectedSurface.tint)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Wireless Deck")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))

                        Text(selectedSurface.title)
                            .font(.headline)
                            .foregroundStyle(selectedSurface.tint)

                        Text(selectedSurfaceStatusLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 18)

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        primaryActionButton

                        Button {
                            isDebugConsoleVisible.toggle()
                            AppLog.info("ui", "Debug console \(isDebugConsoleVisible ? "shown" : "hidden") from deck header")
                        } label: {
                            Label(
                                isDebugConsoleVisible ? "Hide Logs" : "Show Logs",
                                systemImage: isDebugConsoleVisible ? "ladybug.slash" : "ladybug"
                            )
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        infoChip(
                            title: selectedSurfaceTimestampSummary,
                            symbol: "clock",
                            tint: selectedSurface.tint
                        )

                        infoChip(
                            title: "\(debugLogStore.entries.count) logs",
                            symbol: "text.page",
                            tint: .secondary
                        )
                    }
                }
            }

            surfaceSwitcher
            headerInsightRow
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var surfaceSwitcher: some View {
        HStack(spacing: 10) {
            ForEach(RadarSurface.allCases) { surface in
                compactSurfaceButton(for: surface)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactSurfaceButton(for surface: RadarSurface) -> some View {
        Button {
            guard selectedSurface != surface else {
                return
            }

            selectedSurface = surface
            AppLog.info("ui", "Switched wireless dashboard surface to \(surface.rawValue)")
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(surface.tint.opacity(selectedSurface == surface ? 0.18 : 0.08))
                        .frame(width: 30, height: 30)

                    Image(systemName: surface.symbolName)
                        .foregroundStyle(surface.tint)
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(surface.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(surfaceCountText(for: surface))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if selectedSurface == surface {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(surface.tint)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedSurface == surface ? surface.tint.opacity(0.12) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedSurface == surface ? surface.tint.opacity(0.38) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var headerInsightRow: some View {
        HStack(alignment: .top, spacing: 12) {
            healthInsightCard
            savedPlacesCard
            alertSummaryCard
        }
    }

    private var healthInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Wireless Health", systemImage: "cross.case")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedSurface.tint)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(selectedHealthReport.score)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(selectedHealthReport.tone.title)
                    .font(.headline)
                    .foregroundStyle(selectedSurface.tint)
            }

            Text(selectedHealthReport.headline)
                .font(.subheadline.weight(.semibold))

            Text(selectedHealthReport.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(selectedSurface.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var savedPlacesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Saved Places", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Save Current") {
                    saveCurrentPlace()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Picker("Compare against", selection: $selectedPlaceID) {
                Text("No baseline").tag(Optional<SavedPlace.ID>.none)

                ForEach(model.telemetry.savedPlaces) { place in
                    Text(place.name).tag(Optional(place.id))
                }
            }
            .pickerStyle(.menu)

            if let selectedPlace {
                Text(compareDigest.summaryLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(selectedPlace.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Delete") {
                        model.telemetry.deletePlace(selectedPlace)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text("Store a named baseline like Home, Office, or Lab, then compare the live environment against it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var alertSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Watched Signals", systemImage: "bell.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text("\(model.totalAlertCount)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(alertSummaryLine)
                .font(.subheadline.weight(.semibold))

            Text("Alerts fire when a watched SSID or Bluetooth device appears, disappears, or drops below your chosen threshold.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 250, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var selectedSurfaceView: some View {
        switch selectedSurface {
        case .wifi:
            WiFiRadarView(
                scanner: model.wifiScanner,
                telemetry: model.telemetry,
                selectedPlace: selectedPlace
            )
        case .bluetooth:
            BluetoothRadarView(
                scanner: model.bluetoothScanner,
                telemetry: model.telemetry,
                selectedPlace: selectedPlace
            )
        }
    }

    private func surfaceCountText(for surface: RadarSurface) -> String {
        switch surface {
        case .wifi:
            return "\(model.wifiScanner.networks.count) networks"
        case .bluetooth:
            return "\(model.bluetoothScanner.devices.count) devices"
        }
    }

    private var debugConsoleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Debug Console", systemImage: "ladybug.fill")
                    .font(.headline)

                Text("\(debugLogStore.entries.count) entries")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Hide") {
                    isDebugConsoleVisible = false
                    AppLog.info("ui", "Debug console hidden from console card")
                }
                .buttonStyle(.bordered)

                Button("Copy Logs") {
                    copyDebugLogs()
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    Task { @MainActor in
                        debugLogStore.clear()
                    }
                    AppLog.info("ui", "Debug console cleared")
                }
                .buttonStyle(.bordered)
            }

            Group {
                if debugLogStore.entries.isEmpty {
                    ContentUnavailableView(
                        "No Debug Logs Yet",
                        systemImage: "text.page",
                        description: Text("Permission changes, scan attempts, and errors will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(debugLogStore.entries) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .center, spacing: 10) {
                                        Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()

                                        Text(entry.level.rawValue)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(levelTint(for: entry.level).opacity(0.12), in: Capsule())
                                            .foregroundStyle(levelTint(for: entry.level))

                                        Text(entry.category)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(entry.message)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(18)
        .frame(height: 240)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var selectedSurfaceStatusLine: String {
        switch selectedSurface {
        case .wifi:
            return model.wifiScanner.statusLine
        case .bluetooth:
            return model.bluetoothScanner.statusLine
        }
    }

    private func prepare(_ surface: RadarSurface) {
        switch surface {
        case .wifi:
            model.wifiScanner.prepare()
        case .bluetooth:
            model.bluetoothScanner.prepare()
        }
    }

    private func infoChip(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: Capsule())
    }

    private var selectedSurfaceTimestampSummary: String {
        switch selectedSurface {
        case .wifi:
            if let lastScanDate = model.wifiScanner.lastScanDate {
                return "Last scan \(lastScanDate.formatted(date: .omitted, time: .standard))"
            }

            return "Ready when you are"
        case .bluetooth:
            if let lastScanDate = model.bluetoothScanner.lastScanDate {
                return "Last sweep \(lastScanDate.formatted(date: .omitted, time: .standard))"
            }

            return "Sweeps run for about 8 seconds"
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch selectedSurface {
        case .wifi:
            Button {
                model.wifiScanner.refresh()
            } label: {
                Label(model.wifiScanner.isScanning ? "Scanning..." : "Refresh Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.wifiScanner.isScanning)
        case .bluetooth:
            if model.bluetoothScanner.isScanning {
                Button {
                    model.bluetoothScanner.stop()
                } label: {
                    Label("Stop Sweep", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    model.bluetoothScanner.refresh()
                } label: {
                    Label("Start Sweep", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var selectedHealthReport: WirelessHealthReport {
        switch selectedSurface {
        case .wifi:
            return model.telemetry.wifiHealth
        case .bluetooth:
            return model.telemetry.bluetoothHealth
        }
    }

    private var selectedPlace: SavedPlace? {
        guard let selectedPlaceID else {
            return nil
        }

        return model.telemetry.savedPlaces.first(where: { $0.id == selectedPlaceID })
    }

    private var compareDigest: WirelessDiffDigest {
        switch selectedSurface {
        case .wifi:
            return model.telemetry.compareWiFi(current: model.wifiScanner.networks, to: selectedPlace)
        case .bluetooth:
            return model.telemetry.compareBluetooth(current: model.bluetoothScanner.devices, to: selectedPlace)
        }
    }

    private var alertSummaryLine: String {
        let wifiCount = model.telemetry.wifiAlerts.count
        let bluetoothCount = model.telemetry.bluetoothAlerts.count

        if model.totalAlertCount == 0 {
            return "No active watches yet"
        }

        return "\(wifiCount) Wi-Fi • \(bluetoothCount) Bluetooth"
    }

    private func copyDebugLogs() {
        let pasteboard = NSPasteboard.general

        Task { @MainActor in
            let logs = debugLogStore.combinedText
            pasteboard.clearContents()
            pasteboard.setString(logs, forType: .string)
            AppLog.info("ui", "Copied \(debugLogStore.entries.count) debug log entries to the pasteboard")
        }
    }

    private func levelTint(for level: DebugLogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func saveCurrentPlace() {
        let suggestedName = "Place \(model.telemetry.savedPlaces.count + 1)"
        guard let placeName = promptForPlaceName(defaultValue: suggestedName) else {
            return
        }

        model.telemetry.savePlace(
            named: placeName,
            wifiNetworks: model.wifiScanner.networks,
            bluetoothDevices: model.bluetoothScanner.devices
        )
        selectedPlaceID = model.telemetry.savedPlaces.first?.id
    }

    private func promptForPlaceName(defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Save Current Environment"
        alert.informativeText = "Give this baseline a short name so you can compare future scans against it."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = defaultValue
        alert.accessoryView = textField

        return alert.runModal() == .alertFirstButtonReturn
            ? textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }
}

#Preview {
    ContentView(model: WirelessDeckAppModel())
}
