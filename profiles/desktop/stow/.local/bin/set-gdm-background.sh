#!/usr/bin/env bash
# Set the GDM login screen background to the current GNOME desktop wallpaper.
#
# GNOME Shell's login screen draws its background from the #lockDialogGroup
# rule inside gnome-shell-theme.gresource. This script builds a modified copy
# of that bundle, with the wallpaper embedded and a CSS override appended, at
# $CUSTOM. GNOME Shell only loads the theme from its fixed path, so the stock
# file is moved aside with dpkg-divert and that path becomes a symlink to the
# custom copy. Package upgrades then update the diverted stock file instead
# of replacing the symlink.
#
# The distro logo under the login prompt isn't part of the theme; it comes
# from the org.gnome.login-screen logo key in $GREETER_DEFAULTS, so the
# script comments that out and sets an empty logo instead.
#
# Usage:
#   ./set-gdm-background.sh            apply the current wallpaper, hide the logo
#   ./set-gdm-background.sh --restore  put the stock theme and logo back
#
# Run as your normal user (not with sudo); it calls sudo when it needs root.
# Re-run it after a gnome-shell upgrade to rebuild from the updated stock theme.

set -euo pipefail

STOCK=/usr/share/gnome-shell/gnome-shell-theme.gresource
DIVERTED=$STOCK.distrib
CUSTOM=/usr/local/share/gnome-shell/custom-gnome-shell-theme.gresource
PREFIX=/org/gnome/shell/theme
IMAGE_NAME=login-background.jpg
GREETER_DEFAULTS=/etc/gdm3/greeter.dconf-defaults
LOGO_MARK='# disabled by set-gdm-background.sh'

die() { echo "error: $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as your normal user; the wallpaper setting is per-user"

if [[ ${1:-} == --restore ]]; then
    if [[ $(dpkg-divert --truename "$STOCK") != "$STOCK" ]]; then
        [[ -L $STOCK ]] && sudo rm "$STOCK"
        sudo dpkg-divert --local --rename --remove "$STOCK"
        sudo rm -f "$CUSTOM"
        echo "Restored the stock login screen theme."
    fi
    if grep -q "$LOGO_MARK\$" "$GREETER_DEFAULTS"; then
        # Uncomment the original logo line and drop the empty one after it.
        sudo sed -i "/$LOGO_MARK\$/{s|^#\(.*\)  $LOGO_MARK\$|\1|;n;/^logo=''\$/d}" "$GREETER_DEFAULTS"
        sudo /usr/share/gdm/generate-config
        echo "Restored the login screen logo."
    fi
    echo "Log out to see the stock login screen."
    exit 0
fi

command -v gresource >/dev/null || die "gresource not found (package libglib2.0-bin)"
if ! command -v glib-compile-resources >/dev/null; then
    echo "glib-compile-resources is needed (package libglib2.0-dev-bin)."
    sudo apt-get install -y libglib2.0-dev-bin
fi

# Pick the wallpaper GNOME is showing for the active light/dark style.
if [[ $(gsettings get org.gnome.desktop.interface color-scheme) == "'prefer-dark'" ]]; then
    uri=$(gsettings get org.gnome.desktop.background picture-uri-dark)
else
    uri=$(gsettings get org.gnome.desktop.background picture-uri)
fi
uri=${uri//\'/}
[[ -n $uri ]] || die "no wallpaper is set"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/theme"

# Resolve the URI (and the first image of an animated .xml wallpaper), then
# convert to JPEG so the greeter doesn't depend on a format-specific loader.
python3 - "$uri" "$work/theme/$IMAGE_NAME" <<'EOF'
import sys, urllib.parse, xml.etree.ElementTree as ET
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf

uri, out = sys.argv[1:]
path = urllib.parse.unquote(urllib.parse.urlparse(uri).path)
if path.endswith(".xml"):
    node = ET.parse(path).find(".//file")
    if node is None:
        sys.exit(f"error: no image found in {path}")
    path = node.text.strip()
print(f"Wallpaper: {path}")
GdkPixbuf.Pixbuf.new_from_file(path).savev(out, "jpeg", ["quality"], ["92"])
EOF

# Build from the stock theme, wherever dpkg currently keeps it.
source=$(dpkg-divert --truename "$STOCK")
[[ -f $source && ! -L $source ]] || die "stock theme not found at $source"

manifest=$work/theme.gresource.xml
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo "<gresources><gresource prefix=\"$PREFIX\">"
    echo "<file>$IMAGE_NAME</file>"
    for res in $(gresource list "$source"); do
        rel=${res#"$PREFIX"/}
        mkdir -p "$work/theme/$(dirname "$rel")"
        gresource extract "$source" "$res" > "$work/theme/$rel"
        echo "<file>$rel</file>"
    done
    echo '</gresource></gresources>'
} > "$manifest"

for css in "$work"/theme/gnome-shell-{dark,light,high-contrast}.css; do
    [[ -f $css ]] || continue
    cat >> "$css" <<EOF

#lockDialogGroup {
  background: #222226 url(resource://$PREFIX/$IMAGE_NAME);
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat; }
EOF
done

glib-compile-resources --sourcedir="$work/theme" --target="$work/theme.gresource" "$manifest"
sudo install -D -m 644 "$work/theme.gresource" "$CUSTOM"

# Point GNOME Shell's fixed theme path at the custom copy.
if [[ $source == "$STOCK" ]]; then
    sudo dpkg-divert --local --rename --divert "$DIVERTED" --add "$STOCK"
fi
sudo ln -sfn "$CUSTOM" "$STOCK"

# Hide the distro logo, keeping the original line as a comment for --restore,
# then rebuild GDM's dconf database (the same step "systemctl reload gdm" runs,
# without signalling the running gdm).
sudo sed -i "/^logo=''\$/! s|^logo=.*|#&  $LOGO_MARK\nlogo=''|" "$GREETER_DEFAULTS"
sudo /usr/share/gdm/generate-config

echo "Login screen background updated and logo hidden. Log out (or reboot) to see it."
echo "To undo: $0 --restore"
