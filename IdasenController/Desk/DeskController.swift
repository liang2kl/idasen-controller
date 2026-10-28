import CoreBluetooth
import Observation

/// Finds, connects to and drives a LINAK desk over Bluetooth.
@MainActor @Observable
final class DeskController: NSObject {
    enum State: Equatable {
        case bluetoothOff
        case unauthorized
        case scanning
        case connecting
        case connected
    }

    private(set) var state = State.scanning
    private(set) var deskName: String?
    /// Current height in centimetres, once the desk has reported it.
    private(set) var height: Double?
    /// Height the desk is heading to while a move is in progress.
    private(set) var target: Double?

    var isConnected: Bool { state == .connected }
    var isMoving: Bool { target != nil }

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var commandCharacteristic: CBCharacteristic?
    @ObservationIgnored private var heightCharacteristic: CBCharacteristic?
    @ObservationIgnored private var referenceCharacteristic: CBCharacteristic?
    @ObservationIgnored private var speed = 0
    @ObservationIgnored private var moveTask: Task<Void, Never>?
    @ObservationIgnored private var hold: (start: ContinuousClock.Instant, height: Double, up: Bool)?

    private static let savedDeskKey = "deskIdentifier"
    private var savedDeskID: UUID? {
        get { UserDefaults.standard.string(forKey: Self.savedDeskKey).flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: Self.savedDeskKey) }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: Movement

    /// Moves the desk to `height` centimetres, retargeting any move in progress.
    func move(to height: Double) {
        guard isConnected else { return }
        let target = height.clamped(to: DeskProtocol.range)
        let wasMoving = isMoving
        moveTask?.cancel()
        self.target = target
        moveTask = Task { [weak self] in
            await self?.drive(to: target, wake: !wasMoving)
        }
    }

    func stop() {
        hold = nil
        moveTask?.cancel()
        moveTask = nil
        target = nil
        write(DeskProtocol.stop, to: commandCharacteristic)
        write(DeskProtocol.referenceStop, to: referenceCharacteristic)
    }

    /// Starts moving while an arrow button is held down.
    func beginHold(up: Bool) {
        guard let height, isConnected else { return }
        hold = (.now, height, up)
        move(to: up ? DeskProtocol.range.upperBound : DeskProtocol.range.lowerBound)
    }

    /// Stops a held move; a quick click nudges the desk by one centimetre instead.
    func endHold() {
        guard let hold else { return }
        self.hold = nil
        if hold.start.duration(to: .now) < .milliseconds(300) {
            move(to: hold.height + (hold.up ? 1 : -1))
        } else {
            stop()
        }
    }

    private func drive(to target: Double, wake: Bool) async {
        if Task.isCancelled { return }
        if let height, abs(height - target) < 0.3 {
            return stop()
        }
        if wake {
            // The reference input only listens after a wake-up and stop command.
            write(DeskProtocol.wakeUp, to: commandCharacteristic)
            write(DeskProtocol.stop, to: commandCharacteristic)
        }
        let payload = DeskProtocol.encode(height: target)
        let start = ContinuousClock.now
        while start.duration(to: .now) < .seconds(30) {
            write(payload, to: referenceCharacteristic)
            if let heightCharacteristic { peripheral?.readValue(for: heightCharacteristic) }
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
            // The desk reports zero speed once it has arrived or hit an obstacle.
            if let height, speed == 0, abs(height - target) < 0.5 || start.duration(to: .now) > .seconds(1) {
                break
            }
        }
        stop()
    }

    private func write(_ data: Data, to characteristic: CBCharacteristic?) {
        guard let characteristic, let peripheral else { return }
        let type: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: type)
    }

    // MARK: Connection

    /// Forgets the remembered desk and searches for any nearby desk.
    func forgetDesk() {
        savedDeskID = nil
        disconnect()
        connect()
    }

    /// Drops the current connection attempt and starts over.
    func reconnect() {
        disconnect()
        connect()
    }

    private func connect() {
        guard central.state == .poweredOn else { return }
        if let id = savedDeskID, let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(known)
        } else if let connected = central.retrieveConnectedPeripherals(withServices: [DeskProtocol.controlService]).first {
            connect(connected)
        } else {
            state = .scanning
            central.scanForPeripherals(withServices: nil)
        }
    }

    private func connect(_ peripheral: CBPeripheral) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        deskName = peripheral.name
        state = .connecting
        // Connection requests never time out, so a desk that is out of range
        // or powered off is picked up as soon as it comes back.
        central.connect(peripheral)
    }

    private func disconnect() {
        if central.state == .poweredOn {
            central.stopScan()
            if let peripheral { central.cancelPeripheralConnection(peripheral) }
        }
        peripheral = nil
        resetSession()
        deskName = nil
        height = nil
    }

    private func resetSession() {
        moveTask?.cancel()
        moveTask = nil
        target = nil
        hold = nil
        commandCharacteristic = nil
        heightCharacteristic = nil
        referenceCharacteristic = nil
    }

    private static func isDesk(_ peripheral: CBPeripheral, advertisement: [String: Any]) -> Bool {
        let services = advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let name = advertisement[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        return services.contains(DeskProtocol.controlService) || name.hasPrefix("Desk")
    }
}

extension DeskController: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connect()
        case .unauthorized:
            disconnect()
            state = .unauthorized
        case .poweredOff, .unsupported:
            disconnect()
            state = .bluetoothOff
        default:
            disconnect()
            state = .scanning
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        guard state == .scanning, Self.isDesk(peripheral, advertisement: advertisementData) else { return }
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == self.peripheral else { return }
        savedDeskID = peripheral.identifier
        deskName = peripheral.name
        peripheral.discoverServices(DeskProtocol.services)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        guard peripheral == self.peripheral else { return }
        state = .connecting
        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.peripheral == peripheral { self.central.connect(peripheral) }
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?
    ) {
        guard peripheral == self.peripheral, central.state == .poweredOn else { return }
        resetSession()
        state = .connecting
        central.connect(peripheral)
    }
}

extension DeskController: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(DeskProtocol.characteristics, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?
    ) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case DeskProtocol.command:
                commandCharacteristic = characteristic
            case DeskProtocol.referenceInput:
                referenceCharacteristic = characteristic
            case DeskProtocol.height:
                heightCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }
        if commandCharacteristic != nil, heightCharacteristic != nil, referenceCharacteristic != nil {
            state = .connected
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?
    ) {
        guard characteristic.uuid == DeskProtocol.height,
              let value = characteristic.value, let report = DeskProtocol.decode(value)
        else { return }
        height = report.height
        speed = report.speed
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        deskName = peripheral.name
    }
}
