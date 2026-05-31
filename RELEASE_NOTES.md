# Unix Utility Suite 1.1.0

GNOME Shell launcher feature update.

## Highlights

- GNOME Shell menu now exposes direct actions for System Info, File Search, Process Manager, Network Monitor, and Scheduling Simulator.
- GNOME Shell preferences page lets users choose which menu actions appear.
- GNOME Shell install detection now shows install help when `unix-toolkit` is missing.
- Added Super+Alt+U shortcut for opening the full toolkit launcher.
- Added `unix-toolkit --system-info`, `--file-search`, `--process-manager`, `--network-monitor`, and related command-line actions.

## Install

```bash
sudo apt install ./unix-utility-suite_1.1.0_amd64.deb
unix-toolkit
```

The GNOME, VS Code, and Flatpak launchers require the host `unix-toolkit`
command to be installed first. Use the 1.1.0 package with the GNOME extension
version 2 because direct menu actions rely on the new command-line flags.

## Local Artifact Installs

```bash
sudo snap install --dangerous --classic ./unix-utility-suite_1.1.0_amd64.snap
code --install-extension ./unix-utility-suite-vscode-1.1.0.vsix --force
flatpak install --user -y ./io.github.shivam2931120.UnixToolkitLauncher.flatpak
gnome-extensions install --force './unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip'
```

## Submission Status

Completed:

- GitHub release published with `.deb`, `.snap`, GNOME extension zip, VSIX, and Flatpak bundle.
- GitHub Actions release workflow passed.
- Local `.deb` install-path test passed with `make test-deb-install`.
- VS Code extension and Flatpak bundle were installed locally.
- Docker image built and ran the scheduler smoke command.

Still requires owner credentials, store approval, or sudo:

- Real system `.deb` install with `sudo apt install`.
- Local Snap install with `sudo snap install`.
- Snap Store classic-confinement review before public release.
- Visual Studio Marketplace publication.
- extensions.gnome.org upload/review for extension version 2.
- Flathub publication.
