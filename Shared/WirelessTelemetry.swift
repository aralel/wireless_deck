//
//  WirelessTelemetry.swift
//  router monitor
//
//  Created by Codex on 23.03.2026.
//

import Combine
import Foundation
import UserNotifications

enum WirelessChangeKind: String, Codable, CaseIterable, Hashable, Sendable {
    case new
    case missing
    case stronger
    case weaker
    case moved

    var label: String {
        switch self {
        case .new:
            return "New"
        case .missing:
            return "Missing"
        case .stronger:
            return "Stronger"
        case .weaker:
            return "Weaker"
        case .moved:
            return "Moved"
        }
    }
}

struct WirelessItemChange: Equatable, Sendable {
    let kinds: [WirelessChangeKind]
    let signalDelta: Int?
    let note: String?

    var primaryKind: WirelessChangeKind? {
        kinds.first
    }

    var summary: String {
        var fragments = kinds.map(\.label)

        if let signalDelta {
            let direction = signalDelta > 0 ? "+" : ""
            fragments.append("\(direction)\(signalDelta) dBm")
        }

        if let note, !note.isEmpty {
            fragments.append(note)
        }

        return fragments.joined(separator: " • ")
    }
}

struct WirelessDiffDigest: Equatable, Sendable {
    let newCount: Int
    let missingCount: Int
    let strongerCount: Int
    let weakerCount: Int
    let movedCount: Int
    let itemChanges: [String: WirelessItemChange]

    static let empty = WirelessDiffDigest(
        newCount: 0,
        missingCount: 0,
        strongerCount: 0,
        weakerCount: 0,
        movedCount: 0,
        itemChanges: [:]
    )

    var hasAnyChanges: Bool {
        newCount + missingCount + strongerCount + weakerCount + movedCount > 0
    }

    var summaryLine: String {
        guard hasAnyChanges else {
            return "No meaningful change since the previous capture."
        }

        let segments: [(Int, String)] = [
            (newCount, "new"),
            (missingCount, "missing"),
            (strongerCount, "stronger"),
            (weakerCount, "weaker"),
            (movedCount, "moved"),
        ]

        return segments
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: " • ")
    }
}

struct SignalTimelineSample: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let signalStrength: Int
    let sampleSource: String

    init(id: UUID = UUID(), timestamp: Date, signalStrength: Int, sampleSource: String) {
        self.id = id
        self.timestamp = timestamp
        self.signalStrength = signalStrength
        self.sampleSource = sampleSource
    }

    var signalPercent: Int {
        WiFiSignalPresentation.percent(forRSSI: signalStrength)
    }
}

struct WiFiHistoryRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let capturedAt: Date
    let networks: [WiFiNetwork]

    init(id: UUID = UUID(), capturedAt: Date, networks: [WiFiNetwork]) {
        self.id = id
        self.capturedAt = capturedAt
        self.networks = networks
    }
}

struct BluetoothHistoryRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let capturedAt: Date
    let devices: [BluetoothDevice]

    init(id: UUID = UUID(), capturedAt: Date, devices: [BluetoothDevice]) {
        self.id = id
        self.capturedAt = capturedAt
        self.devices = devices
    }
}

struct SavedPlace: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    let wifiNetworks: [WiFiNetwork]
    let bluetoothDevices: [BluetoothDevice]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        wifiNetworks: [WiFiNetwork],
        bluetoothDevices: [BluetoothDevice]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.wifiNetworks = wifiNetworks
        self.bluetoothDevices = bluetoothDevices
    }
}

