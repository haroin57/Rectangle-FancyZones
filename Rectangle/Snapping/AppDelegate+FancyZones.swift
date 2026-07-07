/// AppDelegate+FancyZones.swift
///
/// Status-bar-menu UI for the FancyZones custom-drag-zone feature. The items
/// are injected into `mainStatusMenu` programmatically (the menu itself comes
/// from Main.storyboard), so no storyboard editing is required. Injection is
/// idempotent and runs from `menuWillOpen`, so it survives menu rebuilds.

import Cocoa

private let fzToggleTag = 990001
private let fzGridHeaderTag = 990002
private let fzGridItemTag = 990003
private let fzGridBaseTag = 990100

private let fzGrids: [(rows: Int, cols: Int)] = [(2, 2), (2, 3), (3, 3), (3, 4)]

extension AppDelegate {

    /// Insert the FancyZones items into the status menu once (idempotent).
    func ensureFancyZonesMenu() {
        guard let menu = mainStatusMenu else { return }
        if menu.item(withTag: fzToggleTag) != nil { return }  // already present

        let toggle = NSMenuItem(title: NSLocalizedString("Zone Dragging (hold ⇧ and drag)", comment: ""),
                                action: #selector(toggleFancyZones(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.tag = fzToggleTag

        let gridItem = NSMenuItem(title: NSLocalizedString("Zone Grid", comment: ""), action: nil, keyEquivalent: "")
        gridItem.tag = fzGridItemTag
        let gridMenu = NSMenu()
        let header = NSMenuItem(title: NSLocalizedString("rows × columns", comment: ""), action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.tag = fzGridHeaderTag
        gridMenu.addItem(header)
        for (i, g) in fzGrids.enumerated() {
            let it = NSMenuItem(title: "\(g.rows) × \(g.cols)  (\(g.rows * g.cols) zones)",
                                action: #selector(setFancyZonesGrid(_:)), keyEquivalent: "")
            it.target = self
            it.tag = fzGridBaseTag + i
            it.representedObject = [g.rows, g.cols]
            gridMenu.addItem(it)
        }
        gridItem.submenu = gridMenu

        // Insert just above the Quit item when we can find it, else append.
        let insertAt: Int
        if let quit = quitMenuItem, menu.index(of: quit) >= 0 {
            insertAt = menu.index(of: quit)
        } else {
            insertAt = menu.numberOfItems
        }
        menu.insertItem(NSMenuItem.separator(), at: insertAt)
        menu.insertItem(toggle, at: insertAt + 1)
        menu.insertItem(gridItem, at: insertAt + 2)
    }

    /// Reflect the current defaults in the injected items' checkmarks.
    func refreshFancyZonesMenuState() {
        guard let menu = mainStatusMenu else { return }
        let enabled = UserDefaults.standard.bool(forKey: "fancyZonesEnabled")
        menu.item(withTag: fzToggleTag)?.state = enabled ? .on : .off

        let rows = UserDefaults.standard.integer(forKey: "fancyZonesRows")
        let cols = UserDefaults.standard.integer(forKey: "fancyZonesCols")
        let r = rows > 0 ? rows : 2
        let c = cols > 0 ? cols : 3
        let gridSubmenu = menu.item(withTag: fzGridItemTag)?.submenu
        for (i, g) in fzGrids.enumerated() {
            gridSubmenu?.item(withTag: fzGridBaseTag + i)?.state = (g.rows == r && g.cols == c) ? .on : .off
        }
    }

    @objc func toggleFancyZones(_ sender: NSMenuItem) {
        let now = UserDefaults.standard.bool(forKey: "fancyZonesEnabled")
        UserDefaults.standard.set(!now, forKey: "fancyZonesEnabled")
        refreshFancyZonesMenuState()
    }

    @objc func setFancyZonesGrid(_ sender: NSMenuItem) {
        guard let rc = sender.representedObject as? [Int], rc.count == 2 else { return }
        UserDefaults.standard.set(rc[0], forKey: "fancyZonesRows")
        UserDefaults.standard.set(rc[1], forKey: "fancyZonesCols")
        UserDefaults.standard.set(true, forKey: "fancyZonesEnabled")   // selecting a grid enables it
        refreshFancyZonesMenuState()
    }
}
