//
//  WiFiShared.swift
//  router monitor
//
//  Created by Codex on 22.03.2026.
//

import Foundation

enum WiFiPermissionState: Equatable {
    case servicesDisabled
    case notDetermined
    case denied
    case restricted
    case authorized
}

enum RouterIdentity {
    nonisolated static func inferRouter(from ssid: String, bssid: String?) -> String {
        let normalizedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedSSID = normalizedSSID.lowercased()

        if lowercasedSSID.hasPrefix("fritz!box") {
            return "AVM \(normalizedSSID)"
        }

        if lowercasedSSID.contains("fritz") {
            return "AVM FRITZ!Box router"
        }

        if lowercasedSSID.contains("vodafone homespot") {
            return "Vodafone Homespot access point"
        }

        if lowercasedSSID.contains("vodafone hotspot") {
            return "Vodafone public hotspot node"
        }

        if lowercasedSSID.contains("vodafone") {
            return "Vodafone-branded router"
        }

        if lowercasedSSID.contains("tp-link") {
            return "TP-Link router"
        }

        if lowercasedSSID.contains("d-link") || lowercasedSSID.contains("dlink") {
            return "D-Link router"
        }

        if lowercasedSSID.contains("netgear") {
            return "NETGEAR router"
        }

        if lowercasedSSID.contains("linksys") {
            return "Linksys router"
        }

        if lowercasedSSID.contains("moto") || lowercasedSSID.contains("iphone") || lowercasedSSID.contains("pixel") {
            return "Phone hotspot"
        }

        if bssid == nil {
            return "Grant location access to reveal the BSSID"
        }

        return "Model not advertised"
    }
}

enum WiFiSignalPresentation {
    nonisolated static func description(forRSSI signalStrength: Int) -> String {
        if signalStrength >= -55 {
            return "Excellent"
        }

        if signalStrength >= -67 {
            return "Good"
        }

        if signalStrength >= -75 {
            return "Fair"
        }

        if signalStrength >= -83 {
            return "Weak"
        }

        return "Very weak"
    }

    nonisolated static func percent(forRSSI signalStrength: Int) -> Int {
        let clampedSignal = max(-90, min(signalStrength, -30))
        return Int(round(Double(clampedSignal + 90) / 60.0 * 100.0))
    }

    nonisolated static func bars(forRSSI signalStrength: Int) -> Int {
        if signalStrength >= -55 {
            return 4
        }

        if signalStrength >= -67 {
            return 3
        }

        if signalStrength >= -75 {
            return 2
        }

        return 1
    }

    nonisolated static func percent(forNormalizedSignal signalStrength: Double) -> Int {
        let clampedSignal = max(0.0, min(signalStrength, 1.0))
        return Int(round(clampedSignal * 100.0))
    }

    nonisolated static func description(forPercent percent: Int) -> String {
        if percent >= 85 {
            return "Excellent"
        }

        if percent >= 65 {
            return "Good"
        }

        if percent >= 45 {
            return "Fair"
        }

        if percent >= 25 {
            return "Weak"
        }

        return "Very weak"
    }

    nonisolated static func bars(forPercent percent: Int) -> Int {
        if percent >= 80 {
            return 4
        }

        if percent >= 55 {
            return 3
        }

        if percent >= 30 {
            return 2
        }

        return 1
    }
}

struct WiFiScanSnapshot: Codable, Sendable {
    let networks: [WiFiNetwork]
    let lastScanDate: Date?
}

struct BluetoothScanSnapshot: Codable, Sendable {
    let devices: [BluetoothDevice]
    let lastScanDate: Date?
}

enum RadarCacheKey: String {
    case wifi = "wifi-snapshot.json"
    case bluetooth = "bluetooth-snapshot.json"
}

enum RadarCacheStore {
    nonisolated static func load<T: Decodable>(_ type: T.Type, for key: RadarCacheKey) -> T? {
        guard let fileURL = fileURL(for: key),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? decoder.decode(T.self, from: data)
    }

    nonisolated static func save<T: Encodable>(_ value: T, for key: RadarCacheKey) {
        guard let fileURL = fileURL(for: key),
              let data = try? encoder.encode(value) else {
            return
        }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    nonisolated private static func fileURL(for key: RadarCacheKey) -> URL? {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return applicationSupportURL?
            .appendingPathComponent("router monitor", isDirectory: true)
            .appendingPathComponent("Cache", isDirectory: true)
            .appendingPathComponent(key.rawValue, isDirectory: false)
    }

    nonisolated private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    nonisolated private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
