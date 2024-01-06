import AppKit
import Foundation
import Combine

class Payload: Identifiable, Equatable, Hashable, ObservableObject {
    @Published var url: URL
    @Published var fileSize: Int?
    @Published var fileModificationDate: Date?

    var fileName: String { url.lastPathComponent }
    var name: String {
        get { url.deletingPathExtension().lastPathComponent }
        set { url = url.deletingLastPathComponent()
                .appending(component: newValue.replacing(/[\/:]/, with: " "))
                .appendingPathExtension(url.pathExtension) }
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

class PayloadViewModel: ObservableObject {
    @Published var payloads: [Payload] {
        didSet {
            UserDefaults.standard.set(payloads.map { $0.fileName }, forKey: "NXBootPayloadsExplicitOrder")
            if let bootPayload, payloads.firstIndex(of: bootPayload) == nil {
                self.bootPayload = nil // because the boot payload is no longer available
            }
        }
    }
    @Published var bootPayload: Payload? {
        didSet {
            UserDefaults.standard.set(bootPayload?.fileName, forKey: "NXBootSelectedPayload")
        }
    }

    public let payloadsFolder: URL

    private var refreshDebounceItem: DispatchWorkItem?
    private lazy var refreshWatcher: DispatchSourceFileSystemObject = {
        let fileDescriptor = open(payloadsFolder.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { fatalError("failed to open payload folder for events") }
        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete],
            queue: DispatchQueue.global(qos: .default)
        )
        watcher.setEventHandler { [weak self] in
            // debounce in case of a flood of update events
            guard let self = self else { return }
            let workItem = DispatchWorkItem { [weak self] in self?.refreshPayloads() }
            self.refreshDebounceItem?.cancel()
            self.refreshDebounceItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: workItem)
        }
        watcher.setCancelHandler {
            close(fileDescriptor)
        }
        return watcher
    }()

    init(payloadsFolder url: URL) throws {
        payloadsFolder = url
        try FileManager.default.createDirectory(at: payloadsFolder, withIntermediateDirectories: true)

        payloads = try PayloadViewModel.loadPayloads(payloadsFolder: payloadsFolder)
        if let bootFileName = UserDefaults.standard.string(forKey: "NXBootSelectedPayload") {
            bootPayload = payloads.first(where: { $0.fileName == bootFileName })
        }

        refreshWatcher.resume()
    }

    deinit {
        refreshWatcher.cancel()
    }

    func refreshPayloads() {
        do {
            let currentPaths = Set(self.payloads.map { $0.url })
            let availablePayloads = try loadPayloads()
            let availablePaths = Set(availablePayloads.map { $0.url })
            self.payloads.append(contentsOf: availablePayloads.filter { !currentPaths.contains($0.url) })
            self.payloads.removeAll(where: { !availablePaths.contains($0.url) })
        } catch {
            fatalError("failed to refresh payload list: \(error)")
        }
    }

    private func loadPayloads() throws -> [Payload] {
        return try PayloadViewModel.loadPayloads(payloadsFolder: payloadsFolder)
    }

    static private func loadPayloads(payloadsFolder: URL) throws -> [Payload] {
        var unorderedPayloads = try FileManager.default.contentsOfDirectory(
            at: payloadsFolder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
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

    func importPayload(_ fromURL: URL) throws -> Payload {
        let name = fromURL.deletingPathExtension().lastPathComponent
        let newURL = payloadsFolder.appending(component: "\(name).bin")
        try FileManager.default.copyItem(at: fromURL, to: newURL)
        let payload = Payload(newURL)
        payloads.append(payload)
        return payload
    }

    func renamePayload(_ payload: Payload, name: String) throws {
        let newURL = payloadsFolder.appending(component: "\(name).bin")
        try FileManager.default.moveItem(at: payload.url, to: newURL)
        payload.url = newURL
    }

    func deletePayload(_ payload: Payload) throws {
        try FileManager.default.trashItem(at: payload.url, resultingItemURL: nil)
    }
}
