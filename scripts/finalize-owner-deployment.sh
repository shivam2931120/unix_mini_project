#!/usr/bin/env bash

set -euo pipefail

PROJECT="unix-utility-suite"
VERSION="1.0.0"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

DEB="$DIST_DIR/${PROJECT}_${VERSION}_${ARCH}.deb"
SNAP="$DIST_DIR/${PROJECT}_${VERSION}_${ARCH}.snap"
VSIX="$DIST_DIR/${PROJECT}-vscode-${VERSION}.vsix"
GNOME_ZIP="$DIST_DIR/unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip"
FLATPAK="$DIST_DIR/io.github.shivam2931120.UnixToolkitLauncher.flatpak"

RUN_PUBLISH=0
RUN_PUBLISH_NOW=0
ASSUME_YES=0

usage() {
    cat <<USAGE
Usage: $0 [--yes] [--publish] [--publish-now]

Installs and verifies the release artifacts that require the owner's sudo
password or desktop account context.

Options:
  --yes      Run local install steps without prompting.
  --publish      Print/check external store publishing commands.
  --publish-now  Attempt supported CLI publishing when credentials are present.

This script does not store passwords or tokens. Marketplace submissions still
require your Snapcraft, Visual Studio Marketplace, GNOME Extensions, or Flathub
accounts.
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --yes)
            ASSUME_YES=1
            ;;
        --publish)
            RUN_PUBLISH=1
            ;;
        --publish-now)
            RUN_PUBLISH=1
            RUN_PUBLISH_NOW=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

ask() {
    local prompt=$1

    if [ "$ASSUME_YES" -eq 1 ]; then
        return 0
    fi

    read -r -p "$prompt [y/N] " answer
    case "$answer" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_file() {
    local path=$1

    if [ ! -f "$path" ]; then
        echo "Missing artifact: $path" >&2
        echo "Run: make package-submission-artifacts" >&2
        exit 1
    fi
}

run_optional() {
    local label=$1
    shift

    echo
    echo "==> $label"
    "$@"
}

verify_artifacts() {
    require_file "$DEB"
    require_file "$SNAP"
    require_file "$VSIX"
    require_file "$GNOME_ZIP"
    require_file "$FLATPAK"
}

install_deb() {
    if ask "Install the Debian package system-wide with sudo apt?"; then
        run_optional "Installing .deb" sudo apt install -y "$DEB"
        run_optional "Checking installed command" command -v unix-toolkit
    else
        echo "Skipped .deb install."
    fi
}

install_snap() {
    if ! command -v snap >/dev/null 2>&1; then
        echo "snap is not installed; skipped Snap install."
        return
    fi

    if ask "Install the Snap package locally with sudo snap install --dangerous --classic?"; then
        run_optional "Installing Snap" sudo snap install --dangerous --classic "$SNAP"
    else
        echo "Skipped Snap install."
    fi
}

install_vscode() {
    if ! command -v code >/dev/null 2>&1; then
        echo "VS Code command 'code' is not available; skipped VSIX install."
        return
    fi

    if ask "Install the VS Code extension package locally?"; then
        run_optional "Installing VSIX" code --install-extension "$VSIX" --force
    else
        echo "Skipped VS Code extension install."
    fi
}

install_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "flatpak is not installed; skipped Flatpak install."
        return
    fi

    if ask "Install the Flatpak bundle for the current user?"; then
        run_optional "Installing Flatpak bundle" flatpak install --user -y "$FLATPAK"
    else
        echo "Skipped Flatpak install."
    fi
}

install_gnome_extension() {
    if ! command -v gnome-extensions >/dev/null 2>&1; then
        echo "gnome-extensions is not available; skipped GNOME extension install."
        return
    fi

    if ask "Install the GNOME Shell extension zip for the current user?"; then
        run_optional "Installing GNOME extension" gnome-extensions install --force "$GNOME_ZIP"
        echo "Log out and back in, then run:"
        echo "  gnome-extensions enable unix-toolkit-launcher@shivam2931120.github.io"
    else
        echo "Skipped GNOME extension install."
    fi
}

snapcraft_status() {
    if ! command -v snapcraft >/dev/null 2>&1; then
        echo "missing"
        return
    fi

    if snapcraft whoami >/dev/null 2>&1; then
        echo "logged-in"
    else
        echo "not-logged-in"
    fi
}

vsce_status() {
    if [ -n "${VSCE_PAT:-}" ]; then
        echo "token-present"
    else
        echo "missing-VSCE_PAT"
    fi
}

publish_notes() {
    local snap_status
    local vsce_ready

    snap_status=$(snapcraft_status)
    vsce_ready=$(vsce_status)

    cat <<NOTES

==> Store publishing checklist

GitHub release is already the primary public distribution:
  https://github.com/shivam2931120/unix_mini_project/releases/tag/v1.0.0

Snap Store readiness: $snap_status
  snapcraft login
  snapcraft upload --release=stable "$SNAP"
  Note: classic confinement requires Snap Store review.

VS Code Marketplace readiness: $vsce_ready
  cd "$ROOT_DIR/platforms/vscode"
  npx @vscode/vsce publish --packagePath "$VSIX"
  Requires a publisher account and VSCE_PAT.

GNOME Extensions:
  Upload "$GNOME_ZIP" at https://extensions.gnome.org/upload/

Flathub:
  The Flatpak artifact is a host launcher and is suitable for local/GitHub
  release use. Flathub submission likely needs redesign because the app manages
  host system state.
NOTES
}

publish_snap_if_ready() {
    if [ "$(snapcraft_status)" != "logged-in" ]; then
        echo "Snap Store publish skipped: install snapcraft and run 'snapcraft login' first."
        return
    fi

    if ask "Upload the Snap artifact to the stable channel now?"; then
        run_optional "Publishing Snap" snapcraft upload --release=stable "$SNAP"
    else
        echo "Skipped Snap Store publish."
    fi
}

publish_vscode_if_ready() {
    if [ -z "${VSCE_PAT:-}" ]; then
        echo "VS Code publish skipped: set VSCE_PAT first."
        return
    fi

    if ask "Publish the VS Code extension to Marketplace now using VSCE_PAT?"; then
        run_optional "Publishing VS Code extension" npx @vscode/vsce publish --packagePath "$VSIX" --pat "$VSCE_PAT"
    else
        echo "Skipped VS Code Marketplace publish."
    fi
}

publish_if_requested() {
    if [ "$RUN_PUBLISH_NOW" -ne 1 ]; then
        return
    fi

    publish_snap_if_ready
    publish_vscode_if_ready
    echo "GNOME Extensions and Flathub remain manual review/submission flows."
}

cd "$ROOT_DIR"
verify_artifacts

echo "Release artifacts found in: $DIST_DIR"
echo "This script may ask for your sudo password during package installs."

install_deb
install_snap
install_vscode
install_flatpak
install_gnome_extension

if [ "$RUN_PUBLISH" -eq 1 ]; then
    publish_notes
fi

publish_if_requested

echo
echo "Owner finalization script finished."
