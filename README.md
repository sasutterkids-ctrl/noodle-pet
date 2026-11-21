# Noodle

Noodle is a native macOS desktop-pet prototype. The current build includes:

- An always-on-top cat avatar that roams around the visible desktop.
- Click-and-drag movement for the cat.
- Wave, Zoomies, and Nap tricks.
- Draggable treats, a fetchable ball, and a tossable yarn toy.
- A fetch behavior where Noodle runs to toys tossed across the desktop.
- A teach-a-trick prompt for custom named tricks.
- Pet-photo import, displayed as Noodle's clipped avatar look.
- A local “Style as Noodle” pass that crops, warms, sharpens, and color-grades the imported photo for a cartoon-like avatar finish.
- An optional Accessibility-powered action that nudges the focused window toward Noodle.
- An optional Accessibility-powered “Tidy windows” action that tiles open app windows without closing them.

## Run it

From this folder:

```sh
swift run
```

The first time you use **Nudge front window** or **Tidy windows**, macOS will ask for Accessibility permission. Those features are optional; Noodle's animation, toys, and photo import do not need it.

This is intentionally a first native prototype. The local styling pass is designed to work without an API key or uploaded images. The next layer can replace it with a full AI-generated photo-to-avatar conversion, add persistence, richer animation states, and ship a signed distribution bundle.
