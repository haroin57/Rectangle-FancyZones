/// ZoneOverlayWindow.swift
///
/// The translucent overlay shown while dragging in FancyZones mode: every zone
/// of the current screen floats up at once, and the zone under the cursor is
/// highlighted. Dropping the window snaps it into that zone (handled by
/// ``SnappingManager``).
///
/// The window covers the screen's visible frame and never intercepts the
/// drag — `ignoresMouseEvents` is on, so the mouse events keep flowing to
/// ``SnappingManager``'s event monitor.

import Cocoa

class ZoneOverlayWindow: NSWindow {

    private let overlayView = ZoneOverlayView()

    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .modalPanel
        hasShadow = false
        ignoresMouseEvents = true            // never steal the drag
        isReleasedWhenClosed = false
        collectionBehavior.insert(.transient)
        collectionBehavior.insert(.canJoinAllSpaces)
        contentView = overlayView
    }

    /// Show `zones` over `screen`, highlighting `activeIndex`. Zone rects are in
    /// AppKit screen coordinates; they're converted to window-local space here.
    func show(zones: [Zone], activeIndex: Int?, on screen: NSScreen) {
        let vf = screen.adjustedVisibleFrame()
        setFrame(vf, display: false)
        let local: [(CGRect, Bool)] = zones.enumerated().map { idx, z in
            let r = z.rect.offsetBy(dx: -vf.minX, dy: -vf.minY)
            return (r, idx == activeIndex)
        }
        overlayView.zones = local
        overlayView.needsDisplay = true
        if !isVisible {
            orderFront(nil)
        }
    }

    func hide() {
        orderOut(nil)
        overlayView.zones = []
    }
}

private class ZoneOverlayView: NSView {

    /// (rect in view-local coords, isActive)
    var zones: [(CGRect, Bool)] = []

    override var isFlipped: Bool { false }   // AppKit bottom-left, matches zones

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        let inset: CGFloat = 6
        let radius: CGFloat = 12

        let accent = NSColor.controlAccentColor
        let idleFill = NSColor.white.withAlphaComponent(0.10)
        let idleStroke = NSColor.white.withAlphaComponent(0.35)
        let activeFill = accent.withAlphaComponent(0.28)
        let activeStroke = accent.withAlphaComponent(0.95)

        for (rect, active) in zones {
            let r = rect.insetBy(dx: inset, dy: inset)
            guard r.width > 0, r.height > 0 else { continue }
            let path = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
            (active ? activeFill : idleFill).setFill()
            path.fill()
            path.lineWidth = active ? 3 : 1.5
            (active ? activeStroke : idleStroke).setStroke()
            path.stroke()
        }
    }
}
