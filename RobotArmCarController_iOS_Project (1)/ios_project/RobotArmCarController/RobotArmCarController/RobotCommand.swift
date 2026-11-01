//
//  RobotCommand.swift
//  RobotArmCarController
//
//  BLE command protocol for the LAFVIN 4WD Robot Arm Smart Car (JDY-16 BLE module).
//
//  SOURCE OF TRUTH: LA040--APP_Remote_Connected_to_Bluetooth.pdf (official manual)
//  Confirms:
//    - BLE module name:        "JDY-16"
//    - GATT service UUID:      0000FFE0-0000-1000-8000-00805F9B34FB
//    - GATT write char UUID:   0000FFE1-0000-1000-8000-00805F9B34FB
//    - Commands are single ASCII characters, written as UTF-8 bytes (no newline).
//    - Confirmed example commands: 'F' = forward, 'S' = stop.
//
//  EVERYTHING ELSE BELOW MARKED "UNCONFIRMED" IS A PLACEHOLDER, NOT A GUESS.
//  The original app's actual button->command mapping lives inside the Flutter
//  AOT-compiled binary (libapp.so, Dart machine code) and could not be recovered
//  as readable source in this session. Do NOT assume the placeholder characters
//  below are correct — they are deliberately left as single, easy-to-edit
//  constants so you can fill in the real values once you capture them.
//
//  HOW TO GET THE REAL VALUES (~15 minutes, no coding required):
//  1. Install "nRF Connect for Mobile" (Android) alongside the original LAFVIN app.
//  2. Power the robot, open nRF Connect, connect to "JDY-16", and open the
//     Log tab — leave it running.
//  3. In a SEPARATE step, open the official LAFVIN app and connect to the robot.
//  4. Press each button (Backward, Left, Right, claw open/close, arm up/down/
//     left/right, each speed level, each mode toggle) one at a time.
//  5. Switch back to nRF Connect's log — each button press shows the exact
//     bytes written to characteristic FFE1. Record the character.
//  6. Paste the captured characters into the constants below.
//
//  Until then, this app will drive Forward/Stop correctly over real hardware;
//  every other button sends its placeholder value so the UI and BLE plumbing
//  are fully wired, but you must confirm/replace the character before relying
//  on those specific commands.
//

import Foundation

enum RobotCommand {

    // MARK: - CONFIRMED (from official manual)

    static let forward: Character = "F"
    static let stop: Character = "S"

    // MARK: - UNCONFIRMED PLACEHOLDERS (edit after capturing real values — see header)
    // Each `unconfirmed: true` flag below drives a small warning badge in the UI
    // so you always know, at a glance, which buttons are still placeholders.

    static let backward: Character = "B"       // UNCONFIRMED placeholder
    static let left: Character = "L"           // UNCONFIRMED placeholder
    static let right: Character = "R"          // UNCONFIRMED placeholder

    static let clawOpen: Character = "O"        // UNCONFIRMED placeholder
    static let clawClose: Character = "C"       // UNCONFIRMED placeholder
    static let armUp: Character = "1"           // UNCONFIRMED placeholder
    static let armDown: Character = "2"         // UNCONFIRMED placeholder
    static let armLeft: Character = "3"         // UNCONFIRMED placeholder
    static let armRight: Character = "4"        // UNCONFIRMED placeholder
    static let armExecute: Character = "5"      // UNCONFIRMED placeholder
    static let armSave: Character = "6"         // UNCONFIRMED placeholder

    static let speedLow: Character = "7"        // UNCONFIRMED placeholder
    static let speedMiddle: Character = "8"     // UNCONFIRMED placeholder
    static let speedHigh: Character = "9"       // UNCONFIRMED placeholder
    static let speedUp: Character = "+"         // UNCONFIRMED placeholder
    static let speedDown: Character = "-"       // UNCONFIRMED placeholder

    static let lineTrackingToggle: Character = "T"      // UNCONFIRMED placeholder
    static let obstacleAvoidanceToggle: Character = "A" // UNCONFIRMED placeholder
    static let followingToggle: Character = "W"         // UNCONFIRMED placeholder
    static let autoCarryToggle: Character = "Y"          // UNCONFIRMED placeholder
    static let antiDropToggle: Character = "D"           // UNCONFIRMED placeholder

    /// Characters that are verified against the official manual.
    static let confirmedCommands: Set<Character> = [forward, stop]

    static func isConfirmed(_ c: Character) -> Bool {
        confirmedCommands.contains(c)
    }
}

/// A single controllable action in the UI, pairing a label/icon with its command
/// character and whether that character is confirmed or a placeholder.
struct RobotAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let command: Character

    var isConfirmed: Bool { RobotCommand.isConfirmed(command) }
}
