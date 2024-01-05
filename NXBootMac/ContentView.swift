import SwiftUI
import Combine

extension View {
    func border(_ alignment: Alignment) -> some View {
        return self.border(alignment, color: Color.black.opacity(0.15))
    }

    func border(_ alignment: Alignment, color: Color) -> some View {
        return self.overlay(Rectangle().frame(width: nil, height: 1, alignment: alignment).foregroundColor(color), alignment: alignment)
    }
}

struct Payload: Hashable, Identifiable, Equatable {
    var id: String { path }
    var path: String
    var name: String {
        get {
            let fileName = (path as NSString).lastPathComponent
            return (fileName as NSString).deletingPathExtension
        }
        set {
            let dir = (path as NSString).deletingLastPathComponent
            let ext = (path as NSString).pathExtension
            path = "\(dir)/\(newValue.replacing(/[\/:]/, with: " ")).\(ext)"
        }
    }
}

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

struct PayloadView: View {
    @Binding var payload: Payload
    @Binding var selectPayload: Payload?
    @Binding var renamePayload: Payload?
    var deletePayload: (Payload) -> Void

    @State private var hoveringRow = false
    @State private var hoveringDragHandle: Bool = false

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
                    Text("Detail text goes here")
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

    @State private var renamePayload: Payload?
    @State private var renameTo: String = ""
    @FocusState private var renameFocused

    var body: some View {
        VStack(spacing: 0) {
            List($payloads, id: \.self, editActions: [.move, .delete]) { payload in
                PayloadView(
                    payload: payload,
                    selectPayload: $selectPayload,
                    renamePayload: $renamePayload,
                    deletePayload: { payload in
                        payloads.removeAll { payloadToRemove in
                            return payloadToRemove == payload
                        }
                    }
                )
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .environment(\.defaultMinListRowHeight, 40)
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
                SettingsLink {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    let unixTime = NSDate().timeIntervalSince1970
                    payloads.append(Payload(path: "payload\(unixTime).bin"))
                }) {
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
    }

    private func doBoot() {
        // TODO: boot
    }

    private func doRename() {
        let selected = (selectPayload == renamePayload)
        if let index = payloads.firstIndex(where: { $0 == renamePayload }) {
            payloads[index].name = renameTo
            if selected {
                selectPayload = payloads[index]
            }
        }
        renamePayload = nil
    }
}

struct ContentViewPreview: View {
    @State var payloads: [Payload] = [
        Payload(path: "foo.bin"),
        Payload(path: "bar.bin"),
        Payload(path: "baz.bin"),
    ]
    @State var selectPayload: Payload? = Payload(path: "baz.bin")
    @State var autoBoot: Bool = false

    var body: some View {
        ContentView(
            payloads: $payloads,
            selectPayload: $selectPayload,
            autoBoot: $autoBoot
        )
    }
}

#Preview {
    ContentViewPreview()
}
