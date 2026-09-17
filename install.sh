#!/usr/bin/env bash
set -e

PLUGIN_ID="stakillion.veronica.tasks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/${PLUGIN_ID}"

echo "==> Installing Veronica Tasks Plasmoid for KDE Plasma 6..."

# Create target directory
mkdir -p "${HOME}/.local/share/plasma/plasmoids"

echo "Syncing plugin files..."
rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
cp -r "${SCRIPT_DIR}/contents" "${TARGET_DIR}/contents"
cp "${SCRIPT_DIR}/metadata.json" "${TARGET_DIR}/metadata.json"

echo ""
echo "==> Veronica Tasks plugin successfully installed!"
echo "To use it:"
echo "1. Right-click on your panel -> 'Add Widgets...'"
echo "2. Drag 'Veronica Tasks' onto your panel"
echo "3. (Optional) Right-click the widget -> 'Configure Veronica Tasks...' to customize appearance and behavior."
echo "4. (Optional) If updating an existing instance, restart Plasma shell:"
echo "   systemctl --user restart plasma-plasmashell.service"
