// The blur behind translucent themes.
//
// SwiftUI's own `.ultraThinMaterial` samples the *window's* backdrop, which for
// a borderless panel is nothing — so it renders as flat grey. An
// NSVisualEffectView with .behindWindow blending is the only way to get the
// desktop and the windows underneath to show through.
//
// It has to mask itself. SwiftUI's `.clipShape` puts a mask on the SwiftUI
// layer, not on the AppKit view inside it, so an unmasked effect view fills the
// whole window — and because AppKit derives a window's drop shadow from the
// opacity of its content, that produced a hard grey rectangle with jagged edges
// behind the rounded panel. `maskImage` is the AppKit-level fix: a nine-part
// rounded rectangle the effect view stretches to its own bounds.

import AppKit
import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // .popover follows the window's appearance, unlike .hudWindow which is
        // always dark — themes pin their own appearance and expect to be obeyed.
        view.material = .popover
        // Keep blurring while another app is frontmost; the prompt is meant to
        // sit over whatever the user was doing without dulling itself.
        view.state = .active
        view.maskImage = Self.roundedMask(cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.maskImage = Self.roundedMask(cornerRadius: cornerRadius)
    }

    /// A resizable rounded-rectangle mask.
    ///
    /// Cap insets make it a nine-part image: the corners keep their radius at
    /// any panel size while the edges stretch, so one small image masks every
    /// prompt.
    private static func roundedMask(cornerRadius: CGFloat) -> NSImage {
        let edge = cornerRadius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: cornerRadius, left: cornerRadius,
            bottom: cornerRadius, right: cornerRadius)
        image.resizingMode = .stretch
        return image
    }
}