struct WiFiWatchAlert: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let ssid: String
    let bssid: String?
    var displayName: String
    var signalThreshold: Int
    var notifyOnAppear: Bool
    var notifyOnDisappear: Bool
    var notifyOnSignalDrop: Bool
    var lastPresence: Bool
    var lastBelowThreshold: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        ssid: String,
        bssid: String?,
        displayName: String,
        signalThreshold: Int,
        notifyOnAppear: Bool = true,
        notifyOnDisappear: Bool = true,
        notifyOnSignalDrop: Bool = true,
        lastPresence: Bool,
        lastBelowThreshold: Bool,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ssid = ssid
        self.bssid = bssid
        self.displayName = displayName
        self.signalThreshold = signalThreshold
        self.notifyOnAppear = notifyOnAppear
        self.notifyOnDisappear = notifyOnDisappear
        self.notifyOnSignalDrop = notifyOnSignalDrop
        self.lastPresence = lastPresence
        self.lastBelowThreshold = lastBelowThreshold
        self.createdAt = createdAt
    }

    func matches(_ network: WiFiNetwork) -> Bool {
        if let bssid {
            return network.bssid == bssid
        }

        return network.ssid.caseInsensitiveCompare(ssid) == .orderedSame
    }
}

struct BluetoothWatchAlert: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let identifierString: String
    var displayName: String
    var signalThreshold: Int
    var notifyOnAppear: Bool
    var notifyOnDisappear: Bool
    var notifyOnSignalDrop: Bool
    var lastPresence: Bool
    var lastBelowThreshold: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        identifierString: String,
        displayName: String,
        signalThreshold: Int,
        notifyOnAppear: Bool = true,
        notifyOnDisappear: Bool = true,
        notifyOnSignalDrop: Bool = true,
        lastPresence: Bool,
        lastBelowThreshold: Bool,
        createdAt: Date = .now
    ) {
        self.id = id
        self.identifierString = identifierString
        self.displayName = displayName
        self.signalThreshold = signalThreshold
        self.notifyOnAppear = notifyOnAppear
        self.notifyOnDisappear = notifyOnDisappear
        self.notifyOnSignalDrop = notifyOnSignalDrop
        self.lastPresence = lastPresence
        self.lastBelowThreshold = lastBelowThreshold
        self.createdAt = createdAt
    }

    func matches(_ device: BluetoothDevice) -> Bool {
        device.identifierString == identifierString
    }
}

enum WirelessHealthTone: String, Codable, Sendable {
    case healthy
    case busy
    case crowded
    case noisy
    case unstable
    case waiting

    var title: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .busy:
            return "Busy"
        case .crowded:
            return "Crowded"
        case .noisy:
            return "Noisy"
        case .unstable:
            return "Unstable"
        case .waiting:
            return "Waiting"
        }
    }
}

struct WirelessHealthReport: Equatable, Sendable {
    let score: Int
    let tone: WirelessHealthTone
    let headline: String
    let summary: String
    let highlights: [String]

    static let waiting = WirelessHealthReport(
        score: 0,
        tone: .waiting,
        headline: "Waiting for enough telemetry",
        summary: "Run a scan or sweep to score the nearby wireless environment.",
        highlights: []
    )
}

@MainActor
final class WirelessTelemetryStore: ObservableObject {
    @Published private(set) var wifiHistory: [WiFiHistoryRecord] = []
    @Published private(set) var bluetoothHistory: [BluetoothHistoryRecord] = []
    @Published private(set) var wifiAlerts: [WiFiWatchAlert] = []
    @Published private(set) var bluetoothAlerts: [BluetoothWatchAlert] = []
    @Published private(set) var savedPlaces: [SavedPlace] = []
    @Published private(set) var latestWiFiDiff: WirelessDiffDigest = .empty
    @Published private(set) var latestBluetoothDiff: WirelessDiffDigest = .empty
    @Published private(set) var wifiHealth: WirelessHealthReport = .waiting
    @Published private(set) var bluetoothHealth: WirelessHealthReport = .waiting

    private let historyLimit = 160
    private let bluetoothHistoryLimit = 220
    private let notificationCenter = UNUserNotificationCenter.current()

    init() {
        restore()
        recalculatePublishedState()
    }

