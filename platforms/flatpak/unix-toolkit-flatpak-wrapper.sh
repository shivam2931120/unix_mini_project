#!/usr/bin/env sh

if ! command -v flatpak-spawn >/dev/null 2>&1; then
    echo "flatpak-spawn is required to launch the host-installed unix-toolkit command." >&2
    exit 1
fi

exec flatpak-spawn --host unix-toolkit "$@"
