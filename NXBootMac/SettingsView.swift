import SwiftUI

struct SettingsToggleStyle: ToggleStyle {
    var systemImage: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .padding([.leading, .trailing], 5)
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

struct SettingsView: View {
    @Binding var cloudSync: Bool
    @Binding var cloudIdentityToken: UbiquityToken?
    @Binding var autoBoot: Bool
    @Binding var allowCrashReports: Bool
    @Binding var allowUsagePings: Bool

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $cloudSync) {
                    Text("Use iCloud")
                    Text(cloudIdentityToken == nil ? "Synchronization requires that iCloud Drive is enabled." : "Payloads will be synchronized via iCloud Drive. You will be asked what to keep when disabling this option.")
                }
                .disabled(cloudIdentityToken == nil)
                .toggleStyle(SettingsToggleStyle(systemImage: "icloud.fill"))
            }

            Section {
                Toggle(isOn: $autoBoot) {
                    Text("Boot automatically")
                    Text("The selected payload is booted when a device is connected.")
                }
                .toggleStyle(SettingsToggleStyle(systemImage: "cable.connector"))
            }

            Section {
                Toggle(isOn: $allowCrashReports) {
                    Text("Allow crash reports")
                    Text("Anonymously send back crash information with minimal system data to Sentry. No data is sent until a crash happens. [Privacy Policy](https://sentry.io/privacy/)")
                }
                .toggleStyle(SettingsToggleStyle(systemImage: "stethoscope"))

                Toggle(isOn: $allowUsagePings) {
                    Text("Allow usage pings")
                    Text("Let NXBoot count how often it is used, and anonymously report successful or failed boot events to Sentry.")
                }
                .toggleStyle(SettingsToggleStyle(systemImage: "chart.bar.xaxis.ascending"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .navigationTitle("NXBoot Settings")
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
