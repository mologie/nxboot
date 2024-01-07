import AppKit
import Combine
import Foundation
import NXBootKit // for max payload size

@Observable
final class Payload: Identifiable, Equatable, Hashable {
    var url: URL
    var fileSize: Int?
    var fileModificationDate: Date?

    var fileName: String { url.lastPathComponent }
    var name: String {
        get { url.deletingPathExtension().lastPathComponent }
        set {
            url = url.deletingLastPathComponent()
                .appending(component: newValue.replacing(/[\/:]/, with: " "))
                .appendingPathExtension(url.pathExtension)
        }
    }

    init(_ from: URL) {
        url = from
        let rv = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        fileSize = rv?.fileSize
        fileModificationDate = rv?.contentModificationDate
    }

    // The single view model guarantees that IDs and paths have a 1:1 relationship. However, since
    // the path is mutated while the object is in dicts, it cannot be used as identity property.
    let id = UUID()
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Payload, rhs: Payload) -> Bool { return lhs.id == rhs.id }
}

enum PayloadModelError: LocalizedError {
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

@Observable
@MainActor
class PayloadModel {
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

    public let payloadsFolder: URL

    private var refreshTask: Task<Void, Error>?
    private var refreshWatcher: DispatchSourceFileSystemObject

    init(payloadsFolder url: URL) throws {
        payloadsFolder = url
        payloads = []

        try FileManager.default.createDirectory(at: payloadsFolder, withIntermediateDirectories: true)
        let fd = open(payloadsFolder.path, O_EVTONLY)
        guard fd >= 0 else { throw PayloadModelError.observingFolderFailed }
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
            at: payloadsFolder,
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
    func importPayload(_ fromURL: URL) async throws -> Payload {
        let name = fromURL.deletingPathExtension().lastPathComponent
        let newURL = payloadsFolder.appending(component: "\(name).bin")
        let copyTask = Task.detached(priority: .userInitiated) {
            // async because this might come from a network source, so copying will take time
            let rv = try fromURL.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = rv.fileSize else {
                throw PayloadModelError.fileResourceUnavailable(.fileSizeKey)
            }
            if fileSize > NXMaxFuseePayloadSize {
                throw PayloadModelError.fileSizeExceeded(fromURL)
            }
            try FileManager.default.copyItem(at: fromURL, to: newURL)
        }
        try await copyTask.value
        let payload = Payload(newURL)
        payloads.append(payload)
        return payload
    }

    func renamePayload(_ payload: Payload, name: String) throws {
        let newURL = payloadsFolder.appending(component: "\(name).bin")
        try FileManager.default.moveItem(at: payload.url, to: newURL)
        payload.url = newURL
    }

    @discardableResult
    func deletePayload(_ payload: Payload) throws -> URL {
        var trashURL: NSURL?
        try FileManager.default.trashItem(at: payload.url, resultingItemURL: &trashURL)
        return trashURL! as URL
    }
}
