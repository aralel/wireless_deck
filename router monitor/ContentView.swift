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
            return "Wi-Fi Radar"
        case .bluetooth:
            return "Bluetooth Radar"
        }
    }

    var subtitle: String {
        switch self {
        case .wifi:
            return "Nearby access points, channels, signal, and current join"
        case .bluetooth:
            return "Nearby BLE devices, signal, services, and visibility hints"
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
    @StateObject private var debugLogStore = DebugLogStore.shared
    @StateObject private var wifiScanner = WiFiScannerController()
    @StateObject private var bluetoothScanner = BluetoothScannerController()

    @State private var selectedSurface: RadarSurface = .wifi
    @State private var isDebugConsoleVisible = false

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
            .frame(minWidth: 1080, minHeight: 720, alignment: .topLeading)
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

    @ViewBuilder
    private var selectedSurfaceView: some View {
        switch selectedSurface {
        case .wifi:
            WiFiRadarView(scanner: wifiScanner)
        case .bluetooth:
            BluetoothRadarView(scanner: bluetoothScanner)
        }
    }

    private func surfaceCountText(for surface: RadarSurface) -> String {
        switch surface {
        case .wifi:
            return "\(wifiScanner.networks.count) networks"
        case .bluetooth:
            return "\(bluetoothScanner.devices.count) devices"
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
            return wifiScanner.statusLine
        case .bluetooth:
            return bluetoothScanner.statusLine
        }
    }

    private func prepare(_ surface: RadarSurface) {
        switch surface {
        case .wifi:
            wifiScanner.prepare()
        case .bluetooth:
            bluetoothScanner.prepare()
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
            if let lastScanDate = wifiScanner.lastScanDate {
                return "Last scan \(lastScanDate.formatted(date: .omitted, time: .standard))"
            }

            return "Ready when you are"
        case .bluetooth:
            if let lastScanDate = bluetoothScanner.lastScanDate {
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
                wifiScanner.refresh()
            } label: {
                Label(wifiScanner.isScanning ? "Scanning..." : "Refresh Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(wifiScanner.isScanning)
        case .bluetooth:
            if bluetoothScanner.isScanning {
                Button {
                    bluetoothScanner.stop()
                } label: {
                    Label("Stop Sweep", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    bluetoothScanner.refresh()
                } label: {
                    Label("Start Sweep", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
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
}

#Preview {
    ContentView()
}