    func bootstrap(
        wifiNetworks: [WiFiNetwork],
        bluetoothDevices: [BluetoothDevice]
    ) {
        if wifiHistory.isEmpty && !wifiNetworks.isEmpty {
            wifiHealth = Self.makeWiFiHealth(from: wifiNetworks)
        }

        if bluetoothHistory.isEmpty && !bluetoothDevices.isEmpty {
            bluetoothHealth = Self.makeBluetoothHealth(from: bluetoothDevices)
        }
    }

    func recordWiFiScan(_ networks: [WiFiNetwork], at capturedAt: Date) {
        let previousNetworks = wifiHistory.last?.networks ?? []
        wifiHistory.append(WiFiHistoryRecord(capturedAt: capturedAt, networks: networks))
        wifiHistory = Array(wifiHistory.suffix(historyLimit))
        latestWiFiDiff = Self.makeWiFiDiff(previous: previousNetworks, current: networks)
        wifiHealth = Self.makeWiFiHealth(from: networks)
        evaluateWiFiAlerts(with: networks)
        persistWiFiHistory()
        persistWiFiAlerts()
    }

    func recordBluetoothSweep(_ devices: [BluetoothDevice], at capturedAt: Date) {
        let previousDevices = bluetoothHistory.last?.devices ?? []
        bluetoothHistory.append(BluetoothHistoryRecord(capturedAt: capturedAt, devices: devices))
        bluetoothHistory = Array(bluetoothHistory.suffix(bluetoothHistoryLimit))
        latestBluetoothDiff = Self.makeBluetoothDiff(previous: previousDevices, current: devices)
        bluetoothHealth = Self.makeBluetoothHealth(from: devices)
        evaluateBluetoothAlerts(with: devices)
        persistBluetoothHistory()
        persistBluetoothAlerts()
    }

    func addAlert(for network: WiFiNetwork, signalThreshold: Int) {
        guard !wifiAlerts.contains(where: { $0.matches(network) }) else {
            return
        }

        wifiAlerts.insert(
            WiFiWatchAlert(
                ssid: network.ssid,
                bssid: network.bssid,
                displayName: network.ssid,
                signalThreshold: signalThreshold,
                lastPresence: true,
                lastBelowThreshold: network.signalStrength <= signalThreshold
            ),
            at: 0
        )
        persistWiFiAlerts()
        requestNotificationPermissionIfNeeded()
        AppLog.info("alerts", "Started watching Wi-Fi network \(network.ssid) threshold=\(signalThreshold)")
    }

    func removeAlert(for network: WiFiNetwork) {
        wifiAlerts.removeAll(where: { $0.matches(network) })
        persistWiFiAlerts()
        AppLog.info("alerts", "Removed Wi-Fi watch for \(network.ssid)")
    }

    func alert(for network: WiFiNetwork) -> WiFiWatchAlert? {
        wifiAlerts.first(where: { $0.matches(network) })
    }

    func addAlert(for device: BluetoothDevice, signalThreshold: Int) {
        guard !bluetoothAlerts.contains(where: { $0.matches(device) }) else {
            return
        }

        bluetoothAlerts.insert(
            BluetoothWatchAlert(
                identifierString: device.identifierString,
                displayName: device.name,
                signalThreshold: signalThreshold,
                lastPresence: true,
                lastBelowThreshold: device.signalStrength <= signalThreshold
            ),
            at: 0
        )
        persistBluetoothAlerts()
        requestNotificationPermissionIfNeeded()
        AppLog.info("alerts", "Started watching Bluetooth device \(device.identifierString) threshold=\(signalThreshold)")
    }

    func removeAlert(for device: BluetoothDevice) {
        bluetoothAlerts.removeAll(where: { $0.matches(device) })
        persistBluetoothAlerts()
        AppLog.info("alerts", "Removed Bluetooth watch for \(device.identifierString)")
    }

    func alert(for device: BluetoothDevice) -> BluetoothWatchAlert? {
        bluetoothAlerts.first(where: { $0.matches(device) })
    }

