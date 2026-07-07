/// ZoneLayout.swift
///
/// FancyZones-style custom drag zones for Rectangle.
///
/// A ``ZoneLayout`` is a set of zones defined as fractional rectangles over a
/// screen's visible frame. Two ways to define them:
///
///  * a uniform grid — `fancyZonesRows` × `fancyZonesCols` (default 2×3, i.e.
///    sixths), or
///  * a fully custom layout — `fancyZonesCustomLayout`, a JSON array of
///    `[x, y, w, h]` fractions with a TOP-LEFT origin (x→right, y→down),
///    each value in 0...1. Zones may overlap or leave gaps; anything goes.
///
/// Both are read from `UserDefaults.standard` (the app's own domain) so they
/// can be set from the preferences UI or via `defaults write com.knollsoft.Rectangle`.
///
/// Fractions are resolved against a screen's *visible* frame (menu bar / Dock
/// excluded) in AppKit coordinates (bottom-left origin), which is what the
/// overlay window uses directly and what converts cleanly to the
/// Accessibility API via ``CGRect/screenFlipped`` when the window is moved.

import Cocoa

struct Zone {
    /// The target rectangle in AppKit screen coordinates (bottom-left origin).
    let rect: CGRect
}

enum ZoneLayout {

    // MARK: Configuration (UserDefaults-backed)

    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: "fancyZonesEnabled")
    }

    /// Modifier that must be held during a drag to enter zone mode. Stored as
    /// the raw value of `NSEvent.ModifierFlags` intersected with the
    /// device-independent mask (mirrors Rectangle's `snapModifiers`). Defaults
    /// to **Shift** (like PowerToys FancyZones). Control is a poor choice on
    /// macOS because Control-click is a secondary (right) click, so
    /// Control-dragging a title bar doesn't move the window and the feature
    /// never triggers.
    static var modifierFlags: UInt {
        let stored = UserDefaults.standard.object(forKey: "fancyZonesModifiers") as? Int
        return UInt(stored ?? Int(NSEvent.ModifierFlags.shift.rawValue))
    }

    private static var rows: Int {
        let r = UserDefaults.standard.integer(forKey: "fancyZonesRows")
        return r > 0 ? r : 2
    }

    private static var cols: Int {
        let c = UserDefaults.standard.integer(forKey: "fancyZonesCols")
        return c > 0 ? c : 3
    }

    /// Optional fully-custom layout: JSON array of `[x, y, w, h]` fractions,
    /// top-left origin, values 0...1. When present and valid it overrides the
    /// row/col grid.
    private static var customFractions: [CGRect]? {
        guard let raw = UserDefaults.standard.string(forKey: "fancyZonesCustomLayout"),
              let data = raw.data(using: .utf8),
              let arrays = try? JSONSerialization.jsonObject(with: data) as? [[Double]]
        else { return nil }
        let rects: [CGRect] = arrays.compactMap { a in
            guard a.count == 4 else { return nil }
            let r = CGRect(x: a[0], y: a[1], width: a[2], height: a[3])
            // Basic sanity: non-empty and within the unit square-ish.
            guard r.width > 0, r.height > 0 else { return nil }
            return r
        }
        return rects.isEmpty ? nil : rects
    }

    // MARK: Zone computation

    /// The zones for `screen`, resolved to AppKit screen coordinates.
    static func zones(for screen: NSScreen) -> [Zone] {
        let vf = screen.adjustedVisibleFrame()
        let fractions = customFractions ?? gridFractions()
        return fractions.map { Zone(rect: resolve($0, in: vf)) }
    }

    /// Index of the zone whose rect contains `location` (AppKit coords), or nil.
    /// When zones overlap, the last (top-most) match wins.
    static func zoneIndex(at location: CGPoint, for screen: NSScreen) -> Int? {
        let zs = zones(for: screen)
        var match: Int? = nil
        for (i, z) in zs.enumerated() where z.rect.contains(location) {
            match = i
        }
        return match
    }

    // MARK: Helpers

    /// Uniform grid as top-left-origin fractional rects.
    private static func gridFractions() -> [CGRect] {
        let r = rows, c = cols
        var out: [CGRect] = []
        out.reserveCapacity(r * c)
        let fw = 1.0 / Double(c)
        let fh = 1.0 / Double(r)
        for row in 0..<r {
            for col in 0..<c {
                out.append(CGRect(x: Double(col) * fw,
                                  y: Double(row) * fh,
                                  width: fw, height: fh))
            }
        }
        return out
    }

    /// Convert a top-left-origin fractional rect into an AppKit (bottom-left)
    /// rect within `vf` (the screen's visible frame).
    private static func resolve(_ f: CGRect, in vf: CGRect) -> CGRect {
        let w = f.width * vf.width
        let h = f.height * vf.height
        let x = vf.minX + f.minX * vf.width
        // f.minY measures from the TOP; convert to a bottom-left origin.
        let y = vf.maxY - (f.minY * vf.height) - h
        return CGRect(x: x, y: y, width: w, height: h).integral
    }
}
