# App Store Submission Answers

Generated on March 23, 2026 for the current verified macOS app.

Use this as the short answer sheet when filling App Store Connect. This file is intentionally more direct than [AppStoreSubmission.md](/Users/maysam/Workspace/aralel/router%20monitor/docs/AppStoreSubmission.md).

## Scope

- Platform: `macOS`
- App name in project: `Wireless Deck`
- Bundle ID: `com.aralel.router-monitor`
- Version: `1.0`

Note:

- The project configuration references an iPhone target, but the current source checkout is still scoped to the macOS app.
- These answers are intentionally for the macOS submission only.

## App information

### Question: What is the app name?

Answer:

`Wireless Deck`

### Question: What is the subtitle?

Answer:

`Inspect Wi-Fi and Bluetooth`

### Question: What is the promotional text?

Answer:

`Scan nearby Wi-Fi networks, sweep Bluetooth LE devices, sort by signal, and copy wireless diagnostics from one Mac dashboard.`

### Question: What is the full App Store description?

Answer:

`Wireless Deck helps you inspect the wireless environment around your Mac.

Use the Wi-Fi radar to scan nearby networks and view SSID, BSSID, signal, noise, channel, band, security, and router hints. Use the Bluetooth radar to sweep nearby Bluetooth Low Energy devices, compare signal strength, review service summaries, and inspect advertising details.

Sort and filter both views instantly, search live, copy visible rows for diagnostics, and open the optional debug console when you need deeper troubleshooting. Recent Wi-Fi and Bluetooth results are cached locally so the app can restore your last view on launch instead of opening empty.

Use Wireless Deck to:
- inspect nearby Wi-Fi access points
- sweep nearby Bluetooth LE devices
- compare signal quality and radio conditions
- export the rows you are looking at
- troubleshoot permissions and visibility issues with the in-app debug console

Important:
- macOS requires Location Services permission before apps can access nearby Wi-Fi names and BSSIDs
- macOS may require Bluetooth permission before the app can discover nearby BLE devices
- Bluetooth results show devices that are actively advertising nearby
- Wireless Deck does not require an account and does not upload your scan results or debug logs`

### Question: What keywords should I use?

Answer:

`wifi,bluetooth,ble,wireless,router,network,ssid,bssid,signal,diagnostics`

### Question: What is the support URL?

Answer:

`https://<github-username>.github.io/<repo-name>/support.html`

### Question: What is the privacy policy URL?

Answer:

`https://<github-username>.github.io/<repo-name>/privacy.html`

### Question: What is the marketing URL?

Answer:

`Optional. Leave blank unless you have a separate product website.`

### Question: What copyright text should I use?

Answer:

`Copyright 2026 Aralel GmbH`

## App Review

### Question: What should I put in the review notes?

Answer:

`Wireless Deck is a macOS utility with two local discovery surfaces: a Wi-Fi radar built on CoreWLAN and a Bluetooth radar for nearby Bluetooth Low Energy devices.

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

### Question: Does App Review need a demo account?

Answer:

`No demo account is required.`

### Question: What review contact details do I need to provide?

Answer:

- First name: `[YOUR FIRST NAME]`
- Last name: `[YOUR LAST NAME]`
- Email: `[YOUR REVIEW CONTACT EMAIL]`
- Phone: `[YOUR REVIEW CONTACT PHONE]`

## App Privacy

### Question: Does the app collect data from the app?

Answer:

`No.`

### Question: Does the app use data for tracking?

Answer:

`No.`

### Question: Why does the app request location permission?

Answer:

`The app requests location authorization because macOS requires it before third-party apps can access nearby Wi-Fi SSIDs and BSSIDs. Wireless Deck does not collect or transmit the user's geographic location.`

### Question: Why does the app request Bluetooth permission?

Answer:

`The app may request Bluetooth permission so the Bluetooth radar can discover nearby Bluetooth Low Energy devices on Mac. Wireless Deck does not upload discovered device identifiers or build remote profiles from them.`

### Question: Why is "No data collected" accurate here?

Answer:

- Nearby Wi-Fi scanning happens locally on the Mac
- Nearby Bluetooth Low Energy discovery happens locally on the Mac
- There is no sign-in or account system
- There is no analytics SDK
- There is no remote API, upload, or cloud sync
- Local cache files stay on the Mac and are not transmitted off device
- Copy actions write only to the system pasteboard when the user clicks a button

## Pricing and categorization

### Question: What primary category fits best?

Answer:

`Utilities`

### Question: What price should I start with?

Answer:

`Free` is the most natural starting point for the current feature set.

### Question: What age rating guidance fits the current app?

Answer:

`No gambling, no alcohol/tobacco/drug references, no mature themes, no user-generated content.`

## Final checks before submission

- Replace all bracketed placeholders with your real details
- Publish the `docs` site and verify the support and privacy URLs load publicly
- Confirm you own the icon artwork and all app assets
- Review export compliance in App Store Connect before submitting
