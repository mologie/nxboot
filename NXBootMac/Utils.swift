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
