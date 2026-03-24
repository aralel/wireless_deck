//
//  router_monitorTests.swift
//  router monitorTests
//
//  Created by maysam torabi on 22.03.2026.
//

import Testing
@testable import router_monitor
import Foundation

struct router_monitorTests {

    @Test func infersFritzBoxRoutersFromSSID() async throws {
        #expect(RouterIdentity.inferRouter(from: "FRITZ!Box 7590 WS", bssid: "aa:bb:cc:dd:ee:ff") == "AVM FRITZ!Box 7590 WS")
    }

    @Test func infersVodafoneRoutersFromSSID() async throws {
        #expect(RouterIdentity.inferRouter(from: "Vodafone-BB6B", bssid: "aa:bb:cc:dd:ee:ff") == "Vodafone-branded router")
    }

    @Test func resolvesVendorFromBSSIDPrefix() async throws {
        #expect(WiFiVendorCatalog.vendorName(for: "24:a4:3c:11:22:33") == "Ubiquiti")
    }

    @Test func promptsForPermissionWhenRouterNeedsBSSID() async throws {
        #expect(RouterIdentity.inferRouter(from: "Promised Lan", bssid: nil) == "Grant location access to reveal the BSSID")
    }

    @Test func identifiesAppleManufacturerFromBluetoothPayload() async throws {
        let manufacturerData = Data([0x4C, 0x00, 0x02, 0x15])
        #expect(BluetoothDeviceIdentity.manufacturerSummary(from: manufacturerData) == "Apple • 4 bytes")
    }

    @Test func infersAirPodsFromBluetoothName() async throws {
        #expect(
            BluetoothDeviceIdentity.inferType(
                from: "Maysam's AirPods Pro",
                localName: "Maysam's AirPods Pro",
                manufacturerData: nil,
                serviceUUIDs: []
            ) == "Apple AirPods"
        )
    }

    @MainActor
    @Test func wifiDiffHighlightsNewStrongerAndMovedNetworks() async throws {
        let previous = [
            WiFiNetwork(
                id: "aa:bb:cc:dd:ee:01",
                ssid: "Home",
                bssid: "aa:bb:cc:dd:ee:01",
                vendorName: "AVM",
                routerSummary: "AVM access point",
                security: "WPA2 Personal",
                signalStrength: -72,
                noise: -92,
                channel: 1,
                band: "2.4 GHz",
                isCurrentNetwork: true
            )
        ]

        let current = [
            WiFiNetwork(
                id: "aa:bb:cc:dd:ee:01",
                ssid: "Home",
                bssid: "aa:bb:cc:dd:ee:01",
                vendorName: "AVM",
                routerSummary: "AVM access point",
                security: "WPA2 Personal",
                signalStrength: -60,
                noise: -92,
                channel: 11,
                band: "2.4 GHz",
                isCurrentNetwork: true
            ),
            WiFiNetwork(
                id: "aa:bb:cc:dd:ee:02",
                ssid: "Guest",
                bssid: "aa:bb:cc:dd:ee:02",
                vendorName: "Ubiquiti",
                routerSummary: "Ubiquiti access point",
                security: "WPA3 Personal",
                signalStrength: -65,
                noise: -92,
                channel: 36,
                band: "5 GHz",
                isCurrentNetwork: false
            )
        ]

        let digest = WirelessTelemetryStore.makeWiFiDiff(previous: previous, current: current)

        #expect(digest.newCount == 1)
        #expect(digest.strongerCount == 1)
        #expect(digest.movedCount == 1)
    }

    @MainActor
    @Test func crowdedWifiProducesLowerHealthScore() async throws {
        let crowdedNetworks = (1...12).map { index in
            WiFiNetwork(
                id: "aa:bb:cc:dd:ee:\(String(format: "%02d", index))",
                ssid: "Neighbor \(index)",
                bssid: "aa:bb:cc:dd:ee:\(String(format: "%02d", index))",
                vendorName: "Vendor",
                routerSummary: "Vendor access point",
                security: "WPA2 Personal",
                signalStrength: -78 + index,
                noise: -88,
                channel: [1, 6, 11][index % 3],
                band: "2.4 GHz",
                isCurrentNetwork: index == 1
            )
        }

        let health = WirelessTelemetryStore.makeWiFiHealth(from: crowdedNetworks)

        #expect(health.score < 70)
    }

}
