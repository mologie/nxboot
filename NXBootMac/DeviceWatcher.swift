import NXBootKit

@Observable
class DeviceWatcher: NXUSBDeviceEnumeratorDelegate {
    enum Connection: Equatable {
        case idle
        case error(String)
        case device(NXUSBDevice)
    }

    var connection = Connection.idle

    private var usbEnumerator = NXUSBDeviceEnumerator()

    init() {
        usbEnumerator.delegate = self
        usbEnumerator.setFilterForVendorID(UInt16(kTegraX1VendorID), productID: UInt16(kTegraX1ProductID))
        usbEnumerator.start()
    }

    deinit {
        usbEnumerator.stop()
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceConnected device: NXUSBDevice) {
        connection = .device(device)
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceDisconnected device: NXUSBDevice) {
        if case let .device(oldDevice) = connection, oldDevice == device {
            connection = .idle
        }
        // otherwise, the user had multiple devices connected, and disconnected an older one
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceError err: String) {
        connection = .error(err)
    }
}

struct BootError: LocalizedError {
    let error: String
    var errorDescription: String? { "Error launching payload. \(error)" }
}

extension NXUSBDevice: @unchecked Sendable {
    func boot(_ payload: Data, intermezzo: Data) throws {
        var error: NSString?
        if !NXExec(self, intermezzo, payload, &error) {
            throw BootError(error: error! as String)
        }
    }
}

enum LastBootState {
    case notAttempted
    case inProgress
    case succeeded
    case failed(Error)
}
