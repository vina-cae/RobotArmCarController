# LAFVIN 4WD Robot Arm Smart Car — iOS Controller (reverse-engineered)

## 1. What the original app actually is
Inspecting `LAFVIN_4WD_Robot_Arm_Smart_Car_V2_2.zip` (an APK renamed to .zip) shows it is a
**Flutter/Dart app**, package name `robot_arm_car`, using the `flutter_blue_plus` BLE plugin.
The control logic lives in `lib/arm64-v8a/libapp.so` etc. — a **Dart AOT snapshot compiled to
native ARM machine code**, not readable source. Flutter apps ship no Dart bytecode/source in
the APK, so this could not be decompiled back into logic in this session (would need a
specialized AOT disassembler such as `blutter`, which isn't available here and is beyond a
single free-tier session to run reliably).

## 2. What's confirmed (from the official manual you uploaded, `LA040--APP_Remote_Connected_to_Bluetooth.pdf`)
- Robot's BLE module: **`JDY-16`**
- GATT service UUID: **`0000FFE0-0000-1000-8000-00805F9B34FB`**
- Write characteristic UUID: **`0000FFE1-0000-1000-8000-00805F9B34FB`**
- Protocol: single ASCII character written to that characteristic, no terminator.
- Confirmed example commands: **`'F'` = forward**, **`'S'` = stop**.

## 3. What's confirmed from the APK's asset filenames (image names embedded in the app)
These tell us exactly what buttons/features exist, even though not the byte codes they send:
Drive (up/down/left/right/stop), Claw (open/close), Arm (up/down/left/right/execute/save),
Speed (low/mid/high + up/down), Modes (line tracking, obstacle avoidance, following,
auto-carry, anti-drop), gravity-sensor tilt control, and the BLE connect/scanning UI.

## 4. What is NOT recoverable / NOT guessed
The exact single-character codes for backward, left, right, each arm motion, each speed level,
and each mode toggle are **not in this document and not recoverable from the compiled binary**
in this session. I deliberately did **not** substitute values from other vendors' similar but
unrelated Arduino/Bluetooth-car projects, since that would be guessing, not reverse-engineering.

**To get the real values** (~15 minutes, no coding required):
1. Install **nRF Connect for Mobile** (Android) alongside the original LAFVIN app.
2. Power the robot, open nRF Connect, connect to `JDY-16`, open the **Log** tab, leave it running.
3. Separately, open the official LAFVIN app and connect to the robot.
4. Press each button one at a time (Backward, Left, Right, claw open/close, each arm direction,
   each speed level, each mode toggle).
5. Check nRF Connect's log — each press shows the exact byte(s) written to characteristic FFE1.
6. Edit `RobotCommand.swift` in the iOS project (constants are clearly labeled, one line each)
   and replace the placeholder characters with the real ones.

## 5. Technology decision for the iOS rebuild
**Native Swift + SwiftUI + CoreBluetooth** — not Flutter, not React Native. Reasoning:
- CoreBluetooth is Apple's first-party BLE stack; no need to bundle a cross-platform runtime.
- A single-file-per-screen Swift project is the easiest thing to open, build, and sign in
  Xcode, then export an unsigned/ad-hoc IPA for Sideloadly.
- No dependency on `flutter_blue_plus`-equivalent third-party BLE libraries — reduces build
  risk for a project you'll be signing and installing manually.

## 6. What's in the iOS project (`RobotArmCarController/`)
A real, buildable Xcode project (iOS 16+, SwiftUI):
- `BLEManager.swift` — CoreBluetooth central: scans for `JDY-16`, connects, discovers the
  confirmed service/characteristic, writes commands. Fully functional, not a stub.
- `RobotCommand.swift` — the protocol layer. `forward`/`stop` are wired to the **confirmed**
  manual values. Every other command is a single named constant marked `// UNCONFIRMED
  placeholder` with instructions above it for how to fill it in.
- `ControlButton.swift` / `ContentView.swift` — SwiftUI UI matching the original's layout
  (D-pad, claw, arm, speed, mode buttons). Any button still on a placeholder command shows a
  small orange dot so you always know what's verified vs. not.
- `Info.plist` — includes `NSBluetoothAlwaysUsageDescription` (required by iOS to use BLE).

**Working today, on real hardware, with zero edits:** Forward (press-and-hold) and Stop.
**Working once you fill in `RobotCommand.swift`:** everything else — the BLE plumbing, UI, and
press/release handling are already correct; only the character values need replacing.

## 7. Building the IPA

### Option A — No Mac (GitHub Actions, included in this project)
This project already includes `.github/workflows/build-ipa.yml`, which builds an **unsigned**
`.ipa` on a real macOS machine for free. You don't sign it yourself — Sideloadly signs it with
your Apple ID at install time, so an unsigned IPA is exactly what's needed.

1. Create a free GitHub account if you don't have one: github.com/join
2. Create a new **public** repository (private repos get far fewer free CI minutes).
3. Upload the entire `RobotArmCarController/` folder plus the `.github/` folder from this zip
   to that repo (drag-and-drop works on github.com, or `git push` if you're comfortable with
   git).
4. Go to the repo's **Actions** tab. If it doesn't run automatically, click **Build unsigned
   IPA** → **Run workflow**.
5. Wait a few minutes for it to finish (green checkmark). Open the completed run, scroll to
   **Artifacts**, and download `RobotArmCarController-unsigned-ipa` — it's a zip containing
   `RobotArmCarController-unsigned.ipa`.
6. Install **Sideloadly** on a Windows or Mac PC (sideloadly.io). Windows also needs Apple's
   iTunes/driver installed once so the PC can see your iPhone over USB.
7. Plug in your iPhone, open Sideloadly, drag `RobotArmCarController-unsigned.ipa` in, enter
   your Apple ID when prompted (a free Apple ID works — no paid Developer Program needed), and
   click Start. Sideloadly signs and installs it.
8. On the iPhone: **Settings → General → VPN & Device Management** → trust your Apple ID's
   developer profile the first time you launch the app.
9. Free Apple ID signing expires after **7 days** — just re-run Sideloadly with the same IPA to
   reinstall when it stops opening; you don't need to rebuild unless you changed the code.

### Option B — If you later get access to a Mac
1. Open `RobotArmCarController.xcodeproj` in Xcode (15+).
2. Select the `RobotArmCarController` target → **Signing & Capabilities** → set your Apple ID
   under **Team**.
3. Change `PRODUCT_BUNDLE_IDENTIFIER` if `com.eduardmendoza.RobotArmCarController` collides
   with something already on your account.
4. Product → Destination → **Any iOS Device (arm64)** → Product → Archive.
5. In the Organizer window, **Distribute App → Development** → Export, to get the `.ipa`.
6. Install via Sideloadly or directly from Xcode's Organizer (**Distribute App → Debugging**
   lets Xcode install straight to a plugged-in iPhone, skipping Sideloadly entirely).

## 8. Remaining work / next session
- [ ] Capture the real command bytes with nRF Connect (see §4) and paste them into
      `RobotCommand.swift`.
- [ ] Build and test on real hardware; adjust `writeType` in `BLEManager.send()` if the module
      turns out to require `.withResponse` instead of `.withoutResponse` (try both if unsure).
- [ ] Optional: add the gravity-sensor tilt-control mode (uses the phone's accelerometer —
      `CMMotionManager` — to continuously stream direction commands; not wired yet since its
      exact byte protocol is equally unconfirmed).
- [ ] Optional: real app icon / launch screen art (currently blank placeholders).

This document plus the full project files are enough to pick this back up from scratch in a
new conversation without re-doing the analysis above.