    func savePlace(
        named name: String,
        wifiNetworks: [WiFiNetwork],
        bluetoothDevices: [BluetoothDevice]
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        savedPlaces.insert(
            SavedPlace(
                name: trimmedName,
                wifiNetworks: wifiNetworks,
                bluetoothDevices: bluetoothDevices
            ),
            at: 0
        )
        persistSavedPlaces()
        AppLog.info("places", "Saved baseline place \(trimmedName) wifiNetworks=\(wifiNetworks.count) bluetoothDevices=\(bluetoothDevices.count)")
    }

    func deletePlace(_ place: SavedPlace) {
        savedPlaces.removeAll(where: { $0.id == place.id })
        persistSavedPlaces()
        AppLog.info("places", "Deleted saved place \(place.name)")
    }

    func compareWiFi(current networks: [WiFiNetwork], to place: SavedPlace?) -> WirelessDiffDigest {
        guard let place else {
            return .empty
        }

        return Self.makeWiFiDiff(previous: place.wifiNetworks, current: networks)
    }

    func compareBluetooth(current devices: [BluetoothDevice], to place: SavedPlace?) -> WirelessDiffDigest {
        guard let place else {
            return .empty
        }

        return Self.makeBluetoothDiff(previous: place.bluetoothDevices, current: devices)
    }

    func wifiTimeline(for network: WiFiNetwork, limit: Int = 30) -> [SignalTimelineSample] {
        let key = network.historyKey
        return wifiHistory
            .suffix(limit)
            .compactMap { record in
                guard let matched = record.networks.first(where: { $0.historyKey == key }) else {
                    return nil
                }

                return SignalTimelineSample(
                    timestamp: record.capturedAt,
                    signalStrength: matched.signalStrength,
                    sampleSource: "scan"
                )
            }
    }

    func bluetoothTimeline(for device: BluetoothDevice, limit: Int = 36) -> [SignalTimelineSample] {
        let key = device.historyKey
        return bluetoothHistory
            .suffix(limit)
            .compactMap { record in
                guard let matched = record.devices.first(where: { $0.historyKey == key }) else {
                    return nil
                }

                return SignalTimelineSample(
                    timestamp: record.capturedAt,
                    signalStrength: matched.signalStrength,
                    sampleSource: "sweep"
                )
            }
    }

    func change(for network: WiFiNetwork) -> WirelessItemChange? {
        latestWiFiDiff.itemChanges[network.historyKey]
    }

    func change(for device: BluetoothDevice) -> WirelessItemChange? {
        latestBluetoothDiff.itemChanges[device.historyKey]
    }

    private func restore() {
        wifiHistory = RadarCacheStore.load([WiFiHistoryRecord].self, for: .wifiHistory) ?? []
        bluetoothHistory = RadarCacheStore.load([BluetoothHistoryRecord].self, for: .bluetoothHistory) ?? []
        wifiAlerts = RadarCacheStore.load([WiFiWatchAlert].self, for: .wifiAlerts) ?? []
        bluetoothAlerts = RadarCacheStore.load([BluetoothWatchAlert].self, for: .bluetoothAlerts) ?? []
        savedPlaces = RadarCacheStore.load([SavedPlace].self, for: .savedPlaces) ?? []
    }

    private func recalculatePublishedState() {
        let previousWiFi = wifiHistory.dropLast().last?.networks ?? []
        let currentWiFi = wifiHistory.last?.networks ?? []
        latestWiFiDiff = Self.makeWiFiDiff(previous: previousWiFi, current: currentWiFi)
        wifiHealth = Self.makeWiFiHealth(from: currentWiFi)

        let previousBluetooth = bluetoothHistory.dropLast().last?.devices ?? []
        let currentBluetooth = bluetoothHistory.last?.devices ?? []
        latestBluetoothDiff = Self.makeBluetoothDiff(previous: previousBluetooth, current: currentBluetooth)
        bluetoothHealth = Self.makeBluetoothHealth(from: currentBluetooth)
    }

