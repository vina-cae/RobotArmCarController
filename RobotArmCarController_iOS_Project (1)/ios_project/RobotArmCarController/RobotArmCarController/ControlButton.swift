//
//  ControlButton.swift
//  RobotArmCarController
//

import SwiftUI

/// A button that sends `command` while pressed and `RobotCommand.stop` on release,
/// matching the press-and-hold behavior of the original D-pad controls.
/// Shows a small amber dot if the underlying command is an unconfirmed placeholder.
struct HoldToSendButton: View {
    let systemImage: String
    let command: Character
    let sendsStopOnRelease: Bool
    let ble: BLEManager

    @GestureState private var isPressed = false

    init(systemImage: String, command: Character, sendsStopOnRelease: Bool = true, ble: BLEManager) {
        self.systemImage = systemImage
        self.command = command
        self.sendsStopOnRelease = sendsStopOnRelease
        self.ble = ble
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 26, weight: .semibold))
            .frame(width: 64, height: 64)
            .background(isPressed ? Color.accentColor.opacity(0.35) : Color(.secondarySystemBackground))
            .foregroundStyle(ble.state == .connected ? Color.primary : Color.secondary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !RobotCommand.isConfirmed(command) {
                    UnconfirmedBadge()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
                    .onChanged { _ in if !isPressed { ble.send(command) } }
                    .onEnded { _ in if sendsStopOnRelease { ble.send(RobotCommand.stop) } }
            )
            .disabled(ble.state != .connected)
    }
}

/// A simple tap-to-send button (for claw, arm, speed, and mode toggle actions).
struct TapToSendButton: View {
    let title: String
    let systemImage: String
    let command: Character
    let ble: BLEManager

    var body: some View {
        Button {
            ble.send(command)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !RobotCommand.isConfirmed(command) {
                    UnconfirmedBadge()
                }
            }
        }
        .disabled(ble.state != .connected)
    }
}

struct UnconfirmedBadge: View {
    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .padding(4)
            .accessibilityLabel("Unconfirmed command — see RobotCommand.swift")
    }
}
