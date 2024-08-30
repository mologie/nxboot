import Foundation

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
