//
//  WiFiScanner.swift
//  router monitor
//
//  Created by Codex on 22.03.2026.
//

import Combine
import CoreLocation
import CoreWLAN
import Foundation

struct WiFiNetwork: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let ssid: String
    let bssid: String?
    let routerSummary: String
    let security: String
    let signalStrength: Int
    let noise: Int
    let channel: Int
    let band: String
    let isCurrentNetwork: Bool

    nonisolated var displayBSSID: String {
        bssid ?? "Hidden until location access is granted"
    }

    nonisolated var signalDescription: String {
        WiFiSignalPresentation.description(forRSSI: signalStrength)
    }

    nonisolated var signalPercent: Int {
        WiFiSignalPresentation.percent(forRSSI: signalStrength)
    }

    nonisolated var signalBars: Int {
        WiFiSignalPresentation.bars(forRSSI: signalStrength)
    }
}

@MainActor
final class WiFiScannerController: NSObject, ObservableObject {
    @Published private(set) var networks: [WiFiNetwork] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var permissionState: WiFiPermissionState = .notDetermined
    @Published private(set) var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let autoRefreshInterval: TimeInterval = 20

    var hasVisibleBSSIDs: Bool {
        networks.contains(where: { $0.bssid != nil })
    }

    var statusLine: String {
        switch permissionState {
        case .authorized:
            if isScanning {
                return "Scanning nearby access points..."
            }

            if let errorMessage {
                return errorMessage
            }

            if networks.isEmpty {
                return "Ready to scan nearby networks"
            }

            return "Nearby networks ready to explore"
        case .notDetermined:
            return "Grant location access to reveal nearby Wi-Fi details"
        case .denied:
            return "Location access is off for this app"
        case .restricted:
            return "Location access is restricted on this Mac"
        case .servicesDisabled:
            return "Location Services are currently turned off"
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        AppLog.info("scan", "Wi-Fi scanner initialized")
        restoreCachedSnapshot()
        updatePermissionState()
    }

    func prepare() {
        updatePermissionState()
        AppLog.debug("scan", "Preparing scanner with permissionState=\(permissionState.debugName) cachedNetworks=\(networks.count)")
        autoRefreshIfNeeded(reason: "prepare")
    }

    func requestLocationAccess() {
        updatePermissionState()
        AppLog.info("permissions", "Requesting location access with currentState=\(permissionState.debugName)")

        guard permissionState != .servicesDisabled else {
            errorMessage = "Location Services are turned off in System Settings."
            AppLog.warning("permissions", "Location access request blocked because services are disabled")
            return
        }

        locationManager.requestWhenInUseAuthorization()
    }

    func refresh() {
        guard !isScanning else {
            AppLog.debug("scan", "Refresh ignored because a Wi-Fi scan is already in progress")
            return
        }

        updatePermissionState()
        AppLog.info("scan", "Refresh requested with permissionState=\(permissionState.debugName)")

        guard permissionState == .authorized else {
            errorMessage = permissionErrorMessage
            AppLog.warning(
                "scan",
                "Scan blocked because permissionState=\(permissionState.debugName) error=\(permissionErrorMessage ?? "none") cachedNetworks=\(networks.count)"
            )
            return
        }

        isScanning = true
        errorMessage = nil
        AppLog.debug("scan", "Starting Wi-Fi scan")

        Task { [weak self] in
            guard let self else { return }

            do {
                let refreshedNetworks = try await Task.detached(priority: .userInitiated) {
                    try Self.loadNearbyNetworks()
                }
                .value

                networks = refreshedNetworks
                lastScanDate = .now
                errorMessage = nil
                persistSnapshot()
                AppLog.info("scan", "Scan completed successfully with \(refreshedNetworks.count) networks")
            } catch {
                errorMessage = Self.friendlyMessage(for: error)
                AppLog.error("scan", "Scan failed: \(Self.friendlyMessage(for: error)). Preserving \(networks.count) cached networks")
            }

            isScanning = false
        }
    }

    private var permissionErrorMessage: String? {
        switch permissionState {
        case .servicesDisabled:
            return "Turn on Location Services in System Settings to scan Wi-Fi."
        case .notDetermined:
            return "Allow location access to scan nearby Wi-Fi."
        case .denied:
            return "Enable location access for router monitor in System Settings."
        case .restricted:
            return "Location access is restricted for this Mac."
        case .authorized:
            return nil
        }
    }

    private func updatePermissionState() {
        let previousState = permissionState

        guard CLLocationManager.locationServicesEnabled() else {
            permissionState = .servicesDisabled
            if previousState != permissionState {
                AppLog.warning("permissions", "Location Services are disabled at the system level")
            }
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            permissionState = .notDetermined
        case .restricted:
            permissionState = .restricted
        case .denied:
            permissionState = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            permissionState = .authorized
        @unknown default:
            permissionState = .restricted
        }

        if previousState != permissionState {
            AppLog.info("permissions", "Permission state changed from \(previousState.debugName) to \(permissionState.debugName)")
        }
    }

    private func restoreCachedSnapshot() {
        guard let snapshot = RadarCacheStore.load(WiFiScanSnapshot.self, for: .wifi) else {
            return
        }

        networks = snapshot.networks
        lastScanDate = snapshot.lastScanDate
        AppLog.info("cache", "Loaded \(snapshot.networks.count) cached Wi-Fi networks from disk")
    }

    private func persistSnapshot() {
        RadarCacheStore.save(
            WiFiScanSnapshot(networks: networks, lastScanDate: lastScanDate),
            for: .wifi
        )
        AppLog.debug("cache", "Saved \(networks.count) Wi-Fi networks to disk")
    }

    private func autoRefreshIfNeeded(reason: String, force: Bool = false) {
        guard permissionState == .authorized, !isScanning else {
            return
        }

        let shouldRefresh = force || networks.isEmpty || lastScanDate == nil || isDataStale

        guard shouldRefresh else {
            return
        }

        AppLog.info("scan", "Starting automatic Wi-Fi scan because \(reason)")
        refresh()
    }

    private var isDataStale: Bool {
        guard let lastScanDate else {
            return true
        }

        return Date().timeIntervalSince(lastScanDate) >= autoRefreshInterval
    }

    nonisolated private static func loadNearbyNetworks() throws -> [WiFiNetwork] {
        let client = CWWiFiClient.shared()
        let defaultInterface = client.interface()
        let interfaceNames = client.interfaceNames() ?? []
        let fallbackInterface = interfaceNames
            .compactMap { client.interface(withName: $0) }
            .first

        guard let interface = defaultInterface ?? fallbackInterface else {
            AppLog.error(
                "scan",
                "No Wi-Fi interface is available. defaultInterface=nil interfaceNames=\(interfaceNames) sandboxed=\(AppRuntimeDiagnostics.isSandboxed) sandboxContainerID=\(AppRuntimeDiagnostics.sandboxContainerID ?? "<none>")"
            )
            throw ScanError.noInterface(interfaceNames: interfaceNames, sandboxed: AppRuntimeDiagnostics.isSandboxed)
        }

        AppLog.debug(
            "scan",
            "Using Wi-Fi interface name=\(interface.interfaceName ?? "<unknown>") defaultInterface=\(defaultInterface?.interfaceName ?? "nil") interfaceNames=\(interfaceNames)"
        )

        let currentSSID = interface.ssid()
        let currentBSSID = interface.bssid()
        let networks = try interface.scanForNetworks(withSSID: nil, includeHidden: false)
        AppLog.debug("scan", "CoreWLAN returned \(networks.count) raw networks currentSSID=\(currentSSID ?? "<none>") currentBSSID=\(currentBSSID ?? "<hidden>")")

        let mappedNetworks = networks
            .map { network in
                let ssid = network.ssid?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "<Hidden network>"
                let bssid = network.bssid?.lowercased()
                let channel = network.wlanChannel?.channelNumber ?? 0
                let band = bandLabel(for: network.wlanChannel?.channelBand)
                let isCurrentNetwork = ssid == currentSSID && (currentBSSID == nil || currentBSSID == bssid)

                return WiFiNetwork(
                    id: bssid ?? "\(ssid)-\(channel)-\(network.rssiValue)-\(network.noiseMeasurement)",
                    ssid: ssid,
                    bssid: bssid,
                    routerSummary: RouterIdentity.inferRouter(from: ssid, bssid: bssid),
                    security: securityLabel(for: network),
                    signalStrength: network.rssiValue,
                    noise: network.noiseMeasurement,
                    channel: channel,
                    band: band,
                    isCurrentNetwork: isCurrentNetwork
                )
            }
            .sorted { lhs, rhs in
                if lhs.signalStrength == rhs.signalStrength {
                    return lhs.ssid.localizedCaseInsensitiveCompare(rhs.ssid) == .orderedAscending
                }

                return lhs.signalStrength > rhs.signalStrength
            }

        let loggedNetworks = min(mappedNetworks.count, 60)
        for network in mappedNetworks.prefix(loggedNetworks) {
            AppLog.debug(
                "scan",
                "Network ssid=\(network.ssid) router=\(network.routerSummary) bssid=\(network.displayBSSID) signal=\(network.signalStrength) noise=\(network.noise) channel=\(network.channel) band=\(network.band) security=\(network.security) current=\(network.isCurrentNetwork)"
            )
        }

        if mappedNetworks.count > loggedNetworks {
            AppLog.debug("scan", "Skipped logging \(mappedNetworks.count - loggedNetworks) additional networks to keep the debug console readable")
        }

        return mappedNetworks
    }

    nonisolated private static func bandLabel(for band: CWChannelBand?) -> String {
        switch band {
        case .band2GHz:
            return "2.4 GHz"
        case .band5GHz:
            return "5 GHz"
        case .band6GHz:
            return "6 GHz"
        default:
            return "--"
        }
    }

    nonisolated private static func securityLabel(for network: CWNetwork) -> String {
        let labels: [(CWSecurity, String)] = [
            (.wpa3Enterprise, "WPA3 Enterprise"),
            (.wpa3Personal, "WPA3 Personal"),
            (.wpa3Transition, "WPA3 Transition"),
            (.wpa2Enterprise, "WPA2 Enterprise"),
            (.wpaEnterpriseMixed, "WPA/WPA2 Enterprise"),
            (.wpaEnterprise, "WPA Enterprise"),
            (.enterprise, "Enterprise"),
            (.wpa2Personal, "WPA2 Personal"),
            (.wpaPersonalMixed, "WPA/WPA2 Personal"),
            (.wpaPersonal, "WPA Personal"),
            (.personal, "Personal"),
            (.oweTransition, "OWE Transition"),
            (.OWE, "OWE"),
            (.dynamicWEP, "Dynamic WEP"),
            (.none, "Open"),
        ]

        for (security, label) in labels where network.supportsSecurity(security) {
            return label
        }

        return "Unknown"
    }

    nonisolated private static func friendlyMessage(for error: Error) -> String {
        if let scanError = error as? ScanError {
            return scanError.localizedDescription
        }

        let nsError = error as NSError

        if nsError.domain == CWErrorDomain, nsError.code == -3930 {
            return "macOS blocked the Wi-Fi scan. Check that location access is enabled for router monitor."
        }

        return nsError.localizedDescription
    }
}

extension WiFiScannerController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        AppLog.info("permissions", "CLLocationManager authorization callback received with status=\(manager.authorizationStatus.debugName)")
        updatePermissionState()

        if permissionState == .authorized {
            autoRefreshIfNeeded(reason: "location authorization changed", force: true)
        } else if !networks.isEmpty {
            AppLog.warning("permissions", "PermissionState=\(permissionState.debugName). Keeping \(networks.count) cached networks until a fresh authorized scan is possible")
        }
    }
}

enum ScanError: LocalizedError {
    case noInterface(interfaceNames: [String], sandboxed: Bool)

    var errorDescription: String? {
        switch self {
        case .noInterface(let interfaceNames, let sandboxed):
            if interfaceNames.isEmpty {
                if sandboxed {
                    return "No Wi-Fi interface is visible to the app. App Sandbox usually causes this even when the Mac itself has Wi-Fi."
                }

                return "No Wi-Fi interface is available on this Mac."
            }

            return "CoreWLAN could not bind a Wi-Fi interface. Available interface names: \(interfaceNames.joined(separator: ", "))."
        }
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension WiFiPermissionState {
    var debugName: String {
        switch self {
        case .servicesDisabled:
            return "servicesDisabled"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .authorized:
            return "authorized"
        }
    }
}

private extension CLAuthorizationStatus {
    var debugName: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }
}