    private func persistWiFiHistory() {
        RadarCacheStore.save(wifiHistory, for: .wifiHistory)
    }

    private func persistBluetoothHistory() {
        RadarCacheStore.save(bluetoothHistory, for: .bluetoothHistory)
    }

    private func persistWiFiAlerts() {
        RadarCacheStore.save(wifiAlerts, for: .wifiAlerts)
    }

    private func persistBluetoothAlerts() {
        RadarCacheStore.save(bluetoothAlerts, for: .bluetoothAlerts)
    }

    private func persistSavedPlaces() {
        RadarCacheStore.save(savedPlaces, for: .savedPlaces)
    }

    private func requestNotificationPermissionIfNeeded() {
        Task {
            do {
                let settings = await notificationCenter.notificationSettings()

                if settings.authorizationStatus == .notDetermined {
                    let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                    AppLog.info("alerts", "Notification permission request completed granted=\(granted)")
                }
            } catch {
                AppLog.warning("alerts", "Notification permission request failed: \(error.localizedDescription)")
            }
        }
    }

    private func evaluateWiFiAlerts(with networks: [WiFiNetwork]) {
        guard !wifiAlerts.isEmpty else {
            return
        }

        for index in wifiAlerts.indices {
            let matchedNetwork = networks.first(where: { wifiAlerts[index].matches($0) })
            let isPresent = matchedNetwork != nil

            if wifiAlerts[index].notifyOnAppear, !wifiAlerts[index].lastPresence, isPresent {
                deliverNotification(
                    title: "\(wifiAlerts[index].displayName) is back",
                    body: "The watched Wi-Fi network is visible again nearby."
                )
            }

            if wifiAlerts[index].notifyOnDisappear, wifiAlerts[index].lastPresence, !isPresent {
                deliverNotification(
                    title: "\(wifiAlerts[index].displayName) disappeared",
                    body: "The watched Wi-Fi network was present before and is missing from the latest scan."
                )
            }

            if let matchedNetwork {
                let isBelowThreshold = matchedNetwork.signalStrength <= wifiAlerts[index].signalThreshold

                if wifiAlerts[index].notifyOnSignalDrop, !wifiAlerts[index].lastBelowThreshold, isBelowThreshold {
                    deliverNotification(
                        title: "\(wifiAlerts[index].displayName) dropped in strength",
                        body: "Latest signal is \(matchedNetwork.signalStrength) dBm, below your threshold of \(wifiAlerts[index].signalThreshold) dBm."
                    )
                }

                wifiAlerts[index].lastBelowThreshold = isBelowThreshold
            } else {
                wifiAlerts[index].lastBelowThreshold = false
            }

            wifiAlerts[index].lastPresence = isPresent
        }
    }

    private func evaluateBluetoothAlerts(with devices: [BluetoothDevice]) {
        guard !bluetoothAlerts.isEmpty else {
            return
        }

        for index in bluetoothAlerts.indices {
            let matchedDevice = devices.first(where: { bluetoothAlerts[index].matches($0) })
            let isPresent = matchedDevice != nil

            if bluetoothAlerts[index].notifyOnAppear, !bluetoothAlerts[index].lastPresence, isPresent {
                deliverNotification(
                    title: "\(bluetoothAlerts[index].displayName) is back",
                    body: "The watched Bluetooth device is advertising again."
                )
            }

            if bluetoothAlerts[index].notifyOnDisappear, bluetoothAlerts[index].lastPresence, !isPresent {
                deliverNotification(
                    title: "\(bluetoothAlerts[index].displayName) disappeared",
                    body: "The watched Bluetooth device is missing from the latest sweep."
                )
            }

            if let matchedDevice {
                let isBelowThreshold = matchedDevice.signalStrength <= bluetoothAlerts[index].signalThreshold

                if bluetoothAlerts[index].notifyOnSignalDrop, !bluetoothAlerts[index].lastBelowThreshold, isBelowThreshold {
                    deliverNotification(
                        title: "\(bluetoothAlerts[index].displayName) drifted away",
                        body: "Latest signal is \(matchedDevice.signalStrength) dBm, below your threshold of \(bluetoothAlerts[index].signalThreshold) dBm."
                    )
                }

                bluetoothAlerts[index].lastBelowThreshold = isBelowThreshold
            } else {
                bluetoothAlerts[index].lastBelowThreshold = false
            }

            bluetoothAlerts[index].lastPresence = isPresent
        }
    }

