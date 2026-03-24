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
    nonisolated static func inferRouter(from ssid: String, bssid: String?, vendorName: String? = nil) -> String {
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

        if let vendorName {
            return "\(vendorName) access point"
        }

        if bssid == nil {
            return "Grant location access to reveal the BSSID"
        }

        return "Model not advertised"
    }
}

enum WiFiVendorCatalog {
    nonisolated static func vendorName(for bssid: String?) -> String? {
        guard let bssid else {
            return nil
        }

        let normalizedPrefix = bssid
            .uppercased()
            .replacingOccurrences(of: "-", with: ":")
            .split(separator: ":")
            .prefix(3)
            .joined(separator: ":")

        guard normalizedPrefix.count == 8 else {
            return nil
        }

        return ouiVendors[normalizedPrefix]
    }

    nonisolated private static let ouiVendors: [String: String] = [
        "04:18:D6": "Ubiquiti",
        "18:E8:29": "Ubiquiti",
        "24:5A:4C": "Ubiquiti",
        "24:A4:3C": "Ubiquiti",
        "68:D7:9A": "Ubiquiti",
        "74:83:C2": "Ubiquiti",
        "78:8A:20": "Ubiquiti",
        "80:2A:A8": "Ubiquiti",
        "9C:05:D6": "Ubiquiti",
        "B4:FB:E4": "Ubiquiti",
        "CC:2D:E0": "Ubiquiti",
        "D8:B3:70": "Ubiquiti",
        "DC:9F:DB": "Ubiquiti",
        "E0:63:DA": "Ubiquiti",
        "34:31:C4": "AVM",
        "38:10:D5": "AVM",
        "50:7E:5D": "AVM",
        "54:E6:FC": "AVM",
        "84:16:F9": "AVM",
        "18:A6:F7": "TP-Link",
        "50:C7:BF": "TP-Link",
        "D8:0D:17": "TP-Link",
        "F4:EC:38": "TP-Link",
        "C0:56:27": "NETGEAR",
        "9C:3D:CF": "NETGEAR",
        "00:22:3F": "D-Link",
        "B0:C5:54": "D-Link",
        "00:25:9C": "Linksys",
        "C0:56:E3": "Linksys",
        "04:DB:56": "Apple",
        "3C:15:C2": "Apple",
        "40:A6:D9": "Apple",
        "58:55:CA": "Apple",
        "68:96:7B": "Apple",
        "84:38:35": "Apple",
        "90:72:40": "Apple",
        "A4:5E:60": "Apple",
        "CC:20:E8": "Apple",
        "F0:18:98": "Apple",
        "44:65:0D": "Cisco",
        "70:3A:CB": "Cisco",
        "6C:5A:B0": "Google",
        "F4:F5:D8": "Google",
        "2C:AB:00": "HUAWEI",
        "9C:B7:0D": "HUAWEI",
    ]
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
    case wifiHistory = "wifi-history.json"
    case bluetoothHistory = "bluetooth-history.json"
    case wifiAlerts = "wifi-alerts.json"
    case bluetoothAlerts = "bluetooth-alerts.json"
    case savedPlaces = "saved-places.json"
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
