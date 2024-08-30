import SwiftUI

struct Links {
    static let homepage = URL(string: "https://mologie.github.io/nxboot/")!
    static let repo = URL(string: "https://github.com/mologie/nxboot/")!
    static let issues = URL(string: "https://github.com/mologie/nxboot/issues")!
}

private let aboutText = """
    NXBoot starts custom boot code on compatible Tegra X1 chips, including Nintendo Switch consoles released during or before 2019.

    CVE-2018-6242 has been discovered and implemented by Kate Temkin (ktemkin.com) and fail0verflow.com.

    {re}switched's Python Fusée Launcher served as reference for implementing this application.

    This application is provided to you under the terms of the GNU General Public License v3 and comes \
    with absolutely no warranty. Improper use of custom boot code can damage your hardware or result \
    in exclusion from online services.
    """

class AboutWindowController: NSWindowController {
    // using an AppKit controller instead of SwiftUI Window here for multiple perks:
    // - doesn't show up in the Window menu dropdown
    // - can be centered when it's opened
    // - can be properly closed with ESC

    static func controller() -> AboutWindowController {
        let window = NSWindow()
        window.styleMask = [.closable, .titled, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.title = "About NXBoot"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: AboutView().fixedSize())
        return AboutWindowController(window: window)
    }

    func showWindowCentered() {
        if let window, !window.isVisible {
            window.center()
        }
        showWindow(nil)
    }

    @objc func cancel(_ sender: Any?) {
        window?.close()
    }
}

struct AboutView: View {
    var appVersion: String {
        let infoDict = Bundle.main.infoDictionary!
        return infoDict["CFBundleShortVersionString"] as! String
    }
    var fill = Color(nsColor: NSColor.textBackgroundColor)

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(nsImage: NSImage(named: NSImage.applicationIconName)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 100)
                VStack(alignment: .leading) {
                    Text("NXBoot")
                        .font(.system(size: 36))
                        .shadow(color: fill, radius: 1, x: 0, y: 1)
                    Text("Version \(appVersion)")
                        .foregroundStyle(.secondary)
                        .shadow(color: fill, radius: 1, x: 0, y: 1)
                }
            }
            Text("Oliver Kuckertz (@mologie)")
                .fontWeight(.light)
                .shadow(color: fill, radius: 1, x: 0, y: 1)
            Text(aboutText)
                .shadow(color: fill, radius: 1, x: 0, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Link(destination: Links.homepage) {
                    Text("Homepage").frame(height: 26).frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)

                Link(destination: Links.repo) {
                    Text("Source Code").frame(height: 26).frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }
        }
        .padding([.top], 5)
        .padding([.leading, .trailing, .bottom], 30)
        .background(alignment: .bottom) {
            Image(.tri)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.1)
        }
        .background(TranslucentBackgroundView().ignoresSafeArea())
        .frame(width: 360)
    }
}

#Preview {
    AboutView().fixedSize()
}
