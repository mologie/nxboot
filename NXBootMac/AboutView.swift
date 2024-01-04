import SwiftUI

struct TranslucentBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.material = .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct AboutView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("Hello, World!")
                Spacer()
            }
            Spacer()
        }
        .frame(minWidth: 300, minHeight: 300)
        .background(TranslucentBackgroundView().ignoresSafeArea())
    }
}

#Preview {
    AboutView().fixedSize()
}
