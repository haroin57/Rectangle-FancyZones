/// AppDelegate+FancyZones.swift
///
/// Status-bar-menu UI for the FancyZones custom-drag-zone feature. The items
/// are injected into `mainStatusMenu` programmatically (the menu itself comes
/// from Main.storyboard), so no storyboard editing is required. Injection is
/// idempotent and runs from `menuWillOpen`, so it survives menu rebuilds and
/// reflects the currently-connected monitors.

import Cocoa

private let fzToggleTag = 990001
private let fzGridItemTag = 990003

private let fzGrids: [(rows: Int, cols: Int)] = [(2, 2), (2, 3), (3, 3), (3, 4), (1, 2), (1, 3)]

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
        gridItem.submenu = NSMenu()

        let insertAt: Int
        if let quit = quitMenuItem, menu.index(of: quit) >= 0 {
            insertAt = menu.index(of: quit)
        } else {
            insertAt = menu.numberOfItems
        }
        menu.insertItem(NSMenuItem.separator(), at: insertAt)
        menu.insertItem(toggle, at: insertAt + 1)
        menu.insertItem(gridItem, at: insertAt + 2)
        rebuildGridSubmenu()
    }

    /// Reflect the current defaults in the injected items, and rebuild the grid
    /// submenu so it tracks the currently-connected monitors + selection.
    func refreshFancyZonesMenuState() {
        guard let menu = mainStatusMenu else { return }
        let enabled = UserDefaults.standard.bool(forKey: "fancyZonesEnabled")
        menu.item(withTag: fzToggleTag)?.state = enabled ? .on : .off
        rebuildGridSubmenu()
    }

    /// Repopulate the "Zone Grid" submenu: a global default section plus one
    /// section per connected monitor.
    func rebuildGridSubmenu() {
        guard let sub = mainStatusMenu?.item(withTag: fzGridItemTag)?.submenu else { return }
        sub.removeAllItems()

        let (gr, gc) = globalGrid()

        let defHeader = NSMenuItem(title: NSLocalizedString("Default (all monitors)", comment: ""), action: nil, keyEquivalent: "")
        defHeader.isEnabled = false
        sub.addItem(defHeader)
        for g in fzGrids {
            sub.addItem(gridOption(rows: g.rows, cols: g.cols, screenKey: nil,
                                   checked: g.rows == gr && g.cols == gc))
        }

        for screen in NSScreen.screens {
            sub.addItem(NSMenuItem.separator())
            let key = ZoneLayout.screenKey(screen)
            let mh = NSMenuItem(title: screen.localizedName, action: nil, keyEquivalent: "")
            mh.isEnabled = false
            sub.addItem(mh)
            let override = perMonitorGrid(key)
            for g in fzGrids {
                sub.addItem(gridOption(rows: g.rows, cols: g.cols, screenKey: key,
                                       checked: override != nil && override! == (g.rows, g.cols)))
            }
            let useDefault = NSMenuItem(title: NSLocalizedString("Use default", comment: ""),
                                        action: #selector(clearFancyZonesGrid(_:)), keyEquivalent: "")
            useDefault.target = self
            useDefault.representedObject = key
            useDefault.state = (override == nil) ? .on : .off
            sub.addItem(useDefault)
        }
    }

    private func gridOption(rows r: Int, cols c: Int, screenKey key: String?, checked: Bool) -> NSMenuItem {
        let it = NSMenuItem(title: "\(r) × \(c)  (\(r * c) zones)",
                            action: #selector(setFancyZonesGrid(_:)), keyEquivalent: "")
        it.target = self
        it.representedObject = ["r": r, "c": c, "key": key ?? ""]
        it.state = checked ? .on : .off
        return it
    }

    private func globalGrid() -> (Int, Int) {
        let r = UserDefaults.standard.integer(forKey: "fancyZonesRows")
        let c = UserDefaults.standard.integer(forKey: "fancyZonesCols")
        return (r > 0 ? r : 2, c > 0 ? c : 3)
    }

    private func perMonitorGrid(_ key: String) -> (Int, Int)? {
        let r = UserDefaults.standard.integer(forKey: "fancyZonesRows_" + key)
        let c = UserDefaults.standard.integer(forKey: "fancyZonesCols_" + key)
        return (r > 0 && c > 0) ? (r, c) : nil
    }

    @objc func toggleFancyZones(_ sender: NSMenuItem) {
        let now = UserDefaults.standard.bool(forKey: "fancyZonesEnabled")
        UserDefaults.standard.set(!now, forKey: "fancyZonesEnabled")
        refreshFancyZonesMenuState()
    }

    @objc func setFancyZonesGrid(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let r = info["r"] as? Int, let c = info["c"] as? Int else { return }
        let key = (info["key"] as? String) ?? ""
        let suffix = key.isEmpty ? "" : "_" + key
        UserDefaults.standard.set(r, forKey: "fancyZonesRows" + suffix)
        UserDefaults.standard.set(c, forKey: "fancyZonesCols" + suffix)
        UserDefaults.standard.set(true, forKey: "fancyZonesEnabled")  // selecting a grid enables it
        refreshFancyZonesMenuState()
    }

    @objc func clearFancyZonesGrid(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        UserDefaults.standard.removeObject(forKey: "fancyZonesRows_" + key)
        UserDefaults.standard.removeObject(forKey: "fancyZonesCols_" + key)
        refreshFancyZonesMenuState()
    }
}
