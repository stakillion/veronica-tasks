# Veronica Tasks

**Veronica Tasks** is a modification of KDE Plasma 6's default Icons-Only Task Manager with a visual overhaul inspired by Windows 7.

It replaces the default theme-drawn SVG frames with custom pure-QML rounded translucent cards, bringing back the classic Aero glass aesthetic with modern polish.

---

## Installation

Run the installation script to install the plasmoid to your local user directory:

```bash
./install.sh
```

Restart Plasma Shell to apply:

```bash
systemctl --user restart plasma-plasmashell.service
```

### Adding to Panel
1. Right-click on your panel → **Add Widgets…**
2. Locate **Veronica Tasks** and drag it onto your panel.
3. (Optional) Remove the default task manager.
4. Right-click **Veronica Tasks** → **Configure Veronica Tasks…** to customize appearance and spacing.

---

## Packaging

To generate a distributable `.plasmoid` bundle:

```bash
./package.sh
```

---

## License

GNU General Public License v2.0 or later (GPL-2.0-or-later).
