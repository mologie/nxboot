import Foundation

class FolderWatcher {
    private var debounceTask: Task<Void, Error>?
    private var fso: DispatchSourceFileSystemObject

    init(_ url: URL, action: @MainActor @Sendable @escaping () async -> Void) throws {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { throw FolderWatcherError.openFailed }
        fso = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete],
            queue: DispatchQueue.global(qos: .default)
        )
        fso.setCancelHandler {
            // NB: only invoked upon explicit cancelation
            close(fd)
        }
        fso.setEventHandler { [weak self] in
            // debounce in case of a flood of update events
            guard let self = self else { return }
            self.debounceTask = Task {
                try await Task.sleep(for: .milliseconds(100))
                await action()
            }
        }
        fso.resume()
    }

    deinit {
        fso.cancel()
    }
}

enum FolderWatcherError: Error {
    case openFailed
}
