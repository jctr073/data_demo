import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.title = "Data Demo"
            window.setContentSize(NSSize(width: 1120, height: 740))
            window.minSize = NSSize(width: 980, height: 680)
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}
