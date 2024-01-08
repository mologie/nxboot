import SwiftUI

struct SettingsView: View {
    @Binding var cloudSync: Bool
    @Binding var cloudIdentityToken: UbiquityToken?
    @Binding var autoBoot: Bool
    @Binding var allowCrashReports: Bool
    @Binding var allowUsagePings: Bool

    var body: some View {
        Form {
            Toggle(isOn: $cloudSync) {
                Text("Use iCloud")
                Text(cloudIdentityToken == nil ? "Synchronization requires that iCloud Drive is enabled." : "Payloads are moved to iCloud when the option is enabled. You will be asked what to keep when disabling it again.")
            }.disabled(cloudIdentityToken == nil)

            Divider()

            Toggle(isOn: $autoBoot) {
                Text("Boot automatically")
                Text("The selected payload is booted when a device is connected.")
            }

            Divider()

            Toggle(isOn: .constant(false)) {
                Text("Automatically check for updates")
                Text("Update checks run at most once per week.")
            }

            Toggle(isOn: $allowCrashReports) {
                Text("Allow crash reports")
                Text("Anonymously send back crash information and minimal system data on unexpected errors. I use sentry.io for this purpose.")
            }

            Toggle(isOn: $allowUsagePings) {
                Text("Allow usage pings")
                Text("This counts how many devices have already been booted with NXBoot, which gives me a fuzzy feeling.")
            }

            Link("Sentry Privacy Policy", destination: URL(string: "https://sentry.io/privacy/")!)
                .font(.footnote)
                .padding(.leading, 18)
        }
        .navigationTitle("NXBoot Settings")
        .padding(20)
        .frame(width: 450)
    }
}

#Preview {
    SettingsView(
        cloudSync: .constant(false),
        cloudIdentityToken: .constant(UbiquityToken(wrapped: "dummy" as NSString)),
        autoBoot: .constant(false),
        allowCrashReports: .constant(true),
        allowUsagePings: .constant(true)
    )
}
