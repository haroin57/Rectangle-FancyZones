# FancyZones-style custom drag zones

This fork adds a PowerToys-FancyZones-style feature to Rectangle: define your
own zones, hold a modifier while dragging a window, see **all** zones float up
at once, and drop the window into the highlighted one.

It runs alongside Rectangle's existing edge/corner snapping — the zone overlay
only appears while the zone modifier is held during a drag.

## How it works

- New files, all under `Rectangle/Snapping/`:
  - `ZoneLayout.swift` — resolves the zone rectangles for a screen (a uniform
    grid, or a fully custom layout) and hit-tests the cursor against them.
  - `ZoneOverlayWindow.swift` — the translucent overlay that draws every zone
    and highlights the active one. It sets `ignoresMouseEvents`, so it never
    intercepts the drag.
- `SnappingManager.swift` — while a window is being dragged, if the feature is
  enabled and the zone modifier is held, it shows the overlay, tracks the zone
  under the cursor, and on mouse-up moves the window into that zone
  (`AccessibilityElement.setFrame(rect.screenFlipped)`). The normal edge-snap
  path is bypassed while zone mode is active.

## Enabling & configuring

All settings live in the app's own defaults domain (`com.knollsoft.Rectangle`):

```bash
# Turn the feature on
defaults write com.knollsoft.Rectangle fancyZonesEnabled -bool true

# Modifier to hold while dragging (raw NSEvent.ModifierFlags value).
# Default 262144 = Control. Examples: Option=524288, Command=1048576, Shift=131072.
defaults write com.knollsoft.Rectangle fancyZonesModifiers -int 262144

# Uniform grid (default 2 rows x 3 cols = sixths — good for a 34" ultrawide)
defaults write com.knollsoft.Rectangle fancyZonesRows -int 2
defaults write com.knollsoft.Rectangle fancyZonesCols -int 3
```

Restart Rectangle after changing defaults (it reads them live on each drag, but
a restart guarantees a clean state).

### Fully custom zones

For arbitrary (non-grid) zones, set `fancyZonesCustomLayout` to a JSON array of
`[x, y, w, h]` fractions with a **top-left origin**, each value in `0…1`. This
overrides the row/col grid. Example — a wide center column flanked by two
narrow side columns, with the sides split top/bottom:

```bash
defaults write com.knollsoft.Rectangle fancyZonesCustomLayout '[
  [0.0, 0.0, 0.25, 0.5],
  [0.0, 0.5, 0.25, 0.5],
  [0.25, 0.0, 0.5, 1.0],
  [0.75, 0.0, 0.25, 0.5],
  [0.75, 0.5, 0.25, 0.5]
]'
```

## Building

Requires **full Xcode** (Command Line Tools cannot compile the storyboards /
asset catalog). Then:

```bash
./build_and_install.sh
```

which builds a local unsigned Release and installs it to `/Applications`.

## Notes / limitations

- The new files are wired into `Rectangle.xcodeproj` (Rectangle target).
- There is no preferences-pane UI yet; configuration is via `defaults` (above).
- An unsigned local build must be re-granted Accessibility permission
  (System Settings → Privacy & Security → Accessibility).
