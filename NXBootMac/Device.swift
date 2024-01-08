import NXBootKit

typealias Device = NXUSBDevice

extension Device: @unchecked Sendable {
    struct BootError: LocalizedError {
        let message: String
        var errorDescription: String? { "Error launching payload. \(message)" }
    }

    func boot(_ payload: Data, intermezzo: Data) throws {
        var error: NSString?
        if !NXExec(self, intermezzo, payload, &error) {
            throw BootError(message: error! as String)
        }
    }
}
