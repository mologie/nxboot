import Combine
import NXBootKit
import SwiftUI

struct PayloadActionImage: View {
    var imageName: String
    var hoveringRow: Bool
    var hoveringButton: Bool

    var body: some View {
        Image(systemName: imageName)
            .renderingMode(.template)
            .foregroundColor(hoveringButton ? .accentColor : .primary)
            .opacity(hoveringRow ? 1.0 : 0.3)
            .padding([.trailing], 5)
    }
}

struct PayloadActionButton: View {
    var hoveringRow: Bool
    var imageName: String
    var action: () -> Void

    @State private var hoveringButton: Bool = false

    var body: some View {
        Button(action: action) {
            PayloadActionImage(imageName: imageName, hoveringRow: hoveringRow, hoveringButton: hoveringButton)
        }
        .buttonStyle(.plain)
        .onHover(perform: { hovering in hoveringButton = hovering })
    }
}

enum PayloadError: LocalizedError {
    case importFailed(Error)
    case renameFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .importFailed(_): return "Error Importing Payload"
        case .renameFailed(_): return "Error Renaming Payload"
        case .deleteFailed(_): return "Error Deleting Payload"
        }
    }

    var failureReason: String? {
        switch self {
        case .importFailed(let error): return error.localizedDescription
        case .renameFailed(let error): return error.localizedDescription
        case .deleteFailed(let error): return error.localizedDescription
        }
    }
}

struct PayloadView: View {
    @Binding var payload: Payload
    @Binding var selectPayload: Payload?
    @Binding var renamePayload: Payload?
    var deletePayload: (Payload) -> Void

    @State private var hoveringRow = false
    @State private var hoveringDragHandle: Bool = false

    private var payloadDate: String {
        guard let fileDate = payload.fileModificationDate else {
            return "[no date]"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: fileDate)
    }

    private var payloadSize: String {
        guard let fileSize = payload.fileSize else {
            return "[no size]"
        }
        return "\(fileSize / 1024) KiB"
    }

    var body: some View {
        HStack {
            Button(action: {
                selectPayload = payload
            }) {
                Image(systemName: "arrow.forward")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.accentColor)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24)
                    .opacity(selectPayload == payload ? 1.0 : 0.0)
                VStack(alignment: .leading) {
                    Text(payload.name)
                    Text("From \(payloadDate) (\(payloadSize))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            PayloadActionButton(hoveringRow: hoveringRow, imageName: "rectangle.and.pencil.and.ellipsis") {
                renamePayload = payload
            }

            PayloadActionButton(hoveringRow: hoveringRow, imageName: "trash") {
                deletePayload(payload)
            }

            // no button, event bubbles up and list handles sorting
            PayloadActionImage(imageName: "arrow.up.and.down.and.arrow.left.and.right", hoveringRow: hoveringRow, hoveringButton: hoveringDragHandle)
                .onHover(perform: { hovering in hoveringDragHandle = hovering })
        }
        .onHover { hovering in hoveringRow = hovering }
    }
}

enum LastBootState {
    case notAttempted
    case inProgress
    case succeeded
    case failed(Error)
}

@MainActor
struct MainView: View {
    @Environment(\.undoManager) var undoManager
    @Binding public var payloads: [Payload]
    @Binding public var selectPayload: Payload?
    @Binding public var device: DeviceState
    @Binding public var lastBoot: LastBootState
    @Binding public var autoBoot: Bool
    public var onBootPayload: @MainActor (Payload, NXUSBDevice) async -> Void
    public var onSelectPayload: @MainActor () async -> Void
    public var onImportPayload: @MainActor (URL) async throws -> Payload
    public var onRenamePayload: @MainActor (Payload, String) throws -> Void
    public var onDeletePayload: @MainActor (Payload) throws -> URL

    @State private var renamePayload: Payload?
    @State private var renameTo: String = ""
    @FocusState private var renameFocused

    @State private var showError = false
    @State private var lastError: PayloadError?

    var deviceTitle: String {
        switch device {
        case .idle:
            return "Waiting for device..."
        case .error(_):
            return "USB error"
        case .connected(_):
            return "Device connected in RCM mode"
        }
    }

    var deviceFootnote: String {
        switch device {
        case .idle:
            let message: String
            if autoBoot {
                if selectPayload != nil {
                    message = "Selected payload will be booted on connection"
                } else {
                    message = "Select a payload to boot it on connection"
                }
            } else {
                message = "Connect your Tegra X1 device in RCM mode"
            }
            switch lastBoot {
            case .succeeded:
                return "\(message). Last boot succeeded."
            case .failed(let bootError):
                return "\(message). Last boot: \(bootError.localizedDescription)"
            default:
                return message
            }
        case .error(let errorDescription):
            return errorDescription
        case .connected(_):
            switch lastBoot {
            case .notAttempted:
                return "Ready to boot"
            case .inProgress:
                return "Booting..."
            case .succeeded:
                return "Payload started 🎉"
            case .failed(let bootError):
                return bootError.localizedDescription
            }
        }
    }

