import SwiftUI

@main
struct Main: App {
    @Environment(\.openWindow) var openWindow
    @State var payloads: [Payload] = []
    @State var selectPayload: Payload?
    @State var autoBoot = false

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
                Button("About NXBoot") {
                    openWindow(id: "about")
                }
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
                Link("NXBoot Homepage", destination: URL(string: "https://mologie.github.io/nxboot/")!)
                Divider()
                Link("Source Code", destination: URL(string: "https://github.com/mologie/nxboot/")!)
                Link("Issue Tracker and Known Issues", destination: URL(string: "https://github.com/mologie/nxboot/issues")!)
            }
        }

        Window("About NXBoot", id: "about") {
            AboutView().fixedSize()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
    }
}
