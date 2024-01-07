import Combine
import Foundation
import NXBootKit

@MainActor
protocol PayloadStorage: Observable, AnyObject {
    var payloads: [Payload] { get set }
    var bootPayload: Payload? { get set }

    @discardableResult
    func importPayload(_ fromURL: URL, at index: Int?, withName name: String?, move: Bool) async throws -> Payload

    func renamePayload(_ payload: Payload, name: String) throws

    @discardableResult
    func deletePayload(_ payload: Payload) throws -> URL?
}

@Observable
class PayloadStorageFolder: PayloadStorage {
    var payloads: [Payload] {
        didSet {
            UserDefaults.standard.set(payloads.map { $0.fileName }, forKey: "NXBootPayloadsExplicitOrder")
            if let bootPayload, payloads.firstIndex(of: bootPayload) == nil {
                self.bootPayload = nil  // because the boot payload is no longer available
            }
        }
    }
    var bootPayload: Payload? {
        didSet {
            UserDefaults.standard.set(bootPayload?.fileName, forKey: "NXBootSelectedPayload")
        }
    }

    public let rootPath: URL

    private var refreshTask: Task<Void, Error>?
    private var refreshWatcher: DispatchSourceFileSystemObject

    init(rootPath url: URL) throws {
        rootPath = url
        payloads = []

        try FileManager.default.createDirectory(at: rootPath, withIntermediateDirectories: true)
        let fd = open(rootPath.path, O_EVTONLY)
        guard fd >= 0 else { throw ModelError.observingFolderFailed }
        refreshWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete],
            queue: DispatchQueue.global(qos: .default)
        )
        refreshWatcher.setCancelHandler {
            close(fd)
        }
        refreshWatcher.setEventHandler { [weak self] in
            // debounce in case of a flood of update events
            guard let self = self else { return }
            self.refreshTask = Task { [weak self] in
                try await Task.sleep(for: .milliseconds(100))
                self?.refreshPayloads()
            }
        }
        refreshWatcher.resume()

        payloads = try loadPayloads()
        if let bootFileName = UserDefaults.standard.string(forKey: "NXBootSelectedPayload") {
            bootPayload = payloads.first(where: { $0.fileName == bootFileName })
        }
    }

    deinit {
        // TODO: refreshWatcher.cancel()
    }

    func refreshPayloads() {
        do {
            let currentPaths = Set(self.payloads.map { $0.url })
            let availablePayloads = try loadPayloads()
            let availablePaths = Set(availablePayloads.map { $0.url })
            self.payloads.append(contentsOf: availablePayloads.filter { !currentPaths.contains($0.url) })
            self.payloads.removeAll(where: { !availablePaths.contains($0.url) })
        } catch {
            print("DirWatcher: Failed to refresh payload list: \(error.localizedDescription)")
        }
    }

    private func loadPayloads() throws -> [Payload] {
        var unorderedPayloads = try FileManager.default.contentsOfDirectory(
            at: rootPath,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        )
        .filter { $0.path.hasSuffix(".bin") && (try! $0.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile! }
        .map { Payload($0) }
        var result: [Payload] = []
        let explicitOrder = UserDefaults.standard.stringArray(forKey: "NXBootPayloadsExplicitOrder")
        if let explicitOrder {
            for fileName in explicitOrder {
                if let index = unorderedPayloads.firstIndex(where: { $0.fileName == fileName }) {
                    result.append(unorderedPayloads[index])
                    unorderedPayloads.remove(at: index)
                }
            }
        }
        result.append(contentsOf: unorderedPayloads.sorted(by: { $0.fileName < $1.fileName }))
        return result
    }

    @discardableResult
    func importPayload(_ fromURL: URL, at index: Int?, withName name: String?, move: Bool) async throws -> Payload {
        let name = name ?? fromURL.deletingPathExtension().lastPathComponent
        let newURL = rootPath.appending(component: "\(name).bin")
        let fileOp = Task.detached(priority: .userInitiated) {
            // async because this might come from a network source, so copying will take time
            let rv = try fromURL.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = rv.fileSize else {
                throw ModelError.fileResourceUnavailable(.fileSizeKey)
            }
            if fileSize > NXMaxFuseePayloadSize {
                throw ModelError.fileSizeExceeded(fromURL)
            }
            if move {
                try FileManager.default.moveItem(at: fromURL, to: newURL)
            } else {
                try FileManager.default.copyItem(at: fromURL, to: newURL)
            }
        }
        try await fileOp.value
        let payload = Payload(newURL)
        if let index, index <= payloads.count {
            payloads.insert(payload, at: index)
        } else {
            payloads.append(payload)
        }
        return payload
    }

    func renamePayload(_ payload: Payload, name: String) throws {
        let newURL = rootPath.appending(component: "\(name).bin")
        try FileManager.default.moveItem(at: payload.url, to: newURL)
        payload.url = newURL
    }

    @discardableResult
    func deletePayload(_ payload: Payload) throws -> URL? {
        var trashURL: NSURL?
        try FileManager.default.trashItem(at: payload.url, resultingItemURL: &trashURL)
        return trashURL as URL?
    }

    enum ModelError: LocalizedError {
        case fileResourceUnavailable(URLResourceKey)
        case fileSizeExceeded(URL)
        case observingFolderFailed

        var errorDescription: String? {
            switch self {
            case .fileResourceUnavailable(let key):
                return "Could not fetch payload file attribute \(key)."
            case .fileSizeExceeded(let url):
                return "\"\(url.lastPathComponent)\" does not appear to be a valid payload. Payloads must be at most \(NXMaxFuseePayloadSize / 1024) KiB large to fit into IRAM."
            case .observingFolderFailed:
                return "Internal error: Failed to begin observing changes in the Payloads storage folder."
            }
        }
    }
}

@Observable
class PayloadStorageDummy: PayloadStorage {
    var payloads: [Payload] = [
        Payload(URL(fileURLWithPath: "/tmp/foo.bin")),
        Payload(URL(fileURLWithPath: "/tmp/bar.bin")),
        Payload(URL(fileURLWithPath: "/tmp/baz.bin")),
    ]

    var bootPayload: Payload? = nil

    func importPayload(_ fromURL: URL, at index: Int?, withName name: String?, move: Bool) async throws -> Payload {
        let payload = Payload(fromURL)
        payloads.append(payload)
        return payload
    }

    func renamePayload(_ payload: Payload, name: String) throws {
        guard let index = payloads.firstIndex(of: payload) else { return }
        payloads[index].name = name
    }

    func deletePayload(_ payload: Payload) throws -> URL? {
        payloads.removeAll(where: { $0 == payload })
        return payload.url
    }
}
