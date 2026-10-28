import CoreBluetooth

/// The LINAK DPG Bluetooth protocol spoken by IKEA IDÅSEN and other LINAK-based desks.
@MainActor
enum DeskProtocol {
    static let controlService = CBUUID(string: "99FA0001-338A-1024-8A49-009C0215F78A")
    static let command = CBUUID(string: "99FA0002-338A-1024-8A49-009C0215F78A")
    static let outputService = CBUUID(string: "99FA0020-338A-1024-8A49-009C0215F78A")
    static let height = CBUUID(string: "99FA0021-338A-1024-8A49-009C0215F78A")
    static let inputService = CBUUID(string: "99FA0030-338A-1024-8A49-009C0215F78A")
    static let referenceInput = CBUUID(string: "99FA0031-338A-1024-8A49-009C0215F78A")

    static let services = [controlService, outputService, inputService]
    static let characteristics = [command, height, referenceInput]

    static let wakeUp = Data([0xFE, 0x00])
    static let stop = Data([0xFF, 0x00])
    /// Ends a move started through the reference input.
    static let referenceStop = Data([0x01, 0x80])

    /// Height range of the desk frame, in centimetres.
    static let range = 62.0...127.0

    /// Decodes a height report: a little-endian UInt16 height in 0.1 mm above the
    /// lowest position, optionally followed by an Int16 speed.
    static func decode(_ data: Data) -> (height: Double, speed: Int)? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }
        let raw = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        let speed = bytes.count >= 4 ? Int(Int16(bitPattern: UInt16(bytes[2]) | UInt16(bytes[3]) << 8)) : 0
        return (range.lowerBound + Double(raw) / 100, speed)
    }

    /// Encodes a target height for the reference input.
    static func encode(height: Double) -> Data {
        let raw = UInt16(((height.clamped(to: range) - range.lowerBound) * 100).rounded())
        return Data([UInt8(raw & 0xFF), UInt8(raw >> 8)])
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
