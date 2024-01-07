import Combine
import NXBootKit
import SwiftUI

@MainActor
struct NXBootView<TPayloadService: PayloadService>: View {
    @Environment(\.undoManager) var undoManager
    @Bindable var payloadService: TPayloadService
    @Binding var connection: DeviceWatcher.Connection
    @Binding var lastBoot: LastBootState
    @Binding var autoBoot: Bool
    var onBootPayload: @MainActor (Payload, NXUSBDevice) async -> Void
    var onSelectPayload: @MainActor () async -> Payload?

    @State private var renamePayload: Payload?
    @State private var renameTo: String = ""
    @FocusState private var renameFocused

    enum ActionError: LocalizedError {
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
    @State private var showError = false
    @State private var lastError: ActionError?

    var navigationText: String {
        guard let payload = payloadService.bootPayload else { return "no payload selected "}
        return "using \(payload.name)"
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($payloadService.payloads, id: \.self) { payload in
                    PayloadView(
                        payload: payload,
                        selectPayload: $payloadService.bootPayload,
                        renamePayload: $renamePayload,
                        deletePayload: deletePayload
                    )
                }
                .onMove(perform: { movePayload(from: $0, to: $1) })
                .onDelete(perform: { deletePayload(at: $0) })
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .environment(\.defaultMinListRowHeight, 40)
            .onDrop(of: [.fileURL], isTargeted: nil, perform: { doDrop(providers: $0) })
            .border(.bottom)

            DeviceView(
                connection: connection,
                lastBoot: lastBoot,
                autoBoot: autoBoot,
                onBootPayload: onBootPayload
            )
            .padding()
            .background(TranslucentBackgroundView())
        }
        .navigationTitle("NXBoot")
        .navigationSubtitle(navigationText)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    Task { @MainActor in
                        if let payload = await onSelectPayload(), !autoBoot {
                            payloadService.bootPayload = payload
                        }
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
                            lastError = ActionError.importFailed(error)
                            showError = true
                        }
                    }
                }
            }
        }
        return true
    }

    private func importPayload(_ url: URL) async throws {
        let payload = try await payloadService.importPayload(url, at: nil)
        if !autoBoot {
            payloadService.bootPayload = payload
        }
    }

    private func movePayload(from source: IndexSet, to destination: Int) {
        payloadService.payloads.move(fromOffsets: source, toOffset: destination)
        // didSet property observer in view model stores new explicit order
    }

    private func renamePayloadCommit() {
        guard let payload = renamePayload else { return }
        do {
            try payloadService.renamePayload(payload, name: renameTo)
            renamePayload = nil
        } catch {
            lastError = ActionError.renameFailed(error)
            showError = true
        }
    }

    private func deletePayload(_ payload: Payload) {
        deletePayload(at: IndexSet(integer: payloadService.payloads.firstIndex(of: payload)!))
    }

    private func deletePayload(at offsets: IndexSet) {
        let payloads = payloadService.payloads
        for index in offsets {
            do {
                let trashURL = try payloadService.deletePayload(payloads[index])
                guard let undoFromURL = trashURL else { return }
                undoManager?.registerUndo(withTarget: payloadService, handler: { service in
                    Task { @MainActor in
                        _ = try await service.importPayload(undoFromURL, at: index)
                    }
                })
                // TODO: track all other index-affecting ops, otherwise undo might crash
            } catch {
                lastError = ActionError.deleteFailed(error)
                showError = true
                break
            }
        }
    }
}

@MainActor
struct NXBootView_Preview: View {
    @State private var payloadService = PayloadServiceDummy()
    @State private var autoBoot: Bool = false

    var body: some View {
        NXBootView(
            payloadService: payloadService,
            connection: .constant(.idle),
            lastBoot: .constant(.notAttempted),
            autoBoot: $autoBoot,
            onBootPayload: { payload, device in },
            onSelectPayload: {
                let unixTime = NSDate().timeIntervalSince1970
                let url = URL(fileURLWithPath: "/tmp/payload\(unixTime).bin")
                return try? await payloadService.importPayload(url, at: nil)
            })
    }
}

#Preview {
    NXBootView_Preview()
}
