# Unix Utility Suite

Unix Utility Suite is a small Linux desktop toolkit built with Bash, C, and
Zenity. It provides one launcher command, `unix-toolkit`, for common system
utility tasks.

## Features

- System information viewer
- Media file launcher
- Home-directory file search
- Debian/Ubuntu package update helper
- PDF opener
- GUI calculator
- Process viewer and terminator
- CPU scheduling simulator for FCFS, SJF, Priority, and Round Robin
- Running systemd service manager
- Network throughput monitor

## Requirements

- Linux desktop session
- `bash`
- `gcc` and `make` for building from source
- `zenity`
- `xdg-open` from `xdg-utils`
- `procps`, `coreutils`, `findutils`, `util-linux`, and `iproute2`
- A terminal emulator such as `gnome-terminal`, `x-terminal-emulator`, or `xterm`

Optional runtime tools:

- `mpv` or `vlc` for media playback
- `apt`, `sudo`, and `systemctl` for update and service actions

On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install build-essential zenity xdg-utils procps coreutils findutils util-linux iproute2 gnome-terminal sudo
```

## Build And Run

```bash
make
./unix.sh
```

Run the non-GUI smoke test:

```bash
make test
```

Run the Debian package install-path test:

```bash
make test-deb-install
```

## Install Locally

```bash
sudo make install
unix-toolkit
```

Uninstall:

```bash
sudo make uninstall
```

## Build A Debian Package

```bash
make package-deb
sudo apt install ./dist/unix-utility-suite_1.0.0_$(dpkg --print-architecture).deb
unix-toolkit
```

## Build Submission Artifacts

```bash
make package-submission-artifacts
```

The Flatpak part of this target needs either `flatpak-builder` or the user
Flatpak app `org.flatpak.Builder`.

This creates:

- Debian package: `dist/unix-utility-suite_1.0.0_<arch>.deb`
- Snap package: `dist/unix-utility-suite_1.0.0_<arch>.snap`
- GNOME Shell extension zip: `dist/unix-toolkit-launcher@shivam2931120.github.io.shell-extension.zip`
- VS Code extension package: `dist/unix-utility-suite-vscode-1.0.0.vsix`
- Flatpak bundle: `dist/io.github.shivam2931120.UnixToolkitLauncher.flatpak`

Optional targets:

```bash
make docker-build
```

More deployment and submission steps are in [DEPLOYMENT.md](DEPLOYMENT.md).
Current release status is tracked in [SUBMISSION_STATUS.md](SUBMISSION_STATUS.md).

## Project Layout

```text
.
├── unix.sh
├── calc_gui.c
├── proc_manager.c
├── sched_sim.c
├── Makefile
├── docs/
├── packaging/
├── platforms/
└── snap/
```

## License

MIT. See [LICENSE](LICENSE).
