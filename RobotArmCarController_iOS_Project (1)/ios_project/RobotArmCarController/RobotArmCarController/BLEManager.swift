//
//  BLEManager.swift
//  RobotArmCarController
//
//  CoreBluetooth controller for the LAFVIN JDY-16 BLE module.
//  Matches the protocol confirmed in the official manual:
//    - Device advertises as "JDY-16"
//    - Service   0000FFE0-0000-1000-8000-00805F9B34FB
//    - Write Characteristic 0000FFE1-0000-1000-8000-00805F9B34FB (WRITE_NO_RESPONSE)
//    - Payload: single ASCII character, UTF-8 encoded, no terminator.
//

import Foundation
import CoreBluetooth
import Combine

enum ConnectionState: Equatable {
    case poweredOff
    case scanning
    case connecting
    case connected
    case disconnected
    case failed(String)

    var label: String {
        switch self {
        case .poweredOff: return "Bluetooth is off"
        case .scanning: return "Searching for JDY-16…"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

final class BLEManager: NSObject, ObservableObject {

    // Confirmed from the official manual (see RobotCommand.swift header).
    static let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    static let characteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    static let targetDeviceName = "JDY-16"

    @Published var state: ConnectionState = .disconnected
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var lastSentCommand: Character?
    @Published var autoConnectEnabled = true

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var scanTimeoutWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public controls

    func startScan() {
        guard central.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Stop scanning automatically after 15s per the manual's guidance
        // ("wait for 15 seconds" while searching for the JDY-16 device).
        scanTimeoutWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .scanning else { return }
            self.central.stopScan()
            if self.peripheral == nil {
                self.state = .failed("Device not found — try again, or pick it manually from the list")
            }
        }
        scanTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
    }

    func stopScan() {
        central.stopScan()
        scanTimeoutWorkItem?.cancel()
        if state == .scanning { state = .disconnected }
    }

    func connect(to peripheral: CBPeripheral) {
        central.stopScan()
        scanTimeoutWorkItem?.cancel()
        self.peripheral = peripheral
        peripheral.delegate = self
        state = .connecting
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    /// Sends a single-character command over BLE, exactly as the original
    /// app does: raw UTF-8 bytes of one ASCII character, write-without-response.
    func send(_ command: Character) {
        guard let peripheral, let characteristic = writeCharacteristic,
              let data = String(command).data(using: .utf8) else { return }
        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
        lastSentCommand = command
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            state = .disconnected
            if autoConnectEnabled { startScan() }
        case .poweredOff:
            state = .poweredOff
        default:
            state = .failed("Bluetooth unavailable")
        }
    }

    func centralManager(_ central: CBCentralManager,
                         didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any],
                         rssi RSSI: NSNumber) {
        guard !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        discoveredPeripherals.append(peripheral)

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? ""
        if autoConnectEnabled, name.contains(Self.targetDeviceName) {
            connect(to: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed(error?.localizedDescription ?? "Could not connect")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeCharacteristic = nil
        self.peripheral = nil
        state = .disconnected
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serviceUUID {
            peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didDiscoverCharacteristicsFor service: CBService,
                     error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Self.characteristicUUID {
            writeCharacteristic = characteristic
            state = .connected
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            state = .failed(error.localizedDescription)
        }
    }
}
