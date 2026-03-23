//
//  BluetoothScanner.swift
//  router monitor
//
//  Created by Codex on 23.03.2026.
//

import Combine
import CoreBluetooth
import Foundation

struct BluetoothDevice: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let name: String
    let typeGuess: String
    let identifierString: String
    let localName: String?
    let isConnectable: Bool?
    let serviceSummary: String
    let serviceCount: Int
    let manufacturerSummary: String
    let signalStrength: Int
    let lastSeenDate: Date
    let seenCount: Int

    nonisolated var signalDescription: String {
        WiFiSignalPresentation.description(forRSSI: signalStrength)
    }

    nonisolated var signalPercent: Int {
        WiFiSignalPresentation.percent(forRSSI: signalStrength)
    }

    nonisolated var signalBars: Int {
        WiFiSignalPresentation.bars(forRSSI: signalStrength)
    }

    nonisolated var connectableLabel: String {
        guard let isConnectable else {
            return "Unknown"
        }

        return isConnectable ? "Yes" : "No"
    }

    nonisolated var lastSeenSummary: String {
        let elapsedSeconds = max(0, Int(Date().timeIntervalSince(lastSeenDate)))

        if elapsedSeconds < 2 {
            return "Just now"
        }

        if elapsedSeconds < 60 {
            return "\(elapsedSeconds)s ago"
        }

        let elapsedMinutes = elapsedSeconds / 60

        if elapsedMinutes < 60 {
            return "\(elapsedMinutes)m ago"
        }

        return lastSeenDate.formatted(date: .omitted, time: .shortened)
    }

    nonisolated var proximitySummary: String {
        if signalStrength >= -55 {
            return "Very close"
        }

        if signalStrength >= -67 {
            return "Nearby"
        }

        if signalStrength >= -75 {
            return "A room away"
        }

        if signalStrength >= -83 {
            return "Farther out"
        }

        return "Edge of range"
    }

    nonisolated var stabilitySummary: String {
        switch seenCount {
        case 8...:
            return "Advertising steadily"
        case 4...:
            return "Seen repeatedly"
        case 2...:
            return "Seen more than once"
        default:
            return "Only seen briefly"
        }
    }
}

enum BluetoothAvailabilityState: Equatable {
    case unknown
    case permissionNotDetermined
    case permissionDenied
    case permissionRestricted
    case poweredOff
    case resetting
    case unsupported
    case ready
}

