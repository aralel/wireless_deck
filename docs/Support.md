# Wi-Fi Radar Support

Updated: March 23, 2026

Wi-Fi Radar helps you inspect nearby Wi-Fi networks and nearby Bluetooth Low Energy devices on Mac. The app includes a Wi-Fi radar, a Bluetooth radar, copy tools, locally cached restore on launch, and an optional debug console.

## Requirements

- A Mac with Wi-Fi hardware enabled for nearby Wi-Fi scans
- Bluetooth turned on for Bluetooth sweeps
- macOS Location Services access granted to Wi-Fi Radar for Wi-Fi scans
- macOS Bluetooth access granted to Wi-Fi Radar if the system prompts during Bluetooth discovery

## Quick start

1. Open Wi-Fi Radar.
2. If macOS asks for Location Services or Bluetooth permission, allow the request for the feature you want to use.
3. On the Wi-Fi radar, click `Refresh Scan` to list nearby networks.
4. Switch to `Bluetooth Radar` and start a sweep to list nearby advertising BLE devices.
5. Sort, search, filter, or use `Copy Visible` as needed.

## Troubleshooting

### No networks are shown

- Make sure Wi-Fi is enabled on your Mac.
- Click `Refresh Scan`.
- Confirm Location Services is enabled in System Settings.
- Confirm Wi-Fi Radar has permission under `System Settings > Privacy & Security > Location Services`.

### No Bluetooth devices are shown

- Make sure Bluetooth is turned on.
- Start a new Bluetooth sweep.
- Confirm Wi-Fi Radar is allowed under `System Settings > Privacy & Security > Bluetooth` if macOS has asked before.
- Remember that the Bluetooth radar shows devices that are actively advertising nearby over Bluetooth Low Energy.

### BSSIDs are hidden

macOS may hide BSSIDs until location access has been granted. Recheck the app's Location Services permission and refresh the scan.

### A Bluetooth device is missing

Some devices do not advertise all the time, and some classic Bluetooth devices may not appear if they are not actively advertising over Bluetooth Low Energy. Move closer, wake the device, or run another sweep.

### Router model looks generic

Router identity in Wi-Fi Radar is a best-effort guess based on SSID patterns and available metadata. Exact models are only shown when the network advertises them clearly.

### Old results appear immediately on launch

That is expected. Wi-Fi Radar restores recent local Wi-Fi and Bluetooth results from on-device cache so the app does not open empty. Run a fresh scan or sweep any time you want live data.

### The debug console is not visible

The debug console is hidden by default. Use the `Show Debug Console` button in the app header when you want to inspect scan logs.

## Contact support

For support questions, contact:

- Email: `support@aralel.com`
- Website: `https://www.aralel.com`
- Name or company: `Aralel GmbH`

## Information to include in a support request

To speed up troubleshooting, include:

- your macOS version
- whether Location Services is enabled for Wi-Fi Radar
- whether Bluetooth access is enabled for Wi-Fi Radar
- whether Wi-Fi and Bluetooth are on
- a short description of the issue
- copied debug logs, if relevant
