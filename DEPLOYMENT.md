# Deployment Checklist

This repository now supports the realistic deployment paths for the original
C/Bash project:

- native Linux command and desktop launcher
- Debian/Ubuntu `.deb`
- GitHub release artifacts
- Snap manifest
- GNOME Shell launcher extension
- VS Code launcher extension
- experimental Flatpak host launcher
- Docker build/test image

The `.deb` is the primary distribution format. The GNOME, VS Code, and Flatpak
artifacts are wrappers that launch the installed `unix-toolkit` command.

## 1. Verify Locally

```bash
make clean
make test
make test-deb-install
desktop-file-validate packaging/unix-toolkit.desktop
```

`make test-deb-install` installs the generated `.deb` into a disposable
alternate root using `fakeroot` and verifies the installed command, helper
binaries, desktop file, man page, and scheduler helper.

For a real host install on Ubuntu/Debian, run this from an account with sudo:

```bash
make package-deb
sudo apt install ./dist/unix-utility-suite_1.1.0_$(dpkg --print-architecture).deb
unix-toolkit
```

Then manually open every GUI menu item in a desktop session.

## 2. Build Submission Artifacts

```bash
make package-submission-artifacts
```

Expected outputs:

- `dist/unix-utility-suite_1.1.0_<arch>.deb`
- `dist/unix-utility-suite_1.1.0_<arch>.snap`
- `dist/unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip`
- `dist/unix-utility-suite-vscode-1.1.0.vsix`
- `dist/io.github.shivam2931120.UnixToolkitLauncher.flatpak`

Optional outputs:

```bash
make docker-build
```

## 3. GitHub Release

1. Commit all release files.
2. Push the branch.
3. Create a tag:

   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

4. Create a GitHub release and upload everything in `dist/`.

With GitHub CLI:

```bash
gh release create v1.1.0 dist/* \
  --title "Unix Utility Suite 1.1.0" \
  --notes-file RELEASE_NOTES.md
```

## 4. Debian/Ubuntu `.deb`

Build:

```bash
make package-deb
```

The package installs:

- `/usr/bin/unix-toolkit`
- `/usr/lib/unix-utility-suite/`
- `/usr/share/applications/unix-toolkit.desktop`
- `/usr/share/man/man1/unix-toolkit.1`

This `.deb` is ready for direct GitHub release distribution. Official Debian or
Ubuntu repository submission requires a full Debian source package and sponsor
review; this repository currently builds a binary package for direct
distribution.

## 5. Snap

The starter manifest is `snap/snapcraft.yaml`.

Build the local snap artifact without Snapcraft:

```bash
make package-snap
```

Output:

```text
dist/unix-utility-suite_1.1.0_<arch>.snap
```

Build with Snapcraft when Snapcraft is installed:

```bash
snapcraft pack
```

Because this toolkit manages host processes, packages, services, and files, the
Snap uses `classic` confinement. Publishing to the Snap Store requires a
Snapcraft account and a classic-confinement review request.

## 6. GNOME Shell Extension

Build:

```bash
make package-gnome-extension
```

Output:

```text
dist/unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip
```

Submit that zip to extensions.gnome.org. The extension does not bundle C
binaries; it only adds a top-bar launcher for the host-installed
`unix-toolkit` command.

## 7. VS Code Extension

Build:

```bash
make package-vscode-extension
```

Output:

```text
dist/unix-utility-suite-vscode-1.1.0.vsix
```

Install locally:

```bash
code --install-extension dist/unix-utility-suite-vscode-1.1.0.vsix
```

Publish with `vsce` after creating a Visual Studio Marketplace publisher and
Personal Access Token:

```bash
cd platforms/vscode
npx @vscode/vsce publish
```

## 8. Flatpak

The Flatpak files are in `platforms/flatpak/`. This is an experimental wrapper
that calls the host-installed `unix-toolkit` through `flatpak-spawn --host`.

Build when `flatpak-builder` is installed:

```bash
make package-flatpak-bundle
```

If `org.flatpak.Builder` is installed as a user Flatpak, the Makefile can use
that instead of a host `flatpak-builder` binary.

This is suitable for local testing. Flathub submission is unlikely to accept
the current design because the app is fundamentally a host-system manager.

## 9. Docker

Build:

```bash
make docker-build
```

The Docker image is for reproducible build/test verification and scheduler
demo output. It is not the primary GUI distribution format.

## 10. Guided Owner Finalization

Run this from your local terminal to complete sudo/account-gated installs with prompts:

```bash
make owner-finalize
```

To attempt supported CLI publishing after setting account credentials:

```bash
scripts/finalize-owner-deployment.sh --publish-now
```

The helper verifies release artifacts, asks before system installs, checks publisher readiness, and prints the store-publishing commands when invoked through the Make target.

## 11. Store Credentials Still Required

These actions cannot be completed from this repository alone:

- Snap Store publishing needs your Snapcraft login and classic-confinement approval.
- VS Code Marketplace publishing needs your publisher account and PAT.
- GNOME Extensions publishing needs your extensions.gnome.org account.
- Flathub publishing needs a Flathub submission/PR and likely an app redesign.
- A true host `.deb` install test needs sudo on the target machine.

## Reference Docs

- Debian binary packages: https://www.debian.org/doc/debian-policy/ch-binary.html
- Snap documentation: https://snapcraft.io/docs/
- Snap classic confinement: https://documentation.ubuntu.com/snapcraft/stable/explanation/classic-confinement/
- GNOME Shell extension review guidelines: https://gjs.guide/extensions/review-guidelines/review-guidelines.html
- VS Code extension publishing: https://code.visualstudio.com/api/working-with-extensions/publishing-extension
- Flatpak manifests: https://docs.flatpak.org/en/latest/manifests.html
