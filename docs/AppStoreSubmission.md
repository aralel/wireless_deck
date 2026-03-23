# App Store Submission Pack

Generated on March 23, 2026 for the verified macOS target:

- App bundle ID: `com.aralel.router-monitor`
- Display name in project: `WiFi Radar`
- Marketing version: `1.0`
- Category in project: `Utilities`

This pack is written for the macOS app currently present in the workspace. The project configuration references an iPhone target, but the current source checkout is still scoped to the macOS app, so iOS-specific submission copy is intentionally not claimed here.

## App Store metadata

### App name

`Wi-Fi Radar`

Length: 11 / 30

### Subtitle

`Inspect Wi-Fi and Bluetooth`

Length: 23 / 30

### Promotional text

`Scan nearby Wi-Fi networks, sweep Bluetooth LE devices, sort by signal, and copy wireless diagnostics from one Mac dashboard.`

Length: 150 / 170

### Description

`Wi-Fi Radar helps you inspect the wireless environment around your Mac.

Use the Wi-Fi radar to scan nearby networks and view SSID, BSSID, signal, noise, channel, band, security, and router hints. Use the Bluetooth radar to sweep nearby Bluetooth Low Energy devices, compare signal strength, review service summaries, and inspect advertising details.

Sort and filter both views instantly, search live, copy visible rows for diagnostics, and open the optional debug console when you need deeper troubleshooting. Recent Wi-Fi and Bluetooth results are cached locally so the app can restore your last view on launch instead of opening empty.

Use Wi-Fi Radar to:
- inspect nearby Wi-Fi access points
- sweep nearby Bluetooth LE devices
- compare signal quality and radio conditions
- export the rows you are looking at
- troubleshoot permissions and visibility issues with the in-app debug console

Important:
- macOS requires Location Services permission before apps can access nearby Wi-Fi names and BSSIDs
- macOS may require Bluetooth permission before the app can discover nearby BLE devices
- Bluetooth results show devices that are actively advertising nearby
- Wi-Fi Radar does not require an account and does not upload your scan results or debug logs`

### Keywords

`wifi,bluetooth,ble,wireless,router,network,ssid,bssid,signal,diagnostics`

Size: 74 / 100 bytes

### Support URL

Use the published GitHub Pages support page:

`https://<github-username>.github.io/<repo-name>/support.html`

### Privacy Policy URL

Use the published GitHub Pages privacy page:

`https://<github-username>.github.io/<repo-name>/privacy.html`

### Marketing URL

Optional. Leave blank if you do not have a product website yet.

### Copyright

`Copyright 2026 Aralel GmbH`

## App Review information

### Review notes

`Wi-Fi Radar is a macOS utility with two local discovery surfaces: a Wi-Fi radar built on CoreWLAN and a Bluetooth radar for nearby Bluetooth Low Energy devices.

The Wi-Fi radar shows SSID, BSSID, signal, noise, channel, band, security, and router hints. The Bluetooth radar shows nearby BLE devices, signal strength, service summaries, connectability hints, and advertising details.

Location Services permission is required only because macOS gates access to nearby Wi-Fi names and BSSIDs behind location authorization. Bluetooth permission may also be requested so the app can discover nearby BLE devices. The app does not use maps, request background location, or collect geographic coordinates.

There are no sign-ins, accounts, payments, subscriptions, or third-party SDKs.

To test the core feature:
1. Launch the app.
2. Grant Location Services access if macOS prompts for Wi-Fi scanning.
3. Click "Refresh Scan" on the Wi-Fi radar to list nearby networks.
4. Switch to "Bluetooth Radar" and allow Bluetooth access if macOS prompts, then start a sweep.
5. Nearby Wi-Fi networks and advertising BLE devices should appear.

If access is denied, the app shows in-app explanations and buttons that open System Settings so permissions can be enabled. Bluetooth results are limited to devices that are actively advertising nearby.`

### Demo account

`No demo account is required.`

### Review contact fields

These fields are not generated from the codebase and must be filled with your real contact details:

- First name: `[YOUR FIRST NAME]`
- Last name: `[YOUR LAST NAME]`
- Email: `[YOUR REVIEW CONTACT EMAIL]`
- Phone: `[YOUR REVIEW CONTACT PHONE]`

## App Privacy answers

These are the recommended App Privacy answers based on the current codebase.

### Data collection

`No, this app does not collect data from the app.`

Reasoning:

- the app scans nearby Wi-Fi networks locally on the Mac
- the app discovers nearby Bluetooth Low Energy devices locally on the Mac
- there is no account system
- there is no analytics SDK
- there is no remote API, upload, or cloud sync
- local cache files stay on the Mac and are not transmitted off device
- copy actions write to the system pasteboard only when the user clicks a button

### Tracking

`No, this app does not use data for tracking.`

### Location explanation for App Review

Use this if asked why the app requests location permission:

`The app requests location authorization because macOS requires it before third-party apps can access nearby Wi-Fi SSIDs and BSSIDs. Wi-Fi Radar does not collect or transmit the user's geographic location.`

### Bluetooth explanation for App Review

Use this if asked why the app requests Bluetooth permission:

`The app may request Bluetooth permission so the Bluetooth radar can discover nearby Bluetooth Low Energy devices on Mac. Wi-Fi Radar does not upload discovered device identifiers or build remote profiles from them.`

## Optional screenshot captions

If you want short marketing text for screenshots, use these:

1. `Scan nearby Wi-Fi networks`
2. `Sweep nearby Bluetooth LE devices`
3. `Read signal quality at a glance`
4. `Sort and filter large wireless views fast`
5. `Restore recent results and copy diagnostics quickly`

## Suggested release notes

Use this for future updates, or adapt it if you want an internal launch note:

`Initial release of Wi-Fi Radar with nearby Wi-Fi scanning, Bluetooth LE sweeps, router hints, sortable results, signal-quality views, cached restore, export tools, and an optional debug console for troubleshooting permission and scan issues.`

## Short answer sheet

For the paste-ready version of the submission answers, use:

[AppStoreSubmissionAnswers.md](/Users/maysam/Workspace/aralel/router%20monitor/docs/AppStoreSubmissionAnswers.md)

## Non-text items you still need to choose manually

- Price: `Free` is the most natural starting point for the current feature set
- Primary category: `Utilities`
- Secondary category: optional
- Age rating: no gambling, no alcohol/tobacco/drug references, no mature themes, no user-generated content
- Content rights: confirm you own the icon artwork and all app assets
- Export compliance: review your exact answer in App Store Connect, but the current codebase does not include custom encryption logic or network transport

## Sources checked

- Apple App Store Connect reference for required metadata fields:
  [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties/)
- Apple App Review submission flow:
  [Overview of submitting for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-for-review/)
- Apple App Privacy guidance:
  [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
