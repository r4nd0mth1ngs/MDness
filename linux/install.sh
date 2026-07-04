#!/bin/sh
# MDness Linux installer for Ubuntu and Arch.
# Installs runtime dependencies (apt or pacman), then copies the app, shared web
# assets, desktop entry and icon under $PREFIX (default /usr/local).
# Usage: ./linux/install.sh            (installs deps + app)
#        ./linux/install.sh --no-deps  (skip dependency install)
set -eu

PREFIX="${PREFIX:-/usr/local}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DEPS=1
[ "${1:-}" = "--no-deps" ] && INSTALL_DEPS=0

as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

if [ "$INSTALL_DEPS" -eq 1 ]; then
    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing dependencies with apt…"
        as_root apt-get update
        as_root apt-get install -y python3-gi gir1.2-gtk-4.0 gir1.2-webkit-6.0
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing dependencies with pacman…"
        as_root pacman -S --needed --noconfirm python-gobject gtk4 webkitgtk-6.0
    else
        echo "Unknown package manager. Install manually: GTK4, WebKitGTK 6.0, PyGObject." >&2
    fi
fi

echo "Installing MDness to $PREFIX…"
as_root install -Dm755 "$REPO/linux/mdness" "$PREFIX/bin/mdness"
as_root install -d "$PREFIX/share/mdness/web"
as_root sh -c "cp '$REPO'/web/* '$PREFIX/share/mdness/web/'"
as_root install -Dm644 "$REPO/linux/mdness.desktop" "$PREFIX/share/applications/mdness.desktop"
as_root install -Dm644 "$REPO/linux/mdness.png" "$PREFIX/share/icons/hicolor/256x256/apps/mdness.png"

command -v update-desktop-database >/dev/null 2>&1 && \
    as_root update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    as_root gtk-update-icon-cache -qtf "$PREFIX/share/icons/hicolor" 2>/dev/null || true

echo "Done. Launch 'mdness', or bind a global shortcut with: mdness --install-shortcut"
