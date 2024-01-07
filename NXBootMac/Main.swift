import Combine
import NXBootKit
import SwiftUI

@main
@MainActor
struct Main: App {
    @State private var payloadModel: PayloadModel
    @AppStorage("NXBootAutomaticMode") private var autoBoot = false
    private var intermezzo: Data = { NSDataAsset(name: "Intermezzo")!.data }()

    @State private var deviceModel: DeviceModel
    @State private var lastBoot: LastBootState = .notAttempted
    private var deviceSubscription: AnyCancellable?

    @State private var mainWindow: NSWindow?
    private let aboutWindowController: AboutWindowController

    var body: some Scene {
        Window("NXBoot", id: "main") {
            ContentView(
                payloads: $payloadModel.payloads,
                selectPayload: $payloadModel.bootPayload,
                device: $deviceModel.device,
                lastBoot: $lastBoot,
                autoBoot: $autoBoot,
                onBootPayload: bootPayload,
                onSelectPayload: selectPayload,
                onImportPayload: payloadModel.importPayload,
                onRenamePayload: payloadModel.renamePayload,
                onDeletePayload: payloadModel.deletePayload
            )
            .background(WindowAccessor(window: $mainWindow))
            .frame(minWidth: 540, minHeight: 240)
            .frame(idealWidth: 640, idealHeight: 322)
            .onOpenURL(perform: { url in
                // something was dragged onto the application icon
                Task { @MainActor in await importPayload(from: url) }
            })
        }
        .windowResizability(.contentSize)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About NXBoot") { aboutWindowController.showWindowCentered() }
            }
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                Button("Add Payload File...", action: {
                    Task { @MainActor in await selectPayload() }
                }).keyboardShortcut("o", modifiers: [.command])
                Toggle("Auto-boot Selected Payload", isOn: $autoBoot)
                Divider()
                Button("Open Payload Folder") {
                    NSWorkspace.shared.open(payloadModel.payloadsFolder)
                }
                Button("Reload Payload List") { payloadModel.refreshPayloads() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            CommandGroup(replacing: CommandGroupPlacement.help) {
                Link("NXBoot Homepage", destination: Links.homepage)
                Divider()
                Link("Source Code", destination: Links.repo)
                Link("Issue Tracker and Known Issues", destination: Links.issues)
            }
        }
        .onChange(of: autoBoot) { _, autoBoot in
            // trigger auto-boot when toggle is enabled
            if !autoBoot { return }
            Task { @MainActor in
                guard let payload = payloadModel.bootPayload else { return }
                guard case let .connected(device) = deviceModel.device else { return }
                guard case .notAttempted = lastBoot else { return }
                print("App: Auto-booting existing device")
                await bootPayload(payload, on: device)
            }
        }
        .onChange(of: deviceModel.device) { oldDevice, newDevice in
            // reset boot state and trigger auto-boot when a device is connected
            Task { @MainActor in
                guard let payload = payloadModel.bootPayload else { return }
                if case .inProgress = lastBoot {
                    print("App: Device transition during boot: \(oldDevice) => \(newDevice)")
                    return
                    // the boot task will eventually fail if the device was indeed disconnected
                } else {
                    print("App: Device transition: \(oldDevice) => \(newDevice)")
                }
                if case let .connected(device) = newDevice {
                    print("App: Device connected")
                    lastBoot = .notAttempted
                    if autoBoot {
                        print("App: Auto-booting new device connected")
                        await bootPayload(payload, on: device)
                    }
                }
            }
        }
    }

    init() {
        let payloadsFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NXBoot")
            .appendingPathComponent("Payloads")
        do {
            payloadModel = try PayloadModel(payloadsFolder: payloadsFolder)
            deviceModel = DeviceModel()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Initialization Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            exit(1)
        }
        aboutWindowController = AboutWindowController.controller()
    }

    private func bootPayload(_ payload: Payload, on device: NXUSBDevice) async {
        guard case .notAttempted = lastBoot else { return }
        do {
            lastBoot = .inProgress
            print("App: Boot in progress")
            let payloadURL = payload.url
            let task = Task.detached(priority: .userInitiated) {
                print("App: Boot task running")
                let payloadData = try Data(contentsOf: payloadURL)
                try await device.boot(payloadData, intermezzo: intermezzo)
            }
            try await task.value
            lastBoot = .succeeded
            print("App: Boot succeeded")
        } catch {
            lastBoot = .failed(error)
        }
    }

    private func selectPayload() async {
        // Meh, no SwiftUI variant exists for this one. Worse yet, it needs a hack to retrieve the
        // SwiftUI window's NSWindow, so that the open and error dialogs can be attached properly.
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.data]

        let response: NSApplication.ModalResponse
        if let mainWindow {
            response = await openPanel.beginSheetModal(for: mainWindow)
        } else {
            response = await openPanel.begin()
        }

        guard response == .OK, let url = openPanel.urls.first else { return }
        await importPayload(from: url)
    }

    private func importPayload(from url: URL) async {
        do {
            let payload = try await payloadModel.importPayload(url)
            if !autoBoot {
                payloadModel.bootPayload = payload
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error Importing Payload"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            if let mainWindow {
                await alert.beginSheetModal(for: mainWindow)
            } else {
                alert.runModal()
            }
        }
    }
}
