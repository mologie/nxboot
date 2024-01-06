import SwiftUI
import Combine

struct PayloadActionImage: View {
    var imageName: String
    var hoveringRow: Bool
    var hoveringButton: Bool

    var body: some View {
        Image(systemName: imageName)
            .renderingMode(.template)
            .foregroundColor(hoveringButton ? .nxBootBlue : .primary)
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
        HStack() {
            Button(action: {
                selectPayload = payload
            }) {
                Image(systemName: "arrow.forward")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.nxBootBlue)
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

struct ContentView: View {
    @Binding public var payloads: [Payload]
    @Binding public var selectPayload: Payload?
    @Binding public var autoBoot: Bool
    public var onSelectPayload: () -> Void
    public var onImportPayload: (URL) throws -> Payload
    public var onRenamePayload: (Payload, String) throws -> Void
    public var onDeletePayload: (Payload) throws -> Void

    @State private var renamePayload: Payload?
    @State private var renameTo: String = ""
    @FocusState private var renameFocused

    @State private var showError = false
    @State private var lastError: PayloadError?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($payloads, id: \.self) { payload in
                    PayloadView(
                        payload: payload,
                        selectPayload: $selectPayload,
                        renamePayload: $renamePayload,
                        deletePayload: doDelete
                    )
                }
                .onMove(perform: doMove)
                .onDelete(perform: doDelete)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .environment(\.defaultMinListRowHeight, 40)
            .onDrop(of: [.fileURL], isTargeted: nil, perform: doDrop)
            .border(.bottom)

            HStack {
                HStack {
                    Circle()
                        .foregroundColor(.red)
                        .frame(width: 16, height: 16)
                    VStack(alignment: .leading) {
                        Text("Waiting for device...")
                        Text("Connect your Nintendo Switch in RCM mode")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Boot Payload", action: doBoot)
                    .disabled(selectPayload == nil)
            }
            .padding()
            .background(TranslucentBackgroundView())
        }
        .navigationTitle("NXBoot")
        .navigationSubtitle(selectPayload != nil ? "using \(selectPayload!.name)" : "no payload selected")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: onSelectPayload) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            ToolbarItemGroup(placement: .automatic, content: {
                Picker(selection: $autoBoot, content: {
                    Text("auto-boot").tag(true)
                    Text("manual").tag(false)
                }, label: {})
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
                    .onSubmit(doRename)
                HStack {
                    Button(action: { renamePayload = nil }, label: {
                        Text("Cancel")
                            .frame(height: 26)
                            .frame(maxWidth: .infinity)
                    })
                    Button(action: doRename, label: {
                        Text("Rename")
                            .frame(height: 26)
                            .frame(maxWidth: .infinity)
                    }).buttonStyle(.borderedProminent)
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
                    DispatchQueue.main.async {
                        do {
                            try doImport(url)
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

    private func doBoot() {
        // TODO: boot
    }

    private func doImport(_ url: URL) throws {
        let payload = try onImportPayload(url)
        if !autoBoot {
            selectPayload = payload
        }
    }

    private func doMove(from source: IndexSet, to destination: Int) {
        payloads.move(fromOffsets: source, toOffset: destination)
        // didSet property observer in view model stores new explicit order
    }

    private func doRename() {
        guard let payload = renamePayload else { return }
        do {
            try onRenamePayload(payload, renameTo)
            renamePayload = nil
        } catch {
            lastError = PayloadError.renameFailed(error)
            showError = true
        }
    }

    private func doDelete(_ payload: Payload) {
        doDelete(at: IndexSet(integer: payloads.firstIndex(of: payload)!))
    }

    private func doDelete(at offsets: IndexSet) {
        let payloads = payloads
        for index in offsets {
            do {
                try onDeletePayload(payloads[index])
            } catch {
                lastError = PayloadError.deleteFailed(error)
                showError = true
                break
            }
        }
    }
}

struct ContentViewPreview: View {
    @State var payloads: [Payload] = [
        Payload(URL(fileURLWithPath: "/tmp/foo.bin")),
        Payload(URL(fileURLWithPath: "/tmp/bar.bin")),
        Payload(URL(fileURLWithPath: "/tmp/baz.bin")),
    ]
    @State var selectPayload: Payload? = nil
    @State var autoBoot: Bool = false

    var body: some View {
        ContentView(
            payloads: $payloads,
            selectPayload: $selectPayload,
            autoBoot: $autoBoot,
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
            })
    }
}

#Preview {
    ContentViewPreview()
}