@MainActor
final class BluetoothScannerController: NSObject, ObservableObject {
    @Published private(set) var devices: [BluetoothDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var availabilityState: BluetoothAvailabilityState = .unknown
    @Published private(set) var errorMessage: String?

    private var centralManager: CBCentralManager?
    private var stopScanTask: Task<Void, Never>?
    private var loggedDeviceIdentifiers: Set<UUID> = []
    private var currentSweepDevices: [UUID: BluetoothDevice] = [:]

    private let scanDuration: Duration = .seconds(8)
    private let autoSweepInterval: TimeInterval = 25

    var connectableDevicesCount: Int {
        devices.filter { $0.isConnectable == true }.count
    }

    var statusLine: String {
        switch availabilityState {
        case .ready:
            if isScanning {
                return "Sweeping nearby Bluetooth Low Energy devices..."
            }

            if let errorMessage {
                return errorMessage
            }

            if devices.isEmpty {
                return "Ready to discover nearby Bluetooth devices"
            }

            return "Nearby Bluetooth devices ready to inspect"
        case .permissionNotDetermined:
            return "Start a Bluetooth sweep to let macOS request access if needed"
        case .permissionDenied:
            return "Bluetooth access is off for this app"
        case .permissionRestricted:
            return "Bluetooth access is restricted on this Mac"
        case .poweredOff:
            return "Bluetooth is currently turned off"
        case .resetting:
            return "Bluetooth is resetting on this Mac"
        case .unsupported:
            return "This Mac does not support Bluetooth Low Energy scanning"
        case .unknown:
            return "Bluetooth is warming up on this Mac"
        }
    }

    override init() {
        super.init()
        AppLog.info("bluetooth", "Bluetooth scanner initialized")
        restoreCachedSnapshot()
    }

    deinit {
        stopScanTask?.cancel()
        centralManager?.stopScan()
    }

    func prepare() {
        ensureCentralManager()
        updateAvailabilityState()
        AppLog.debug(
            "bluetooth",
            "Preparing Bluetooth scanner with availabilityState=\(availabilityState.debugName) cachedDevices=\(devices.count)"
        )
        autoSweepIfNeeded(reason: "prepare")
    }

    func refresh() {
        guard !isScanning else {
            AppLog.debug("bluetooth", "Refresh ignored because a Bluetooth sweep is already in progress")
            return
        }

        ensureCentralManager()
        updateAvailabilityState()
        AppLog.info("bluetooth", "Refresh requested with availabilityState=\(availabilityState.debugName)")

        switch availabilityState {
        case .ready, .permissionNotDetermined:
            startScanSweep()
        case .permissionDenied:
            errorMessage = "Enable Bluetooth access for router monitor in System Settings."
        case .permissionRestricted:
            errorMessage = "Bluetooth access is restricted for this Mac."
        case .poweredOff:
            errorMessage = "Turn Bluetooth on in System Settings before starting a sweep."
        case .resetting:
            errorMessage = "Bluetooth is resetting right now. Try again in a moment."
        case .unsupported:
            errorMessage = "This Mac does not support Bluetooth Low Energy discovery."
        case .unknown:
            errorMessage = "Bluetooth is still initializing. Try again in a moment."
        }

        if let errorMessage, availabilityState != .ready, availabilityState != .permissionNotDetermined {
            AppLog.warning(
                "bluetooth",
                "Bluetooth sweep blocked because availabilityState=\(availabilityState.debugName) error=\(errorMessage)"
            )
        }
    }

    func stop() {
        finishScanSweep(reason: "stopped by user")
    }

    private func ensureCentralManager() {
        guard centralManager == nil else {
            return
        }

        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
        AppLog.debug("bluetooth", "CoreBluetooth central manager created")
    }

    private func startScanSweep() {
        guard let centralManager else {
            errorMessage = "Bluetooth could not be initialized."
            return
        }

        stopScanTask?.cancel()
        centralManager.stopScan()

        currentSweepDevices.removeAll()
        loggedDeviceIdentifiers.removeAll()
        isScanning = true
        errorMessage = nil

        AppLog.debug(
            "bluetooth",
            "Starting Bluetooth sweep allowDuplicates=true durationSeconds=\(Int(scanDuration.components.seconds))"
        )

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        stopScanTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: scanDuration)
            finishScanSweep(reason: "completed")
        }
    }

    private func finishScanSweep(reason: String) {
        guard isScanning else {
            return
        }

        let discoveredDevices = Self.sortedDevices(Array(currentSweepDevices.values))

        stopScanTask?.cancel()
        stopScanTask = nil
        centralManager?.stopScan()
        isScanning = false
        lastScanDate = .now

        if !discoveredDevices.isEmpty {
            devices = discoveredDevices
            errorMessage = nil
        } else if devices.isEmpty && errorMessage == nil {
            errorMessage = "No Bluetooth devices were discovered. Nearby devices must be powered on and advertising to appear."
        } else if errorMessage == nil {
            errorMessage = "No Bluetooth devices were discovered in the latest sweep. Showing previous results."
        }

        persistSnapshot()
        currentSweepDevices.removeAll()
        AppLog.info("bluetooth", "Bluetooth sweep \(reason) with \(devices.count) devices")
    }

    private func updateAvailabilityState() {
        let previousState = availabilityState
        let authorization = CBManager.authorization
        let managerState = centralManager?.state ?? .unknown

        switch authorization {
        case .restricted:
            availabilityState = .permissionRestricted
        case .denied:
            availabilityState = .permissionDenied
        case .notDetermined:
            availabilityState = stateBeforeAuthorization(from: managerState)
        case .allowedAlways:
            availabilityState = authorizedState(from: managerState)
        @unknown default:
            availabilityState = .unknown
        }

        if previousState != availabilityState {
            AppLog.info(
                "bluetooth",
                "Bluetooth availability changed from \(previousState.debugName) to \(availabilityState.debugName) managerState=\(managerState.debugName) authorization=\(authorization.debugName)"
            )
        }

        if availabilityState != .ready, availabilityState != .permissionNotDetermined, isScanning {
            finishScanSweep(reason: "interrupted by state change")
        }
    }

    private func stateBeforeAuthorization(from managerState: CBManagerState) -> BluetoothAvailabilityState {
        switch managerState {
        case .poweredOn:
            return .permissionNotDetermined
        case .poweredOff:
            return .poweredOff
        case .unsupported:
            return .unsupported
        case .resetting:
            return .resetting
        case .unauthorized:
            return .permissionDenied
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private func authorizedState(from managerState: CBManagerState) -> BluetoothAvailabilityState {
        switch managerState {
        case .poweredOn:
            return .ready
        case .poweredOff:
            return .poweredOff
        case .unsupported:
            return .unsupported
        case .resetting:
            return .resetting
        case .unauthorized:
            return .permissionDenied
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private func integrate(_ device: BluetoothDevice) {
        if let existingDevice = currentSweepDevices[device.id] {
            currentSweepDevices[device.id] = Self.merged(existing: existingDevice, discovered: device)
        } else {
            currentSweepDevices[device.id] = device
        }

        devices = Self.sortedDevices(Array(currentSweepDevices.values))
    }

    nonisolated private static func makeDevice(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: Int,
        seenAt: Date
    ) -> BluetoothDevice {
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let peripheralName = peripheral.name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let displayName = localName ?? peripheralName ?? "Unnamed device"
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let serviceUUIDs = (
            advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        ) + (
            advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []
        )
        let uniqueServiceUUIDs = Array(Set(serviceUUIDs))

        return BluetoothDevice(
            id: peripheral.identifier,
            name: displayName,
            typeGuess: BluetoothDeviceIdentity.inferType(
                from: displayName,
                localName: localName,
                manufacturerData: manufacturerData,
                serviceUUIDs: uniqueServiceUUIDs
            ),
            identifierString: peripheral.identifier.uuidString.lowercased(),
            localName: localName,
            isConnectable: advertisementData[CBAdvertisementDataIsConnectable] as? Bool,
            serviceSummary: BluetoothServiceCatalog.summary(for: uniqueServiceUUIDs),
            serviceCount: uniqueServiceUUIDs.count,
            manufacturerSummary: BluetoothDeviceIdentity.manufacturerSummary(from: manufacturerData),
            signalStrength: rssi,
            lastSeenDate: seenAt,
            seenCount: 1
        )
    }

    nonisolated private static func merged(existing: BluetoothDevice, discovered: BluetoothDevice) -> BluetoothDevice {
        BluetoothDevice(
            id: existing.id,
            name: discovered.name == "Unnamed device" ? existing.name : discovered.name,
            typeGuess: discovered.typeGuess == BluetoothDeviceIdentity.fallbackTypeGuess ? existing.typeGuess : discovered.typeGuess,
            identifierString: existing.identifierString,
            localName: discovered.localName ?? existing.localName,
            isConnectable: discovered.isConnectable ?? existing.isConnectable,
            serviceSummary: discovered.serviceCount > 0 ? discovered.serviceSummary : existing.serviceSummary,
            serviceCount: max(existing.serviceCount, discovered.serviceCount),
            manufacturerSummary: discovered.manufacturerSummary == BluetoothDeviceIdentity.noManufacturerSummary
                ? existing.manufacturerSummary
                : discovered.manufacturerSummary,
            signalStrength: discovered.signalStrength,
            lastSeenDate: discovered.lastSeenDate,
            seenCount: existing.seenCount + 1
        )
    }

    nonisolated private static func sortedDevices(_ devices: [BluetoothDevice]) -> [BluetoothDevice] {
        devices.sorted { lhs, rhs in
            if lhs.signalStrength == rhs.signalStrength {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return lhs.signalStrength > rhs.signalStrength
        }
    }

    private func restoreCachedSnapshot() {
        guard let snapshot = RadarCacheStore.load(BluetoothScanSnapshot.self, for: .bluetooth) else {
            return
        }

        devices = snapshot.devices
        lastScanDate = snapshot.lastScanDate
        AppLog.info("cache", "Loaded \(snapshot.devices.count) cached Bluetooth devices from disk")
    }

    private func persistSnapshot() {
        RadarCacheStore.save(
            BluetoothScanSnapshot(devices: devices, lastScanDate: lastScanDate),
            for: .bluetooth
        )
        AppLog.debug("cache", "Saved \(devices.count) Bluetooth devices to disk")
    }

    private func autoSweepIfNeeded(reason: String, force: Bool = false) {
        guard availabilityState == .ready, !isScanning else {
            return
        }

        let shouldSweep = force || devices.isEmpty || lastScanDate == nil || isDataStale

        guard shouldSweep else {
            return
        }

        AppLog.info("bluetooth", "Starting automatic Bluetooth sweep because \(reason)")
        refresh()
    }

    private var isDataStale: Bool {
        guard let lastScanDate else {
            return true
        }

        return Date().timeIntervalSince(lastScanDate) >= autoSweepInterval
    }
}

extension BluetoothScannerController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        AppLog.info(
            "bluetooth",
            "CBCentralManager state callback received state=\(central.state.debugName) authorization=\(CBManager.authorization.debugName)"
        )
        updateAvailabilityState()

        if availabilityState == .ready {
            autoSweepIfNeeded(reason: "bluetooth state callback")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discoveryTime = Date()
        let device = Self.makeDevice(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI.intValue,
            seenAt: discoveryTime
        )

        integrate(device)

        if loggedDeviceIdentifiers.insert(device.id).inserted {
            AppLog.debug(
                "bluetooth",
                "Discovered device name=\(device.name) typeGuess=\(device.typeGuess) identifier=\(device.identifierString) signal=\(device.signalStrength) connectable=\(device.connectableLabel) services=\(device.serviceSummary) manufacturer=\(device.manufacturerSummary)"
            )
        }
    }
}

enum BluetoothDeviceIdentity {
    nonisolated static let fallbackTypeGuess = "Type not obvious"
    nonisolated static let noManufacturerSummary = "None advertised"

    nonisolated static func inferType(
        from displayName: String,
        localName: String?,
        manufacturerData: Data?,
        serviceUUIDs: [CBUUID]
    ) -> String {
        let lowercasedName = displayName.lowercased()

        if lowercasedName.contains("airpods") {
            return "Apple AirPods"
        }

        if lowercasedName.contains("beats") {
            return "Beats audio device"
        }

        if lowercasedName.contains("apple watch") {
            return "Apple Watch"
        }

        if lowercasedName.contains("iphone") || lowercasedName.contains("ipad") || lowercasedName.contains("macbook") {
            return "Apple device"
        }

        if lowercasedName.contains("jbl") {
            return "JBL audio device"
        }

        if lowercasedName.contains("bose") {
            return "Bose audio device"
        }

        if lowercasedName.contains("sony") {
            return "Sony accessory"
        }

        if lowercasedName.contains("garmin") {
            return "Garmin wearable"
        }

        if lowercasedName.contains("fitbit") {
            return "Fitbit wearable"
        }

        if lowercasedName.contains("tile") {
            return "Bluetooth tracker"
        }

        if lowercasedName.contains("logi") || lowercasedName.contains("logitech") {
            return "Logitech accessory"
        }

        if let companyIdentifier = companyIdentifier(from: manufacturerData) {
            if companyIdentifier == 0x004C {
                return "Apple accessory"
            }

            if let companyName = companyName(for: companyIdentifier), localName != nil {
                return "\(companyName) accessory"
            }

            return String(format: "Company 0x%04X device", companyIdentifier)
        }

        let uppercasedServices = Set(serviceUUIDs.map { $0.uuidString.uppercased() })

        if uppercasedServices.contains("1812") {
            return "Input device"
        }

        if uppercasedServices.contains("180D") {
            return "Heart rate sensor"
        }

        if uppercasedServices.contains("180F") {
            return "Battery-reporting accessory"
        }

        if localName != nil {
            return "Named accessory"
        }

        return fallbackTypeGuess
    }

    nonisolated static func manufacturerSummary(from manufacturerData: Data?) -> String {
        guard let manufacturerData else {
            return noManufacturerSummary
        }

        if let companyIdentifier = companyIdentifier(from: manufacturerData) {
            if let companyName = companyName(for: companyIdentifier) {
                return "\(companyName) • \(manufacturerData.count) bytes"
            }

            return String(format: "Company 0x%04X • %d bytes", companyIdentifier, manufacturerData.count)
        }

        return "\(manufacturerData.count) bytes"
    }

    nonisolated static func companyName(for identifier: UInt16) -> String? {
        switch identifier {
        case 0x004C:
            return "Apple"
        case 0x0006:
            return "Microsoft"
        case 0x000F:
            return "Broadcom"
        case 0x0044:
            return "Sony"
        case 0x0059:
            return "Nordic"
        case 0x0075:
            return "Samsung"
        case 0x00E0:
            return "Google"
        case 0x0131:
            return "Bose"
        case 0x0133:
            return "Tile"
        case 0x013D:
            return "Logitech"
        case 0x01A9:
            return "Garmin"
        case 0x01B5:
            return "Fitbit"
        default:
            return nil
        }
    }

    nonisolated static func companyIdentifier(from manufacturerData: Data?) -> UInt16? {
        guard let manufacturerData, manufacturerData.count >= 2 else {
            return nil
        }

        let bytes = [UInt8](manufacturerData.prefix(2))
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }
}

enum BluetoothServiceCatalog {
    nonisolated static func summary(for serviceUUIDs: [CBUUID]) -> String {
        guard !serviceUUIDs.isEmpty else {
            return "None advertised"
        }

        let labels = serviceUUIDs
            .map(label(for:))
            .sorted()

        if labels.count <= 2 {
            return labels.joined(separator: ", ")
        }

        let leadingLabels = labels.prefix(2).joined(separator: ", ")
        return "\(leadingLabels) +\(labels.count - 2) more"
    }

    nonisolated private static func label(for serviceUUID: CBUUID) -> String {
        switch serviceUUID.uuidString.uppercased() {
        case "1800":
            return "Generic Access"
        case "1801":
            return "Generic Attribute"
        case "1805":
            return "Current Time"
        case "180A":
            return "Device Info"
        case "180D":
            return "Heart Rate"
        case "180F":
            return "Battery"
        case "1812":
            return "Human Interface"
        case "181A":
            return "Environmental"
        default:
            return serviceUUID.uuidString.uppercased()
        }
    }
}

private extension BluetoothAvailabilityState {
    var debugName: String {
        switch self {
        case .unknown:
            return "unknown"
        case .permissionNotDetermined:
            return "permissionNotDetermined"
        case .permissionDenied:
            return "permissionDenied"
        case .permissionRestricted:
            return "permissionRestricted"
        case .poweredOff:
            return "poweredOff"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .ready:
            return "ready"
        }
    }
}

private extension CBManagerAuthorization {
    var debugName: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .allowedAlways:
            return "allowedAlways"
        @unknown default:
            return "unknown"
        }
    }
}

private extension CBManagerState {
    var debugName: String {
        switch self {
        case .unknown:
            return "unknown"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case .poweredOff:
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        @unknown default:
            return "unknownFuture"
        }
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
