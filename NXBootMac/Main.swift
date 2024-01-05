import SwiftUI

@main
struct Main: App {
    @State var payloads: [Payload] = []
    @State var selectPayload: Payload?
    @State var autoBoot = false

    @State private var aboutWindowController = AboutWindowController.controller()

    var body: some Scene {
        Window("NXBoot", id: "main") {
            ContentView(
                payloads: $payloads,
                selectPayload: $selectPayload,
                autoBoot: $autoBoot)
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
                Button("Add Payload File...") {
                    // TODO
                }.keyboardShortcut("o", modifiers: [.command])
                Toggle("Auto-boot Selected Payload", isOn: $autoBoot)
                Divider()
                Button("Open Payload Folder") {
                    // TODO
                }
                Button("Reload Payload List") {
                    // TODO
                }
            }
            CommandGroup(replacing: CommandGroupPlacement.help) {
                Link("NXBoot Homepage", destination: Links.homepage)
                Divider()
                Link("Source Code", destination: Links.repo)
                Link("Issue Tracker and Known Issues", destination: Links.issues)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
