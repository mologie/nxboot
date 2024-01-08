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
    var payloads: [Payload] = [] {
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

    // TODO: would prefer to initialize with a single container, not track cloud stuff here
    private let localContainer: URL
    private var localWatcher: FolderWatcher?
    private var cloudContainer: URL?
    private var cloudWatcher: FolderWatcher?

    public var cloudSync: Bool = false {
        didSet {
            Task { @MainActor in await refreshPayloads() }
        }
    }

    public var effectiveContainer: URL {
        if let cloudContainer, cloudSync {
            return cloudContainer
        } else {
            return localContainer
        }
    }

    init(localContainer url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        localContainer = url
        localWatcher = try FolderWatcher(url) {
            [weak self] in await self?.refreshPayloads()
        }
        Task { @MainActor in
            // TODO: busy/loading indicator
            try await refreshCloudContainer()
            await refreshPayloads()
            if let bootFileName = UserDefaults.standard.string(forKey: "NXBootSelectedPayload") {
                bootPayload = payloads.first(where: { $0.fileName == bootFileName })
            }
        }
    }

    func refreshCloudContainer() async throws {
        let setupTask = Task.detached(priority: .utility) {
            FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appending(path: "Documents", directoryHint: .isDirectory)
        }
        cloudContainer = await setupTask.value
        if let cloudContainer {
            cloudWatcher = try FolderWatcher(cloudContainer) {
                [weak self] in await self?.refreshPayloads()
            }
        } else {
            cloudWatcher = nil
        }
        await refreshPayloads()
    }

    func refreshPayloads() async {
        do {
            let currentSet = Set(self.payloads.map { $0.name })
            let availablePayloads = try await loadPayloads(effectiveContainer)
            let availableDict = Dictionary(grouping: availablePayloads, by: { $0.name }).mapValues { $0.first! }
            let availableSet = Set(availablePayloads.map { $0.name })
            self.payloads.removeAll(where: { !availableSet.contains($0.name) })
            self.payloads.forEach { payload in
                // payload might have moved to/from cloud, so refresh its URL
                payload.url = availableDict[payload.name]!.url
            }
            self.payloads.append(contentsOf: availablePayloads.filter { !currentSet.contains($0.name) })
        } catch {
            print("DirWatcher: Failed to refresh payload list: \(error.localizedDescription)")
        }
    }

    private func loadPayloads(_ url: URL) async throws -> [Payload] {
        let dirListTask = Task.detached(priority: .utility) {
            try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
            )
            .filter { $0.path.hasSuffix(".bin") && (try! $0.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile! }
        }
        var unorderedPayloads = try await dirListTask.value.map { Payload($0) }
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
        result.append(contentsOf: unorderedPayloads.sorted(by: {
            $0.fileName.lowercased() < $1.fileName.lowercased()
        }))
        return result
    }

    @discardableResult
    func importPayload(_ fromURL: URL, at index: Int?, withName name: String?, move: Bool) async throws -> Payload {
        let name = name ?? fromURL.deletingPathExtension().lastPathComponent
        let newURL = effectiveContainer.appending(component: "\(name).bin")
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
        let newURL = effectiveContainer.appending(component: "\(name).bin")
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

        var errorDescription: String? {
            switch self {
            case .fileResourceUnavailable(let key):
                return "Could not fetch payload file attribute \(key)."
            case .fileSizeExceeded(let url):
                return "\"\(url.lastPathComponent)\" does not appear to be a valid payload. Payloads must be at most \(NXMaxFuseePayloadSize / 1024) KiB large to fit into IRAM."
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
