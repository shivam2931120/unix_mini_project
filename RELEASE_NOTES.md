# Unix Utility Suite 1.0.0

First packaged release of Unix Utility Suite.

## Highlights

- Installable `unix-toolkit` command for Linux desktops.
- Debian/Ubuntu `.deb` package.
- GNOME Shell launcher extension package.
- VS Code launcher extension package.
- Experimental Flatpak launcher manifest.
- Docker build/test image.

## Install

```bash
sudo apt install ./unix-utility-suite_1.0.0_amd64.deb
unix-toolkit
```

The GNOME, VS Code, and Flatpak launchers require the host `unix-toolkit`
command to be installed first.

## Local Artifact Installs

```bash
sudo snap install --dangerous --classic ./unix-utility-suite_1.0.0_amd64.snap
code --install-extension ./unix-utility-suite-vscode-1.0.0.vsix --force
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

Still requires owner credentials or sudo:

- Real system `.deb` install with `sudo apt install`.
- Local Snap install with `sudo snap install`.
- Snap Store publication.
- Visual Studio Marketplace publication.
- extensions.gnome.org publication.
- Flathub publication.
