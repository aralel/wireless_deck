//
//  WiFiRadarView.swift
//  router monitor
//
//  Created by Codex on 23.03.2026.
//

import AppKit
import SwiftUI

private enum BandFilter: String, CaseIterable, Identifiable {
    case all = "All Bands"
    case band24 = "2.4 GHz"
    case band5 = "5 GHz"
    case band6 = "6 GHz"

    var id: Self { self }

    func matches(_ network: WiFiNetwork) -> Bool {
        switch self {
        case .all:
            return true
        case .band24:
            return network.band == "2.4 GHz"
        case .band5:
            return network.band == "5 GHz"
        case .band6:
            return network.band == "6 GHz"
        }
    }
}

struct WiFiRadarView: View {
    @ObservedObject var scanner: WiFiScannerController

    @State private var searchText = ""
    @State private var bandFilter: BandFilter = .all
    @State private var sortOrder = [KeyPathComparator(\WiFiNetwork.signalStrength, order: .reverse)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            permissionCard
            networksSection
        }
        .task {
            AppLog.info("ui", "Wi-Fi radar tab appeared")
            scanner.prepare()
        }
    }

    private var visibleNetworks: [WiFiNetwork] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var filteredNetworks = scanner.networks.filter { network in
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    network.ssid.localizedCaseInsensitiveContains(query) ||
                    network.routerSummary.localizedCaseInsensitiveContains(query) ||
                    network.security.localizedCaseInsensitiveContains(query) ||
                    network.displayBSSID.localizedCaseInsensitiveContains(query) ||
                    "\(network.channel)".contains(query) ||
                    network.band.localizedCaseInsensitiveContains(query)
            }

            return matchesSearch && bandFilter.matches(network)
        }

        filteredNetworks.sort(using: sortOrder)
        return filteredNetworks
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bandFilter != .all
    }

    private var strongestVisibleNetwork: WiFiNetwork? {
        visibleNetworks.max(by: { $0.signalStrength < $1.signalStrength })
    }

    @ViewBuilder
    private var permissionCard: some View {
        switch scanner.permissionState {
        case .authorized:
            if let errorMessage = scanner.errorMessage {
                statusCard(
                    title: "Scan Issue",
                    message: errorMessage,
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
        case .notDetermined:
            statusCard(
                title: "Location Access Needed",
                message: "macOS only reveals nearby Wi-Fi names and BSSIDs to apps that have Location Services permission.",
                symbol: "location.fill",
                tint: .blue
            ) {
                Button("Allow Location Access") {
                    scanner.requestLocationAccess()
                }
                .buttonStyle(.borderedProminent)
            }
        case .denied:
            statusCard(
                title: "Location Access Was Denied",
                message: "Open System Settings, then go to Privacy & Security > Location Services and enable access for router monitor.",
                symbol: "location.slash.fill",
                tint: .red
            ) {
                HStack(spacing: 12) {
                    Button("Open System Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Check Again") {
                        scanner.prepare()
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .restricted:
            statusCard(
                title: "Location Access Is Restricted",
                message: "This Mac is currently preventing location access for the app, so Wi-Fi details stay hidden.",
                symbol: "hand.raised.fill",
                tint: .orange
            )
        case .servicesDisabled:
            statusCard(
                title: "Location Services Are Off",
                message: "Turn on Location Services in System Settings before scanning nearby Wi-Fi networks.",
                symbol: "location.slash.circle.fill",
                tint: .orange
            ) {
                Button("Open System Settings") {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var networksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("\(visibleNetworks.count) shown", systemImage: "wifi")
                    .font(.headline)

                if visibleNetworks.count != scanner.networks.count {
                    Text("of \(scanner.networks.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if scanner.permissionState == .authorized && !scanner.hasVisibleBSSIDs {
                    Text("BSSIDs are still hidden. Grant location access from the system prompt if macOS asks again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            metricsRow
            filtersRow

            Group {
                if scanner.permissionState == .authorized && scanner.networks.isEmpty && !scanner.isScanning && scanner.errorMessage == nil {
                    ContentUnavailableView(
                        "No Wi-Fi Networks Found",
                        systemImage: "wifi.slash",
                        description: Text("Try refreshing the scan or moving closer to the access point you want to inspect.")
                    )
                } else if scanner.permissionState != .authorized && scanner.networks.isEmpty {
                    ContentUnavailableView(
                        "Waiting For Permission",
                        systemImage: "location.viewfinder",
                        description: Text("Once location access is granted, the app can scan nearby Wi-Fi networks.")
                    )
                } else if visibleNetworks.isEmpty {
                    ContentUnavailableView(
                        "No Matching Networks",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Adjust your search or filters to bring more access points back into view.")
                    )
                } else {
                    Table(of: WiFiNetwork.self, sortOrder: $sortOrder) {
                        TableColumn("") { network in
                            if network.isCurrentNetwork {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .width(32)

                        TableColumn("SSID", value: \.ssid)
                            .width(min: 170, ideal: 210)

                        TableColumn("Router", value: \.routerSummary)
                            .width(min: 220, ideal: 260)

                        TableColumn("Security", value: \.security)
                            .width(min: 130, ideal: 160)

                        TableColumn("BSSID", sortUsing: KeyPathComparator(\WiFiNetwork.displayBSSID)) { network in
                            Text(network.displayBSSID)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(network.bssid == nil ? .secondary : .primary)
                        }
                        .width(min: 180, ideal: 210)

                        TableColumn("Signal", sortUsing: KeyPathComparator(\WiFiNetwork.signalStrength, order: .reverse)) { network in
                            signalStrengthView(for: network)
                        }
                        .width(min: 190, ideal: 220)

                        TableColumn("Noise", sortUsing: KeyPathComparator(\WiFiNetwork.noise)) { network in
                            Text("\(network.noise) dBm")
                                .font(.system(.body, design: .monospaced))
                        }
                        .width(90)

                        TableColumn("Channel", sortUsing: KeyPathComparator(\WiFiNetwork.channel)) { network in
                            Text("\(network.channel)")
                                .font(.system(.body, design: .monospaced))
                        }
                        .width(80)

                        TableColumn("Band", value: \.band)
                            .width(80)
                    } rows: {
                        ForEach(visibleNetworks) { network in
                            TableRow(network)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("Click any header to sort. Search and filters update live, and Copy Visible exports the rows currently on screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 280, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statusCard(
        title: String,
        message: String,
        symbol: String,
        tint: Color,
        @ViewBuilder actions: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actions()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var metricsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                metricPill(
                    title: "Visible",
                    value: "\(visibleNetworks.count) networks",
                    symbol: "wifi"
                )

                metricPill(
                    title: "Strongest",
                    value: strongestVisibleNetwork.map { "\($0.ssid) • \($0.signalDescription) (\($0.signalPercent)%)" } ?? "--",
                    symbol: "bolt.horizontal.circle"
                )
            }
            .padding(.vertical, 2)
        }
    }

    private var filtersRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search SSID, router, BSSID, security, or channel", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Picker("Band", selection: $bandFilter) {
                ForEach(BandFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)

            if hasActiveFilters {
                Button("Reset Filters") {
                    searchText = ""
                    bandFilter = .all
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Copy Visible") {
                copyVisibleNetworks()
            }
            .buttonStyle(.bordered)
            .disabled(visibleNetworks.isEmpty)
        }
    }

    private func metricPill(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func signalStrengthView(for network: WiFiNetwork) -> some View {
        HStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index < network.signalBars ? signalTint(for: network) : Color.secondary.opacity(0.18))
                        .frame(width: 6, height: CGFloat(7 + (index * 4)))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(network.signalDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(signalTint(for: network))

                Text("\(network.signalPercent)% • \(network.signalStrength) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func openSystemSettings() {
        AppLog.info("ui", "Opening System Settings from Wi-Fi radar")
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func copyVisibleNetworks() {
        let pasteboard = NSPasteboard.general
        let header = "SSID\tRouter\tSecurity\tBSSID\tSignal\tRSSI\tNoise\tChannel\tBand\tCurrent"
        let rows = visibleNetworks.map { network in
            [
                network.ssid,
                network.routerSummary,
                network.security,
                network.displayBSSID,
                "\(network.signalDescription) (\(network.signalPercent)%)",
                "\(network.signalStrength)",
                "\(network.noise)",
                "\(network.channel)",
                network.band,
                network.isCurrentNetwork ? "yes" : "no",
            ]
            .joined(separator: "\t")
        }
        .joined(separator: "\n")

        pasteboard.clearContents()
        pasteboard.setString([header, rows].filter { !$0.isEmpty }.joined(separator: "\n"), forType: .string)
        AppLog.info("ui", "Copied \(visibleNetworks.count) visible Wi-Fi networks to the pasteboard")
    }

    private func signalTint(for network: WiFiNetwork) -> Color {
        if network.signalStrength >= -55 {
            return .green
        }

        if network.signalStrength >= -67 {
            return .teal
        }

        if network.signalStrength >= -75 {
            return .orange
        }

        return .red
    }
}
