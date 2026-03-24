//
//  WiFiRadarView.swift
//  router monitor
//
//  Created by Codex on 23.03.2026.
//

import AppKit
import Charts
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
    @ObservedObject var telemetry: WirelessTelemetryStore
    let selectedPlace: SavedPlace?

    @State private var searchText = ""
    @State private var bandFilter: BandFilter = .all
    @State private var selectedNetworkID: WiFiNetwork.ID?
    @State private var signalAlertThreshold = -75
    @State private var sortOrder = [KeyPathComparator(\WiFiNetwork.signalStrength, order: .reverse)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            permissionCard
            networksSection
        }
        .task {
            AppLog.info("ui", "Wi-Fi radar tab appeared")
            scanner.prepare()
            syncSelectedNetwork(with: scanner.networks)
        }
        .onChange(of: scanner.networks) { _, networks in
            syncSelectedNetwork(with: networks)
        }
        .onChange(of: selectedNetworkID) { _, _ in
            syncAlertThreshold()
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
                    network.vendorDisplayName.localizedCaseInsensitiveContains(query) ||
                    "\(network.channel)".contains(query) ||
                    network.band.localizedCaseInsensitiveContains(query)
            }

            return matchesSearch && bandFilter.matches(network)
        }

        filteredNetworks.sort(using: sortOrder)
        return filteredNetworks
    }

    private var strongestVisibleNetwork: WiFiNetwork? {
        visibleNetworks.max(by: { $0.signalStrength < $1.signalStrength })
    }

    private var selectedNetwork: WiFiNetwork? {
        if let selectedNetworkID, let matchedNetwork = scanner.networks.first(where: { $0.id == selectedNetworkID }) {
            return matchedNetwork
        }

        return strongestVisibleNetwork ?? scanner.networks.first
    }

    private var selectedNetworkIsFilteredOut: Bool {
        guard let selectedNetwork else {
            return false
        }

        return !visibleNetworks.contains(where: { $0.id == selectedNetwork.id })
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bandFilter != .all
    }

    private var selectedNetworkTimeline: [SignalTimelineSample] {
        guard let selectedNetwork else {
            return []
        }

        return telemetry.wifiTimeline(for: selectedNetwork)
    }

    private var selectedNetworkChange: WirelessItemChange? {
        guard let selectedNetwork else {
            return nil
        }

        return telemetry.change(for: selectedNetwork)
    }

    private var selectedPlaceDigest: WirelessDiffDigest {
        telemetry.compareWiFi(current: scanner.networks, to: selectedPlace)
    }

    @ViewBuilder
    private var permissionCard: some View {
        switch scanner.permissionState {
        case .authorized:
            if scanner.sandboxInterfaceUnavailable {
                statusCard(
                    title: "Nearby Scan Blocked Right Now",
                    message: "This sandboxed build can still show cached Wi-Fi history, saved-place comparisons, and timelines. Wireless Deck will keep retrying nearby Wi-Fi discovery after launch, wake, or a manual refresh.",
                    symbol: "lock.shield.fill",
                    tint: .orange
                ) {
                    HStack(spacing: 12) {
                        Button("Retry Anyway") {
                            scanner.refresh()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("Bluetooth and all historical Wi-Fi views still work.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let nextAutomaticRetryDate = scanner.nextAutomaticRetryDate {
                        HStack(spacing: 4) {
                            Text("Automatic retry")
                            Text(nextAutomaticRetryDate, style: .relative)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            } else if let errorMessage = scanner.errorMessage {
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

                if let selectedNetwork {
                    Text("Selected: \(selectedNetwork.ssid)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

            HStack(alignment: .top, spacing: 16) {
                networksTableCard
                    .frame(minWidth: 760, maxWidth: .infinity, maxHeight: .infinity)

                inspectorCard
                    .frame(width: 360)
            }

            Text("Every completed Wi-Fi scan is stored locally, diffed against the previous scan, and added to the signal timeline. Watch a network to be notified when it appears, disappears, or dips below your threshold.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 320, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var networksTableCard: some View {
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
                Table(of: WiFiNetwork.self, selection: $selectedNetworkID, sortOrder: $sortOrder) {
                    TableColumn("") { network in
                        if network.isCurrentNetwork {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .width(32)

                    TableColumn("SSID", value: \.ssid)
                        .width(min: 170, ideal: 210)

                    TableColumn("Vendor", sortUsing: KeyPathComparator(\WiFiNetwork.vendorDisplayName)) { network in
                        Text(network.vendorDisplayName)
                            .foregroundStyle(network.vendorName == nil ? .secondary : .primary)
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("Identity", value: \.routerSummary)
                        .width(min: 190, ideal: 240)

                    TableColumn("Change", sortUsing: KeyPathComparator(\WiFiNetwork.signalStrength, order: .reverse)) { network in
                        changeBadgeRow(for: telemetry.change(for: network))
                    }
                    .width(min: 170, ideal: 190)

                    TableColumn("Security", value: \.security)
                        .width(min: 130, ideal: 160)

                    TableColumn("Signal", sortUsing: KeyPathComparator(\WiFiNetwork.signalStrength, order: .reverse)) { network in
                        signalStrengthView(for: network)
                    }
                    .width(min: 185, ideal: 215)

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
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var inspectorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Network Inspector", systemImage: "scope")
                    .font(.headline)

                Spacer()

                if let selectedNetwork {
                    Button("Copy Selection") {
                        copySelectedNetwork(selectedNetwork)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let selectedNetwork {
                selectedNetworkInspector(for: selectedNetwork)
            } else {
                ContentUnavailableView(
                    "No Network Selected",
                    systemImage: "wifi",
                    description: Text("Run a scan or select a visible row to inspect a nearby Wi-Fi network.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

                metricPill(
                    title: "Latest Diff",
                    value: telemetry.latestWiFiDiff.summaryLine,
                    symbol: "arrow.left.arrow.right"
                )

                if selectedPlace != nil {
                    metricPill(
                        title: "Vs Place",
                        value: selectedPlaceDigest.summaryLine,
                        symbol: "mappin.and.ellipse"
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var filtersRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search SSID, vendor, router, BSSID, security, or channel", text: $searchText)
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

    private func selectedNetworkInspector(for network: WiFiNetwork) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(network.ssid)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(network.routerSummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        detailTag(network.band, tint: .blue)
                        detailTag(network.security, tint: .orange)

                        if network.isCurrentNetwork {
                            detailTag("Current join", tint: .green)
                        }

                        if let vendorName = network.vendorName {
                            detailTag(vendorName, tint: .teal)
                        }
                    }

                    changeBadgeRow(for: selectedNetworkChange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Signal Story")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    signalStrengthView(for: network)

                    Text("\(network.noiseMargin) dB of estimated headroom against measured noise.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                timelineCard(for: network)
                watchCard(for: network)
                detailsCard(for: network)

                if let selectedPlace {
                    placeComparisonCard(for: network, selectedPlace: selectedPlace)
                }

                if selectedNetworkIsFilteredOut {
                    Label("This network is selected, but your current filters are hiding its row in the table.", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timelineCard(for network: WiFiNetwork) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timeline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if selectedNetworkTimeline.count >= 2 {
                Chart(selectedNetworkTimeline) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Signal", sample.signalStrength)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        yStart: .value("Floor", -90),
                        yEnd: .value("Signal", sample.signalStrength)
                    )
                    .foregroundStyle(.blue.opacity(0.12))
                }
                .chartYScale(domain: -90 ... -30)
                .frame(height: 150)

                Text("Last \(selectedNetworkTimeline.count) recorded scans for this network.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "Timeline Needs More Scans",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Run a few more Wi-Fi scans to build a signal history for this network.")
                )
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func watchCard(for network: WiFiNetwork) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Watch Alert")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if telemetry.alert(for: network) != nil {
                    Text("Watching")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            Text("Get a notification when this SSID appears, disappears, or drops below a signal threshold.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Stepper(value: $signalAlertThreshold, in: -90 ... -45, step: 5) {
                Text("Threshold \(signalAlertThreshold) dBm")
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                if telemetry.alert(for: network) == nil {
                    Button("Watch This Network") {
                        telemetry.addAlert(for: network, signalThreshold: signalAlertThreshold)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Remove Watch") {
                        telemetry.removeAlert(for: network)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let existingAlert = telemetry.alert(for: network) {
                    Text("Current trigger: \(existingAlert.signalThreshold) dBm")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailsCard(for network: WiFiNetwork) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow(title: "Vendor", value: network.vendorDisplayName)
            detailRow(title: "Identity", value: network.routerSummary)
            detailRow(title: "BSSID", value: network.displayBSSID, monospaced: true)
            detailRow(title: "Security", value: network.security)
            detailRow(title: "Channel", value: "\(network.channel) • \(network.band)")
            detailRow(title: "Noise", value: "\(network.noise) dBm • headroom \(network.noiseMargin) dB")
        }
    }

    private func placeComparisonCard(for network: WiFiNetwork, selectedPlace: SavedPlace) -> some View {
        let previousMatch = selectedPlace.wifiNetworks.first(where: { $0.historyKey == network.historyKey })

        return VStack(alignment: .leading, spacing: 10) {
            Text("Compared With \(selectedPlace.name)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let previousMatch {
                let delta = network.signalStrength - previousMatch.signalStrength
                let deltaPrefix = delta > 0 ? "+" : ""
                Text("This network was \(previousMatch.signalStrength) dBm there and is \(deltaPrefix)\(delta) dBm relative to that baseline now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("This network was not visible in the saved baseline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(selectedPlaceDigest.summaryLine)
                .font(.footnote.weight(.semibold))
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailTag(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
    }

    private func detailRow(title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func changeBadgeRow(for change: WirelessItemChange?) -> some View {
        HStack(spacing: 6) {
            if let change {
                ForEach(change.kinds, id: \.self) { kind in
                    Text(kind.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(changeTint(for: kind).opacity(0.12), in: Capsule())
                        .foregroundStyle(changeTint(for: kind))
                }
            } else {
                Text("Stable")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
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

    private func openSystemSettings() {
        AppLog.info("ui", "Opening System Settings from Wi-Fi radar")
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func copyVisibleNetworks() {
        let pasteboard = NSPasteboard.general
        let header = "SSID\tVendor\tIdentity\tSecurity\tBSSID\tSignal\tRSSI\tNoise\tChannel\tBand\tCurrent"
        let rows = visibleNetworks.map { network in
            [
                network.ssid,
                network.vendorDisplayName,
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

    private func copySelectedNetwork(_ network: WiFiNetwork) {
        let pasteboard = NSPasteboard.general
        let lines = [
            "SSID: \(network.ssid)",
            "Vendor: \(network.vendorDisplayName)",
            "Identity: \(network.routerSummary)",
            "Security: \(network.security)",
            "BSSID: \(network.displayBSSID)",
            "Signal: \(network.signalDescription) (\(network.signalPercent)%)",
            "RSSI: \(network.signalStrength) dBm",
            "Noise: \(network.noise) dBm",
            "Channel: \(network.channel) • \(network.band)",
        ]

        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
        AppLog.info("ui", "Copied selected Wi-Fi network \(network.ssid) to the pasteboard")
    }

    private func syncSelectedNetwork(with networks: [WiFiNetwork]) {
        guard !networks.isEmpty else {
            selectedNetworkID = nil
            return
        }

        if let selectedNetworkID, networks.contains(where: { $0.id == selectedNetworkID }) {
            return
        }

        selectedNetworkID = strongestVisibleNetwork?.id ?? networks.first?.id
        syncAlertThreshold()
    }

    private func syncAlertThreshold() {
        guard let selectedNetwork else {
            signalAlertThreshold = -75
            return
        }

        signalAlertThreshold = telemetry.alert(for: selectedNetwork)?.signalThreshold ?? -75
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

    private func changeTint(for kind: WirelessChangeKind) -> Color {
        switch kind {
        case .new:
            return .green
        case .missing:
            return .red
        case .stronger:
            return .teal
        case .weaker:
            return .orange
        case .moved:
            return .blue
        }
    }
}
