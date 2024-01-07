import SwiftUI

struct DeviceView: View {
    var selectPayload: Payload?
    var connection: DeviceWatcher.Connection
    var lastBoot: NXBootApp.LastBootState
    var autoBoot: Bool
    var onBootPayload: @MainActor (Payload, Device) async -> Void

    private var title: String {
        switch connection {
        case .idle:
            return "Waiting for device..."
        case .error(_):
            return "USB error"
        case .device(_):
            return "Device connected in RCM mode"
        }
    }

    private var footnote: String {
        switch connection {
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
        case .device(_):
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

    private var deviceStatusColor: Color {
        switch connection {
        case .idle, .error(_):
            return .red
        case .device(_):
            switch lastBoot {
            case .notAttempted, .succeeded: return .green
            case .inProgress: return .yellow
            case .failed(_): return .red
            }
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Circle()
                    .foregroundColor(deviceStatusColor)
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading) {
                    Text(title)
                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !autoBoot {
                Button(action: {
                    guard let payload = selectPayload else { return }
                    guard case let .device(device) = connection else { return }
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
                    guard case .device(_) = connection else { return true }
                    guard case .notAttempted = lastBoot else { return true }
                    return false
                }())
            }
        }
    }
}