    var deviceStatusColor: Color {
        switch device {
        case .idle, .error(_):
            return .red
        case .connected(_):
            switch lastBoot {
            case .notAttempted, .succeeded: return .green
            case .inProgress: return .yellow
            case .failed(_): return .red
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($payloads, id: \.self) { payload in
                    PayloadView(
                        payload: payload,
                        selectPayload: $selectPayload,
                        renamePayload: $renamePayload,
                        deletePayload: { deletePayload($0) }
                    )
                }
                .onMove(perform: { movePayload(from: $0, to: $1) })
                .onDelete(perform: { deletePayload(at: $0) })
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .environment(\.defaultMinListRowHeight, 40)
            .onDrop(of: [.fileURL], isTargeted: nil, perform: { doDrop(providers: $0) })
            .border(.bottom)

            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .foregroundColor(deviceStatusColor)
                        .frame(width: 16, height: 16)
                    VStack(alignment: .leading) {
                        Text(deviceTitle)
                        Text(deviceFootnote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !autoBoot {
                    Button(action: {
                        guard let payload = selectPayload else { return }
                        guard case let .connected(device) = device else { return }
                        Task { @MainActor in
                            await onBootPayload(payload, device)
                        }
                    }, label: {
                        Text("Boot Payload")
                            .frame(height: 26)
                            .padding([.leading, .trailing], 10)
                    })
                    .buttonStyle(.borderedProminent)
                    .disabled({
                        if selectPayload == nil { return true }
                        guard case .connected(_) = device else { return true }
                        guard case .notAttempted = lastBoot else { return true }
                        return false
                    }())
                }
            }
            .padding()
            .background(TranslucentBackgroundView())
        }
        .navigationTitle("NXBoot")
        .navigationSubtitle(selectPayload != nil ? "using \(selectPayload!.name)" : "no payload selected")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    Task { @MainActor in
                        await onSelectPayload()
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            ToolbarItemGroup(
                placement: .automatic,
                content: {
                    Picker(
                        selection: $autoBoot,
                        content: {
                            Text("auto-boot").tag(true)
                            Text("manual").tag(false)
                        }, label: {}
                    )
                    .pickerStyle(InlinePickerStyle())
                    .padding([.leading])
                })
        }
        .sheet(item: $renamePayload) { payload in
            VStack(spacing: 10) {
                Image(systemName: "pencil")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36)
                    .padding(5)
                Text("Rename Payload").fontWeight(.bold)
                Text("Please enter a new name for \(payload.name):")
                TextField("New Name", text: $renameTo)
                    .focused($renameFocused)
                    .defaultFocus($renameFocused, true)
                    .padding([.top, .bottom], 5)
                    .onSubmit { renamePayloadCommit() }
                HStack {
                    Button(
                        action: { renamePayload = nil },
                        label: {
                            Text("Cancel")
                                .frame(height: 26)
                                .frame(maxWidth: .infinity)
                        })
                    Button(
                        action: { renamePayloadCommit() },
                        label: {
                            Text("Rename")
                                .frame(height: 26)
                                .frame(maxWidth: .infinity)
                        }
                    ).buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 260)
            .onDisappear { renameTo = "" }
        }
        .alert(isPresented: $showError, error: lastError) { _ in
            Button("OK") { showError = false }
        } message: { error in
            Text(error.failureReason ?? "Failure reason could not be determined.")
        }
    }

    private func doDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    guard let url = url else { return }
                    Task { @MainActor in
                        do {
                            try await importPayload(url)
                        } catch {
                            lastError = PayloadError.importFailed(error)
                            showError = true
                        }
                    }
                }
            }
        }
        return true
    }

    private func importPayload(_ url: URL) async throws {
        let payload = try await onImportPayload(url)
        if !autoBoot {
            selectPayload = payload
        }
    }

    private func movePayload(from source: IndexSet, to destination: Int) {
        payloads.move(fromOffsets: source, toOffset: destination)
        // didSet property observer in view model stores new explicit order
    }

    private func renamePayloadCommit() {
        guard let payload = renamePayload else { return }
        do {
            try onRenamePayload(payload, renameTo)
            renamePayload = nil
        } catch {
            lastError = PayloadError.renameFailed(error)
            showError = true
        }
    }

    private func deletePayload(_ payload: Payload) {
        deletePayload(at: IndexSet(integer: payloads.firstIndex(of: payload)!))
    }

    private func deletePayload(at offsets: IndexSet) {
        let payloads = payloads
        for index in offsets {
            do {
                let trashURL = try onDeletePayload(payloads[index])
                /*
                undoManager?.registerUndo(withTarget: model, handler: { model in
                    // TODO: redo
                })
                */
            } catch {
                lastError = PayloadError.deleteFailed(error)
                showError = true
                break
            }
        }
    }
}

struct MainPreviewView: View {
    @State var payloads: [Payload] = [
        Payload(URL(fileURLWithPath: "/tmp/foo.bin")),
        Payload(URL(fileURLWithPath: "/tmp/bar.bin")),
        Payload(URL(fileURLWithPath: "/tmp/baz.bin")),
    ]
    @State var selectPayload: Payload? = nil
    @State var autoBoot: Bool = false

    var body: some View {
        MainView(
            payloads: $payloads,
            selectPayload: $selectPayload,
            device: .constant(.idle),
            lastBoot: .constant(.notAttempted),
            autoBoot: $autoBoot,
            onBootPayload: { payload, device in },
            onSelectPayload: {
                let unixTime = NSDate().timeIntervalSince1970
                let payload = Payload(URL(fileURLWithPath: "/tmp/payload\(unixTime).bin"))
                payloads.append(payload)
                if !autoBoot {
                    selectPayload = payload
                }
            },
            onImportPayload: {
                let payload = Payload($0)
                payloads.append(payload)
                if !autoBoot {
                    selectPayload = payload
                }
                return payload
            },
            onRenamePayload: { payload, name in
                guard let index = payloads.firstIndex(of: payload) else { return }
                payloads[index].name = name
            },
            onDeletePayload: { payload in
                payloads.removeAll(where: { $0 == payload })
                return payload.url
            })
    }
}

#Preview {
    MainPreviewView()
}
