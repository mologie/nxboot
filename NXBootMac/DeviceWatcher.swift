import NXBootKit

@Observable
class DeviceWatcher: NXUSBDeviceEnumeratorDelegate {
    enum Connection: Equatable {
        case idle
        case error(String)
        case device(Device)
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

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceConnected device: Device) {
        connection = .device(device)
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceDisconnected device: Device) {
        if case let .device(oldDevice) = connection, oldDevice == device {
            connection = .idle
        }
        // otherwise, the user had multiple devices connected, and disconnected an older one
    }

    func usbDeviceEnumerator(_ deviceEnum: NXUSBDeviceEnumerator, deviceError err: String) {
        connection = .error(err)
    }
}
