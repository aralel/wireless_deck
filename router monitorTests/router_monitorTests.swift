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

}
