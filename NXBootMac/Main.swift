import SwiftUI

@main
struct Main: App {
    @ObservedObject private var payloadViewModel: PayloadViewModel
    @State private var autoBoot = false
    @State private var mainWindow: NSWindow?
    private var aboutWindowController = AboutWindowController.controller()

    var body: some Scene {
        Window("NXBoot", id: "main") {
            ContentView(
                payloads: $payloadViewModel.payloads,
                selectPayload: $payloadViewModel.bootPayload,
                autoBoot: $autoBoot,
                onSelectPayload: selectPayload,
                onImportPayload: payloadViewModel.importPayload,
                onRenamePayload: payloadViewModel.renamePayload,
                onDeletePayload: payloadViewModel.deletePayload)
            .background(WindowAccessor(window: $mainWindow))
            .frame(minWidth: 540, minHeight: 240)
            .frame(idealWidth: 640, idealHeight: 322)
        }
        .windowResizability(.contentSize)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About NXBoot") { aboutWindowController.showWindowCentered() }
            }
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                Button("Add Payload File...", action: selectPayload)
                    .keyboardShortcut("o", modifiers: [.command])
                Toggle("Auto-boot Selected Payload", isOn: $autoBoot)
                Divider()
                Button("Open Payload Folder") {
                    NSWorkspace.shared.open(payloadViewModel.payloadsFolder)
                }
                Button("Reload Payload List") { payloadViewModel.refreshPayloads() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            CommandGroup(replacing: CommandGroupPlacement.help) {
                Link("NXBoot Homepage", destination: Links.homepage)
                Divider()
                Link("Source Code", destination: Links.repo)
                Link("Issue Tracker and Known Issues", destination: Links.issues)
            }
        }
    }

    init() {
        let payloadsFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NXBoot")
            .appendingPathComponent("Payloads")
        do {
            payloadViewModel = try PayloadViewModel(payloadsFolder: payloadsFolder)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Initialization Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            exit(1)
        }
    }

    func selectPayload() {
        // Meh, no SwiftUI variant exists for this one. Worse yet, it needs a hack to retrieve the
        // SwiftUI window's NSWindow, so that the open and error dialogs can be attached properly.
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.data]
        let completionHandler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = openPanel.urls.first {
                DispatchQueue.main.async {
                    do {
                        let payload = try payloadViewModel.importPayload(url)
                        if !autoBoot {
                            payloadViewModel.bootPayload = payload
                        }
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Error Importing Payload"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        if let mainWindow {
                            alert.beginSheetModal(for: mainWindow)
                        } else {
                            alert.runModal()
                        }
                    }
                }
            }
        }
        if let mainWindow {
            openPanel.beginSheetModal(for: mainWindow, completionHandler: completionHandler)
        } else {
            openPanel.begin(completionHandler: completionHandler)
        }
    }
}
