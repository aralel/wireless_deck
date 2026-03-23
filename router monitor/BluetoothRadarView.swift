//
//  BluetoothRadarView.swift
//  router monitor
//
//  Created by Codex on 23.03.2026.
//

import AppKit
import SwiftUI

struct BluetoothRadarView: View {
    @ObservedObject var scanner: BluetoothScannerController

    @State private var searchText = ""
    @State private var showConnectableOnly = false
    @State private var showNamedOnly = false
    @State private var selectedDeviceID: BluetoothDevice.ID?
    @State private var sortOrder = [KeyPathComparator(\BluetoothDevice.signalStrength, order: .reverse)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            availabilityCard
            devicesSection
        }
        .task {
            AppLog.info("ui", "Bluetooth radar tab appeared")
            scanner.prepare()
        }
        .onChange(of: scanner.devices) { _, devices in
            syncSelectedDevice(with: devices)
        }
    }

    private var visibleDevices: [BluetoothDevice] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var filteredDevices = scanner.devices.filter { device in
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    device.name.localizedCaseInsensitiveContains(query) ||
                    device.typeGuess.localizedCaseInsensitiveContains(query) ||
                    device.identifierString.localizedCaseInsensitiveContains(query) ||
                    device.serviceSummary.localizedCaseInsensitiveContains(query) ||
                    device.manufacturerSummary.localizedCaseInsensitiveContains(query)
            }

            let passesNamedFilter = !showNamedOnly || device.name != "Unnamed device"
            let passesConnectableFilter = !showConnectableOnly || device.isConnectable == true

            return matchesSearch && passesNamedFilter && passesConnectableFilter
        }

        filteredDevices.sort(using: sortOrder)
        return filteredDevices
    }

    private var strongestVisibleDevice: BluetoothDevice? {
        visibleDevices.max(by: { $0.signalStrength < $1.signalStrength })
    }

    private var identifiedDevicesCount: Int {
        visibleDevices.filter { $0.typeGuess != BluetoothDeviceIdentity.fallbackTypeGuess }.count
    }

    private var connectableVisibleCount: Int {
        visibleDevices.filter { $0.isConnectable == true }.count
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showConnectableOnly || showNamedOnly
    }

    private var selectedDevice: BluetoothDevice? {
        if let selectedDeviceID, let matchedDevice = scanner.devices.first(where: { $0.id == selectedDeviceID }) {
            return matchedDevice
        }

        return strongestVisibleDevice ?? scanner.devices.first
    }

    private var selectedDeviceIsFilteredOut: Bool {
        guard let selectedDevice else {
            return false
        }

        return !visibleDevices.contains(where: { $0.id == selectedDevice.id })
    }

    @ViewBuilder
    private var availabilityCard: some View {
        switch scanner.availabilityState {
        case .ready:
            if let errorMessage = scanner.errorMessage, scanner.devices.isEmpty {
                statusCard(
                    title: "Bluetooth Sweep Note",
                    message: errorMessage,
                    symbol: "dot.radiowaves.left.and.right",
                    tint: .orange
                )
            }
        case .permissionNotDetermined:
            statusCard(
                title: "Bluetooth Access May Be Needed",
                message: "macOS may ask for Bluetooth permission the first time you start a sweep. If it does, allow access so the app can discover nearby devices.",
                symbol: "dot.radiowaves.left.and.right",
                tint: .blue
            ) {
                Button("Start Bluetooth Sweep") {
                    scanner.refresh()
                }
                .buttonStyle(.borderedProminent)
            }
        case .permissionDenied:
            statusCard(
                title: "Bluetooth Access Was Denied",
                message: "Open System Settings, then go to Privacy & Security > Bluetooth and enable access for router monitor.",
                symbol: "bolt.horizontal.circle.fill",
                tint: .red
            ) {
                HStack(spacing: 12) {
                    Button("Open System Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Try Again") {
                        scanner.refresh()
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .permissionRestricted:
            statusCard(
                title: "Bluetooth Access Is Restricted",
                message: "This Mac is currently preventing Bluetooth discovery for the app.",
                symbol: "hand.raised.fill",
                tint: .orange
            )
        case .poweredOff:
            statusCard(
                title: "Bluetooth Is Off",
                message: "Turn Bluetooth on in System Settings before starting a sweep.",
                symbol: "bolt.slash.fill",
                tint: .orange
            ) {
                HStack(spacing: 12) {
                    Button("Open System Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Check Again") {
                        scanner.refresh()
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .resetting:
            statusCard(
                title: "Bluetooth Is Resetting",
                message: "The system Bluetooth service is restarting. Wait a moment, then run another sweep.",
                symbol: "arrow.triangle.2.circlepath.circle.fill",
                tint: .orange
            )
        case .unsupported:
            statusCard(
                title: "Bluetooth Discovery Is Unsupported",
                message: "This Mac does not support Bluetooth Low Energy scanning for nearby peripherals.",
                symbol: "bolt.horizontal.circle.fill",
                tint: .orange
            )
        case .unknown:
            statusCard(
                title: "Bluetooth Is Initializing",
                message: "The Bluetooth stack is still warming up. Try a sweep again in a moment.",
                symbol: "timer",
                tint: .blue
            )
        }
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("\(visibleDevices.count) shown", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)

                if visibleDevices.count != scanner.devices.count {
                    Text("of \(scanner.devices.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let selectedDevice {
                    Text("Selected: \(selectedDevice.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if scanner.isScanning {
                    Text("Live sweep in progress")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.teal)
                }
            }

            metricsRow
            filtersRow

            HStack(alignment: .top, spacing: 16) {
                devicesTableCard
                    .frame(minWidth: 660, maxWidth: .infinity, maxHeight: .infinity)

                inspectorCard
                    .frame(width: 320)
            }

            Text("Bluetooth sweeps list devices that are actively advertising nearby. Select a row to inspect it, click any header to sort, and Copy Visible exports the rows on screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 280, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var devicesTableCard: some View {
        Group {
            if scanner.isScanning && scanner.devices.isEmpty {
                ContentUnavailableView(
                    "Sweeping For Devices",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Nearby Bluetooth devices will appear here as they advertise.")
                )
            } else if scanner.devices.isEmpty && scanner.availabilityState == .ready && !scanner.isScanning {
                ContentUnavailableView(
                    "No Bluetooth Devices Found",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Nearby devices must be powered on and advertising to appear in a sweep.")
                )
            } else if visibleDevices.isEmpty {
                ContentUnavailableView(
                    "No Matching Devices",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Adjust your search or filters to bring more devices back into view.")
                )
            } else {
                Table(of: BluetoothDevice.self, selection: $selectedDeviceID, sortOrder: $sortOrder) {
                    TableColumn("Device", value: \.name)
                        .width(min: 180, ideal: 220)

                    TableColumn("Type Guess", value: \.typeGuess)
                        .width(min: 160, ideal: 210)

                    TableColumn("Connectable", sortUsing: KeyPathComparator(\BluetoothDevice.connectableLabel)) { device in
                        connectableBadge(for: device)
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("Services", sortUsing: KeyPathComparator(\BluetoothDevice.serviceCount, order: .reverse)) { device in
                        Text(device.serviceSummary)
                            .foregroundStyle(device.serviceCount == 0 ? .secondary : .primary)
                    }
                    .width(min: 170, ideal: 220)

                    TableColumn("Manufacturer", value: \.manufacturerSummary)
                        .width(min: 150, ideal: 190)

                    TableColumn("Signal", sortUsing: KeyPathComparator(\BluetoothDevice.signalStrength, order: .reverse)) { device in
                        signalStrengthView(for: device)
                    }
                    .width(min: 185, ideal: 220)

                    TableColumn("Last Seen", sortUsing: KeyPathComparator(\BluetoothDevice.lastSeenDate, order: .reverse)) { device in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.lastSeenSummary)
                                .font(.subheadline.weight(.semibold))

                            Text("\(device.seenCount)x seen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("Identifier", value: \.identifierString) { device in
                        Text(device.identifierString)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 210, ideal: 250)
                } rows: {
                    ForEach(visibleDevices) { device in
                        TableRow(device)
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
                Label("Device Inspector", systemImage: "scope")
                    .font(.headline)

                Spacer()

                if let selectedDevice {
                    Button("Copy Selection") {
                        copySelectedDevice(selectedDevice)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let selectedDevice {
                selectedDeviceInspector(for: selectedDevice)
            } else {
                ContentUnavailableView(
                    "No Device Selected",
                    systemImage: "bolt.horizontal.circle",
                    description: Text("Run a sweep or select a visible row to inspect a nearby Bluetooth device.")
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
                    value: "\(visibleDevices.count)",
                    symbol: "dot.radiowaves.left.and.right"
                )

                metricPill(
                    title: "Connectable",
                    value: "\(connectableVisibleCount)",
                    symbol: "bolt.badge.clock"
                )

                metricPill(
                    title: "Strongest",
                    value: strongestVisibleDevice.map { "\($0.name) • \($0.signalDescription) (\($0.signalPercent)%)" } ?? "--",
                    symbol: "bolt.horizontal.circle"
                )

                metricPill(
                    title: "Identified",
                    value: "\(identifiedDevicesCount)",
                    symbol: "sparkles"
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

                TextField("Search name, type guess, identifier, service, or manufacturer", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Toggle("Connectable only", isOn: $showConnectableOnly)
                .toggleStyle(.switch)
                .fixedSize()

            Toggle("Named only", isOn: $showNamedOnly)
                .toggleStyle(.switch)
                .fixedSize()

            if hasActiveFilters {
                Button("Reset Filters") {
                    searchText = ""
                    showConnectableOnly = false
                    showNamedOnly = false
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("Focus Strongest") {
                selectedDeviceID = strongestVisibleDevice?.id
            }
            .buttonStyle(.bordered)
            .disabled(strongestVisibleDevice == nil)

            Button("Copy Visible") {
                copyVisibleDevices()
            }
            .buttonStyle(.bordered)
            .disabled(visibleDevices.isEmpty)
        }
    }

    private func selectedDeviceInspector(for device: BluetoothDevice) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(device.name)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(device.typeGuess)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        connectableBadge(for: device)

                        detailTag(device.proximitySummary, tint: signalTint(for: device))

                        if device.localName != nil {
                            detailTag("Advertised name", tint: .blue)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Signal Story")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    signalStrengthView(for: device)

                    Text(fieldNotes(for: device))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    detailRow(title: "Manufacturer", value: device.manufacturerSummary)
                    detailRow(title: "Services", value: device.serviceSummary)
                    detailRow(title: "Stability", value: device.stabilitySummary)
                    detailRow(title: "Last seen", value: "\(device.lastSeenSummary) • \(device.seenCount)x observed")

                    if let localName = device.localName {
                        detailRow(title: "Local name", value: localName)
                    }

                    detailRow(title: "Identifier", value: device.identifierString, monospaced: true)
                }

                if selectedDeviceIsFilteredOut {
                    Label("This device is selected, but your current filters are hiding its row in the table.", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricPill(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.teal)

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

    private func connectableBadge(for device: BluetoothDevice) -> some View {
        Text(device.connectableLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(connectableTint(for: device).opacity(0.12), in: Capsule())
            .foregroundStyle(connectableTint(for: device))
    }

    private func signalStrengthView(for device: BluetoothDevice) -> some View {
        HStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index < device.signalBars ? signalTint(for: device) : Color.secondary.opacity(0.18))
                        .frame(width: 6, height: CGFloat(7 + (index * 4)))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.signalDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(signalTint(for: device))

                Text("\(device.signalPercent)% • \(device.signalStrength) dBm")
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
        AppLog.info("ui", "Opening System Settings from Bluetooth radar")
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func copyVisibleDevices() {
        let pasteboard = NSPasteboard.general
        let header = "Name\tType Guess\tConnectable\tServices\tManufacturer\tSignal\tRSSI\tLast Seen\tIdentifier"
        let rows = visibleDevices.map { device in
            [
                device.name,
                device.typeGuess,
                device.connectableLabel,
                device.serviceSummary,
                device.manufacturerSummary,
                "\(device.signalDescription) (\(device.signalPercent)%)",
                "\(device.signalStrength)",
                device.lastSeenSummary,
                device.identifierString,
            ]
            .joined(separator: "\t")
        }
        .joined(separator: "\n")

        pasteboard.clearContents()
        pasteboard.setString([header, rows].filter { !$0.isEmpty }.joined(separator: "\n"), forType: .string)
        AppLog.info("ui", "Copied \(visibleDevices.count) visible Bluetooth devices to the pasteboard")
    }

    private func copySelectedDevice(_ device: BluetoothDevice) {
        let pasteboard = NSPasteboard.general
        let lines = [
            "Name: \(device.name)",
            "Type Guess: \(device.typeGuess)",
            "Connectable: \(device.connectableLabel)",
            "Services: \(device.serviceSummary)",
            "Manufacturer: \(device.manufacturerSummary)",
            "Signal: \(device.signalDescription) (\(device.signalPercent)%)",
            "RSSI: \(device.signalStrength) dBm",
            "Last Seen: \(device.lastSeenSummary)",
            "Seen Count: \(device.seenCount)",
            "Identifier: \(device.identifierString)",
        ]

        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
        AppLog.info("ui", "Copied selected Bluetooth device \(device.identifierString) to the pasteboard")
    }

    private func syncSelectedDevice(with devices: [BluetoothDevice]) {
        guard !devices.isEmpty else {
            selectedDeviceID = nil
            return
        }

        if let selectedDeviceID, devices.contains(where: { $0.id == selectedDeviceID }) {
            return
        }

        selectedDeviceID = strongestVisibleDevice?.id ?? devices.first?.id
    }

    private func fieldNotes(for device: BluetoothDevice) -> String {
        var notes: [String] = []
        notes.append("\(device.proximitySummary) based on the current signal.")

        if device.serviceCount == 0 {
            notes.append("It is advertising without a public service list.")
        } else {
            notes.append("It is advertising \(device.serviceSummary.lowercased()).")
        }

        switch device.isConnectable {
        case true:
            notes.append("The advertisement says the device should accept direct connections.")
        case false:
            notes.append("The advertisement looks broadcast-only right now.")
        case nil:
            notes.append("The advertisement does not clearly say whether it is connectable.")
        }

        return notes.joined(separator: " ")
    }

    private func signalTint(for device: BluetoothDevice) -> Color {
        if device.signalStrength >= -55 {
            return .green
        }

        if device.signalStrength >= -67 {
            return .teal
        }

        if device.signalStrength >= -75 {
            return .orange
        }

        return .red
    }

    private func connectableTint(for device: BluetoothDevice) -> Color {
        switch device.isConnectable {
        case true:
            return .green
        case false:
            return .orange
        case nil:
            return .secondary
        }
    }
}
