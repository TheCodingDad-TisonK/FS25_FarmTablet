# Edit Mode — Reposition and Resize the Tablet

Edit Mode lets you drag the tablet anywhere on screen, scale it up or down, or adjust its width independently — all with the mouse, visually, without touching any config files.

---

## Entering Edit Mode

Three ways:

1. **Right-click** the tablet while it is open
2. Open the **Settings app** → click **ENTER EDIT MODE**
3. While in Edit Mode the Settings button changes to **EXIT EDIT MODE** — click it to save and exit

---

## What You Can Do

```
 ╔══════════════════════════════════════════════════════╗  ← corner handles (scale)
 ║                                                      ║
 ║   Drag anywhere on the body to move the tablet       ║
 ║                                                      ║
 ╚══════════════════════════════════════════════════════╝
 ↕                                                      ↕
 edge handles (width)                        edge handles (width)
```

### Moving (drag the body)
Click and hold anywhere on the tablet body and drag. The tablet follows your mouse. It is clamped to screen edges so it cannot be dragged completely off-screen.

### Scaling (drag a corner handle)
Four small square handles appear at the corners of the tablet. Click and drag any corner to scale the whole tablet up or down uniformly (50–200% of the base size).

The scale handle colour changes:
- **Blue** — idle, ready to drag
- **Bright blue** — hovered
- **Green** — actively being dragged

### Width only (drag an edge handle)
Two handle strips appear on the left and right edges of the tablet. Dragging either edge stretches or narrows the tablet width independently of the overall scale (50–200%).

This is useful on ultra-wide monitors where you want a wider panel without making everything taller.

---

## Visual Feedback

While Edit Mode is active:

- A **pulsing coloured border** appears around the entire tablet
- **Blue border** = idle / dragging body
- **Green border** = actively resizing (corner or edge drag)
- A help label appears at the bottom of the screen:
  ```
  TABLET EDIT MODE  |  Drag: move  |  Corners: scale  |  Edges: width  |  Right-click: exit
  ```

---

## Exiting Edit Mode

- **Right-click** anywhere to save and exit immediately
- **Click EXIT EDIT MODE** in the Settings app
- Position and scale are saved automatically on exit — no separate Save button needed

---

## Auto-Exit

Edit Mode exits automatically if:
- A game dialog or GUI overlay opens (e.g. shop, vehicle purchase screen)
- This prevents getting stuck in Edit Mode during normal gameplay

---

## Saving & Persistence

On exit, the current position (`tabletPosX`, `tabletPosY`), scale (`tabletScale`), and width multiplier (`tabletWidthMult`) are written to `FS25_FarmTablet.xml` in your savegame directory.

They are restored exactly on next load.

---

## Resetting

To undo your changes and return to the default centred position at 100% scale:

**Settings app → RESET POSITION & SCALE**

Or via console:
```
TabletResetSettings
```

Note: `TabletResetSettings` resets **all** settings, not just position/scale. Use the in-app button if you only want to reset layout.

---

## Tips

- If the tablet ends up partially off-screen: open the tablet (it still opens even if mostly hidden), navigate to Settings, click RESET POSITION & SCALE.
- On 4K or ultra-wide displays, try `tabletScale = 1.3` and `tabletWidthMult = 1.2` for a comfortable reading size.
- Scale and position settings are per-savegame — you can have different sizes on different saves.
