# DexCast 🐾

> **Primary command/phrase:** “Sit With Dexter”
> **Purpose:** Cast your MacBook screen to the Fire TV Stick instantly so you can sit beside Dexter, your aging tricolor Phalène dog. Less fiddling, more time together.

DexCast is a native macOS SwiftUI application that acts as a control dashboard for connecting, authorizing, and streaming your MacBook workspace or mobile device to a Fire TV Stick via ADB, Sunshine, and Moonlight.

---

## Quick Start

1. **Launch the App**:
   Run the compiled application located at `/Users/andrew/Desktop/DexCast.app` or `/Users/andrew/DexCast/DexCast.app`.
2. **Dashboard Controls**:
   - Click the large orange **🐾 Sit With Dexter** button to connect ADB, wake up the Fire Stick, open Moonlight on TV, and start the Sunshine streaming host on your Mac.
   - Use the **Quick Cast** sidebar to run Android USB or Wi-Fi mirrors via `scrcpy`.
   - Monitor status cards to verify device connections and active systems.

---

## First-Time Setup Wizard

The app includes a step-by-step Setup Wizard to configure and authorize your environment without manual script editing:

1. **Step 1 (Story)**: Welcome and purpose.
2. **Step 2 (Install)**: Run dependencies installer. Downloads `adb`, `scrcpy`, `localsend`, `kdeconnect`, and `sunshine` via Homebrew.
3. **Step 3 (Profile)**: Input profile name, Fire Stick IP (`10.0.0.115`), and optional Android IP.
4. **Step 4 (Developer Options)**: Enable developer settings on the Fire Stick (Settings → My Fire TV → About → Click device name 7 times; then go to Developer Options and turn ADB Debugging ON).
5. **Step 5 (Moonlight)**: Search and install "Moonlight Game Streaming" from the Fire Stick App Store.
6. **Step 6 (Authorize ADB)**: Runs connection. Look at your TV, check **Always allow from this computer**, and click Allow.
7. **Step 7 (Sunshine)**: Start the Sunshine streaming host.
8. **Step 8 (Displays)**: Open macOS Display settings to choose resolution and layout.
9. **Step 9 (Diagnostics)**: Run the DexCast Doctor to verify all gates.
10. **Step 10 (Launch)**: Test your first cast!

---

## Troubleshooting & Key Concepts

### What does "ADB Unauthorized" mean?
It means the Fire Stick has blocked connection requests from your MacBook because the cryptographic key pair has not been trusted yet. 
- **Fix**: Click **Authorize Fire Stick** (Step 6 or sidebar), watch the TV screen, and choose **Always allow from this computer**, then **Allow**. If it remains unauthorized, click **Reset ADB** in the sidebar.

### How to update the Fire Stick IP?
If the Fire Stick IP changes due to DHCP renewals:
1. Go to the Fire Stick: Settings → My Fire TV → About → Network. Write down the new IP.
2. In DexCast, go to **Setup Profile** (Step 3 or sidebar) and save the new IP.
3. The dashboard will automatically update and attempt connection.

### Dual-Monitor Notes
DexCast guides display routing, but **Sunshine** manages the video capture source:
- Click **macOS Displays** to adjust screen layouts.
- Click **Sunshine Web UI** (`https://localhost:47990`) to log into your Sunshine server settings, navigate to Configuration → Audio/Video, and select the target display index for screen capture.

---

## Developer Scripts

Located in the `scripts/` directory:
- **`scripts/build.zsh`**: Compiles `src/DexCast.swift`, structures the `.app` bundle, links visual Dexter state assets, and applies codesigning.
- **`scripts/doctor.zsh`**: Gathers environment diagnostics and writes them to the log.
- **`scripts/test.zsh`**: Performs script syntax validation (`zsh -n`) and checks app bundle structure integrity.

Logs are written with timestamps directly to `~/Library/Logs/dexcast.log`.
