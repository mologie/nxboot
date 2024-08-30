import SwiftUI

struct PayloadView: View {
    @Binding var payload: Payload
    @Binding var selectPayload: Payload?
    @Binding var renamePayload: Payload?
    var deletePayload: @MainActor (Payload) -> Void

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
