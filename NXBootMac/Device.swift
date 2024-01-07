import NXBootKit

typealias Device = NXUSBDevice

extension Device: @unchecked Sendable {
    struct BootError: LocalizedError {
        let error: String
        var errorDescription: String? { "Error launching payload. \(error)" }
    }

    func boot(_ payload: Data, intermezzo: Data) throws {
        var error: NSString?
        if !NXExec(self, intermezzo, payload, &error) {
            throw BootError(error: error! as String)
        }
    }
}
