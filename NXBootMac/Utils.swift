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

extension View {
    func border(_ alignment: Alignment) -> some View {
        return self.border(alignment, color: Color.black.opacity(0.15))
    }

    func border(_ alignment: Alignment, color: Color) -> some View {
        return self.overlay(Rectangle().frame(width: nil, height: 1, alignment: alignment).foregroundColor(color), alignment: alignment)
    }
}

struct WindowAccessor: NSViewRepresentable {
    // This is horrible, but necessary for attaching Cocoa stuff to the right window.
    // Used by selectPayload in Main.swift.
    // Via https://stackoverflow.com/a/63439982

    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