    private func deliverNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wireless-deck-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error {
                AppLog.warning("alerts", "Failed to deliver notification \(title): \(error.localizedDescription)")
            }
        }
        AppLog.info("alerts", "Delivered alert notification title=\(title)")
    }

    static func makeWiFiDiff(previous: [WiFiNetwork], current: [WiFiNetwork]) -> WirelessDiffDigest {
        let previousMap = Dictionary(uniqueKeysWithValues: previous.map { ($0.historyKey, $0) })
        let currentMap = Dictionary(uniqueKeysWithValues: current.map { ($0.historyKey, $0) })
        var itemChanges: [String: WirelessItemChange] = [:]
        var newCount = 0
        var missingCount = 0
        var strongerCount = 0
        var weakerCount = 0
        var movedCount = 0

        let allKeys = Set(previousMap.keys).union(currentMap.keys)

        for key in allKeys {
            switch (previousMap[key], currentMap[key]) {
            case (nil, let currentNetwork?):
                itemChanges[key] = WirelessItemChange(kinds: [.new], signalDelta: nil, note: currentNetwork.vendorName ?? nil)
                newCount += 1
            case (let previousNetwork?, nil):
                itemChanges[key] = WirelessItemChange(kinds: [.missing], signalDelta: nil, note: previousNetwork.vendorName ?? nil)
                missingCount += 1
            case (let previousNetwork?, let currentNetwork?):
                var kinds: [WirelessChangeKind] = []
                let signalDelta = currentNetwork.signalStrength - previousNetwork.signalStrength

                if signalDelta >= 6 {
                    kinds.append(.stronger)
                    strongerCount += 1
                } else if signalDelta <= -6 {
                    kinds.append(.weaker)
                    weakerCount += 1
                }

                if currentNetwork.channel != previousNetwork.channel || currentNetwork.band != previousNetwork.band {
                    kinds.append(.moved)
                    movedCount += 1
                }

                if !kinds.isEmpty {
                    let movementNote: String?
                    if currentNetwork.channel != previousNetwork.channel || currentNetwork.band != previousNetwork.band {
                        movementNote = "Ch \(previousNetwork.channel) -> \(currentNetwork.channel)"
                    } else {
                        movementNote = nil
                    }

                    itemChanges[key] = WirelessItemChange(
                        kinds: kinds,
                        signalDelta: signalDelta,
                        note: movementNote
                    )
                }
            case (nil, nil):
                break
            }
        }

        return WirelessDiffDigest(
            newCount: newCount,
            missingCount: missingCount,
            strongerCount: strongerCount,
            weakerCount: weakerCount,
            movedCount: movedCount,
            itemChanges: itemChanges
        )
    }

    static func makeBluetoothDiff(previous: [BluetoothDevice], current: [BluetoothDevice]) -> WirelessDiffDigest {
        let previousMap = Dictionary(uniqueKeysWithValues: previous.map { ($0.historyKey, $0) })
        let currentMap = Dictionary(uniqueKeysWithValues: current.map { ($0.historyKey, $0) })
        var itemChanges: [String: WirelessItemChange] = [:]
        var newCount = 0
        var missingCount = 0
        var strongerCount = 0
        var weakerCount = 0
        var movedCount = 0

        let allKeys = Set(previousMap.keys).union(currentMap.keys)

        for key in allKeys {
            switch (previousMap[key], currentMap[key]) {
            case (nil, let currentDevice?):
                itemChanges[key] = WirelessItemChange(kinds: [.new], signalDelta: nil, note: currentDevice.typeGuess)
                newCount += 1
            case (let previousDevice?, nil):
                itemChanges[key] = WirelessItemChange(kinds: [.missing], signalDelta: nil, note: previousDevice.typeGuess)
                missingCount += 1
            case (let previousDevice?, let currentDevice?):
                var kinds: [WirelessChangeKind] = []
                let signalDelta = currentDevice.signalStrength - previousDevice.signalStrength

                if signalDelta >= 6 {
                    kinds.append(.stronger)
                    strongerCount += 1
                } else if signalDelta <= -6 {
                    kinds.append(.weaker)
                    weakerCount += 1
                }

                if currentDevice.proximityBucket != previousDevice.proximityBucket {
                    kinds.append(.moved)
                    movedCount += 1
                }

                if !kinds.isEmpty {
                    let movementNote: String?
                    if currentDevice.proximityBucket != previousDevice.proximityBucket {
                        movementNote = "\(previousDevice.proximitySummary) -> \(currentDevice.proximitySummary)"
                    } else {
                        movementNote = nil
                    }

                    itemChanges[key] = WirelessItemChange(
                        kinds: kinds,
                        signalDelta: signalDelta,
                        note: movementNote
                    )
                }
            case (nil, nil):
                break
            }
        }

        return WirelessDiffDigest(
            newCount: newCount,
            missingCount: missingCount,
            strongerCount: strongerCount,
            weakerCount: weakerCount,
            movedCount: movedCount,
            itemChanges: itemChanges
        )
    }

    static func makeWiFiHealth(from networks: [WiFiNetwork]) -> WirelessHealthReport {
        guard !networks.isEmpty else {
            return .waiting
        }

        let currentNetwork = networks.first(where: \.isCurrentNetwork)
        let strongestNetwork = networks.max(by: { $0.signalStrength < $1.signalStrength })
        let primaryNetwork = currentNetwork ?? strongestNetwork

        let averageNoise = if networks.isEmpty {
            -92
        } else {
            Int(networks.map(\.noise).reduce(0, +) / networks.count)
        }
        let snr = primaryNetwork.map { $0.signalStrength - averageNoise } ?? 0
        let crowded24 = networks.filter { $0.band == "2.4 GHz" }.count
        let uniqueChannels24 = Set(networks.filter { $0.band == "2.4 GHz" }.map(\.channel)).count
        let duplicatedSSIDs = Dictionary(grouping: networks, by: { $0.ssid.lowercased() }).values.filter { $0.count > 1 }.count

        var score = 100

        if crowded24 >= 10 {
            score -= 24
        } else if crowded24 >= 6 {
            score -= 14
        } else if crowded24 >= 3 {
            score -= 6
        }

        if uniqueChannels24 <= 2 && crowded24 >= 4 {
            score -= 12
        }

        if snr < 18 {
            score -= 24
        } else if snr < 26 {
            score -= 12
        } else if snr < 32 {
            score -= 6
        }

        if let currentNetwork, currentNetwork.signalStrength <= -72 {
            score -= 16
        }

        if duplicatedSSIDs >= 3 {
            score -= 8
        }

        score = max(18, min(score, 100))

        let tone: WirelessHealthTone
        switch score {
        case 82...:
            tone = .healthy
        case 68...:
            tone = .busy
        case 52...:
            tone = .crowded
        case 36...:
            tone = .noisy
        default:
            tone = .unstable
        }

        var highlights: [String] = []

        if let primaryNetwork {
            highlights.append("\(primaryNetwork.ssid) is the anchor network at \(primaryNetwork.signalStrength) dBm.")
        }

        if crowded24 > 0 {
            highlights.append("\(crowded24) nearby 2.4 GHz networks are competing across \(max(uniqueChannels24, 1)) channels.")
        }

        highlights.append("Estimated headroom is about \(snr) dB against average noise.")

        let headline: String
        let summary: String

        switch tone {
        case .healthy:
            headline = "The airspace looks healthy."
            summary = "Signal headroom is solid and channel crowding is under control, so this environment should feel stable."
        case .busy:
            headline = "The airspace looks busy but manageable."
            summary = "There is some crowding, especially on shared channels, but the strongest networks still have enough headroom."
        case .crowded:
            headline = "The Wi-Fi environment looks crowded."
            summary = "Multiple nearby access points are competing in the same space, so speed and consistency can dip during busy periods."
        case .noisy:
            headline = "The Wi-Fi environment looks noisy."
            summary = "Weak signal headroom or heavy 2.4 GHz overlap suggests interference will be noticeable."
        case .unstable:
            headline = "The Wi-Fi environment looks unstable."
            summary = "Low signal headroom combined with crowding means drops, retries, or erratic performance are likely."
        case .waiting:
            headline = "Waiting for enough telemetry"
            summary = "Run a scan to score the wireless environment."
        }

        return WirelessHealthReport(
            score: score,
            tone: tone,
            headline: headline,
            summary: summary,
            highlights: highlights
        )
    }

    static func makeBluetoothHealth(from devices: [BluetoothDevice]) -> WirelessHealthReport {
        guard !devices.isEmpty else {
            return WirelessHealthReport(
                score: 80,
                tone: .healthy,
                headline: "Bluetooth space looks calm.",
                summary: "No nearby advertisers were seen in the latest sweep, so the airspace is quiet right now.",
                highlights: ["Run another sweep if you expect a nearby device to appear."]
            )
        }

        let namedCount = devices.filter { $0.name != "Unnamed device" }.count
        let stableCount = devices.filter { $0.seenCount >= 4 }.count
        let veryStrongCount = devices.filter { $0.signalStrength >= -60 }.count
        var score = 100

        if devices.count >= 20 {
            score -= 24
        } else if devices.count >= 12 {
            score -= 12
        }

        if namedCount < devices.count / 2 {
            score -= 10
        }

        if stableCount < max(1, devices.count / 4) {
            score -= 12
        }

        if veryStrongCount >= 6 {
            score -= 10
        }

        score = max(24, min(score, 100))

        let tone: WirelessHealthTone
        switch score {
        case 82...:
            tone = .healthy
        case 66...:
            tone = .busy
        case 48...:
            tone = .crowded
        case 34...:
            tone = .noisy
        default:
            tone = .unstable
        }

        let highlights = [
            "\(devices.count) nearby advertisers in the latest sweep.",
            "\(stableCount) were seen repeatedly enough to look steady.",
            "\(namedCount) are broadcasting readable names."
        ]

        let headline: String
        let summary: String

        switch tone {
        case .healthy:
            headline = "Bluetooth space looks healthy."
            summary = "The device mix is readable and fairly stable, so finding and reconnecting devices should feel predictable."
        case .busy:
            headline = "Bluetooth space looks busy."
            summary = "There are enough nearby advertisers to keep the airspace active, but it still looks manageable."
        case .crowded:
            headline = "Bluetooth space looks crowded."
            summary = "A lot of nearby advertisers are competing for airtime, which can make discovery feel slower or noisier."
        case .noisy:
            headline = "Bluetooth space looks noisy."
            summary = "Many transient or unnamed advertisers are appearing, so nearby device discovery may feel messy."
        case .unstable:
            headline = "Bluetooth space looks unstable."
            summary = "The sweep is seeing a fast-changing or low-confidence set of nearby advertisers."
        case .waiting:
            headline = "Waiting for enough telemetry"
            summary = "Run a sweep to score the Bluetooth environment."
        }

        return WirelessHealthReport(
            score: score,
            tone: tone,
            headline: headline,
            summary: summary,
            highlights: highlights
        )
    }
}
