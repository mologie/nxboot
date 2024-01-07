import NXBootKit

enum DeviceState: Equatable {
    case idle
    case error(String)
    case connected(NXUSBDevice)
}

@Observable
class DeviceModel: NXUSBDeviceEnumeratorDelegate {
    var device = DeviceState.idle
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
        self.device = DeviceState.connected(device)
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceDisconnected device: NXUSBDevice) {
        self.device = DeviceState.idle
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceError err: String) {
        self.device = DeviceState.error(err)
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
