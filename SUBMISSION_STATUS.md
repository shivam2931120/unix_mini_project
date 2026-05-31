# Submission Status

Last audited: 2026-05-31

## Completed

- Source pushed to `main`.
- Release tag created: `v1.1.0`.
- GitHub release published:
  https://github.com/shivam2931120/unix_mini_project/releases/tag/v1.1.0
- GitHub release assets uploaded:
  - `unix-utility-suite_1.1.0_amd64.deb`
  - `unix-utility-suite_1.1.0_amd64.snap`
  - `unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip`
  - `unix-utility-suite-vscode-1.1.0.vsix`
  - `io.github.shivam2931120.UnixToolkitLauncher.flatpak`
- GitHub Actions release workflow passed.
- `.deb` install-path test passed with `make test-deb-install`.
- VS Code `.vsix` 1.1.0 installed locally.
- Flatpak bundle 1.1.0 built and installed locally.
- GNOME Shell extension version 2 zip built and installed into the user extensions folder.
- Snap Store revision 3 uploaded for 1.1.0.

## Not Completed Because Credentials Or Sudo Are Required

- Real system `.deb` install with `sudo apt install`.
- Local Snap install with `sudo snap install --dangerous --classic`.
- Snap Store public release, pending classic-confinement approval for revision 3.
- Visual Studio Marketplace publication.
- extensions.gnome.org upload/review for extension version 2.
- Flathub publication.

## Exact Commands For The Owner

Real Debian package install:

```bash
sudo apt install ./dist/unix-utility-suite_1.1.0_amd64.deb
unix-toolkit
```

Local Snap install:

```bash
sudo snap install --dangerous --classic ./dist/unix-utility-suite_1.1.0_amd64.snap
```

Local VS Code install:

```bash
code --install-extension ./dist/unix-utility-suite-vscode-1.1.0.vsix --force
```

Local Flatpak install:

```bash
flatpak install --user -y ./dist/io.github.shivam2931120.UnixToolkitLauncher.flatpak
```

GNOME Shell extension:

```bash
gnome-extensions install --force ./dist/unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip
```

Then log out and back in, or restart GNOME Shell where supported, and enable:

```bash
gnome-extensions enable unix-toolkit-launcher@shivam2931120.github.io
```

Run the guided owner-side finalization helper:

```bash
make owner-finalize
```

To attempt supported CLI publishing after setting account credentials:

```bash
scripts/finalize-owner-deployment.sh --publish-now
```

Store submissions must be completed while logged into the relevant publisher
accounts.
