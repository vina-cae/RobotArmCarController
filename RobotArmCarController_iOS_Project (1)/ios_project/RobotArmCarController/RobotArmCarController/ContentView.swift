//
//  ContentView.swift
//  RobotArmCarController
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    connectionBar

                    dPad

                    speedSection

                    armSection

                    modesSection

                    legend
                }
                .padding()
            }
            .navigationTitle("4WD Robot Arm Car")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPicker = true
                        ble.startScan()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                DevicePickerView(ble: ble, isPresented: $showPicker)
            }
        }
    }

    // MARK: - Sections

    private var connectionBar: some View {
        HStack {
            Image(systemName: ble.state == .connected ? "dot.radiowaves.left.and.right" : "bolt.slash")
                .foregroundStyle(ble.state == .connected ? .green : .red)
            Text(ble.state.label)
                .font(.subheadline)
            Spacer()
            if ble.state == .connected {
                Button("Disconnect") { ble.disconnect() }
                    .font(.subheadline)
            } else if ble.state == .scanning || ble.state == .connecting {
                ProgressView()
            } else {
                Button("Connect") { ble.startScan() }
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dPad: some View {
        VStack(spacing: 10) {
            Text("Drive").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            HoldToSendButton(systemImage: "chevron.up", command: RobotCommand.forward, ble: ble)
            HStack(spacing: 10) {
                HoldToSendButton(systemImage: "chevron.left", command: RobotCommand.left, ble: ble)
                Button {
                    ble.send(RobotCommand.stop)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 64, height: 64)
                        .background(Color.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(ble.state != .connected)
                HoldToSendButton(systemImage: "chevron.right", command: RobotCommand.right, ble: ble)
            }
            HoldToSendButton(systemImage: "chevron.down", command: RobotCommand.backward, ble: ble)
        }
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Speed").font(.headline)
            HStack(spacing: 10) {
                TapToSendButton(title: "Low", systemImage: "tortoise", command: RobotCommand.speedLow, ble: ble)
                TapToSendButton(title: "Mid", systemImage: "gauge.medium", command: RobotCommand.speedMiddle, ble: ble)
                TapToSendButton(title: "High", systemImage: "hare", command: RobotCommand.speedHigh, ble: ble)
            }
            HStack(spacing: 10) {
                TapToSendButton(title: "Speed -", systemImage: "minus.circle", command: RobotCommand.speedDown, ble: ble)
                TapToSendButton(title: "Speed +", systemImage: "plus.circle", command: RobotCommand.speedUp, ble: ble)
            }
        }
    }

    private var armSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Arm & Claw").font(.headline)
            HStack(spacing: 10) {
                TapToSendButton(title: "Arm Up", systemImage: "arrow.up", command: RobotCommand.armUp, ble: ble)
                TapToSendButton(title: "Arm Down", systemImage: "arrow.down", command: RobotCommand.armDown, ble: ble)
            }
            HStack(spacing: 10) {
                TapToSendButton(title: "Arm Left", systemImage: "arrow.left", command: RobotCommand.armLeft, ble: ble)
                TapToSendButton(title: "Arm Right", systemImage: "arrow.right", command: RobotCommand.armRight, ble: ble)
            }
            HStack(spacing: 10) {
                TapToSendButton(title: "Claw Open", systemImage: "hand.raised", command: RobotCommand.clawOpen, ble: ble)
                TapToSendButton(title: "Claw Close", systemImage: "hand.raised.fill", command: RobotCommand.clawClose, ble: ble)
            }
            HStack(spacing: 10) {
                TapToSendButton(title: "Save Step", systemImage: "square.and.arrow.down", command: RobotCommand.armSave, ble: ble)
                TapToSendButton(title: "Execute", systemImage: "play.fill", command: RobotCommand.armExecute, ble: ble)
            }
        }
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Modes").font(.headline)
            HStack(spacing: 10) {
                TapToSendButton(title: "Line Track", systemImage: "road.lanes", command: RobotCommand.lineTrackingToggle, ble: ble)
                TapToSendButton(title: "Avoid", systemImage: "exclamationmark.triangle", command: RobotCommand.obstacleAvoidanceToggle, ble: ble)
            }
            HStack(spacing: 10) {
                TapToSendButton(title: "Follow", systemImage: "figure.walk", command: RobotCommand.followingToggle, ble: ble)
                TapToSendButton(title: "Auto Carry", systemImage: "shippingbox", command: RobotCommand.autoCarryToggle, ble: ble)
            }
            TapToSendButton(title: "Anti-Drop", systemImage: "arrow.down.to.line", command: RobotCommand.antiDropToggle, ble: ble)
        }
    }

    private var legend: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.orange).frame(width: 10, height: 10).padding(.top, 4)
            Text("Orange dot = command not yet confirmed against your hardware. Edit RobotCommand.swift once you capture the real value. Forward/Stop are confirmed from the official manual.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Device picker

struct DevicePickerView: View {
    @ObservedObject var ble: BLEManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(ble.discoveredPeripherals, id: \.identifier) { peripheral in
                Button {
                    ble.connect(to: peripheral)
                    isPresented = false
                } label: {
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "Unknown device")
                            .font(.body)
                        Text(peripheral.identifier.uuidString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if ble.discoveredPeripherals.isEmpty {
                    ProgressView("Searching for JDY-16…")
                }
            }
            .navigationTitle("Select Device")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { isPresented = false; ble.stopScan() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
