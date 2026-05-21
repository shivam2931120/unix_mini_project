PROJECT := unix-utility-suite
COMMAND := unix-toolkit
VERSION ?= 1.0.0
PREFIX ?= /usr
CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -pedantic -O2
DEB_ARCH ?= $(shell dpkg --print-architecture 2>/dev/null || uname -m)
GNOME_UUID := unix-toolkit-launcher@shivam2931120.github.io
FLATPAK_ID := io.github.shivam2931120.UnixToolkitLauncher

BINS := calc_gui proc_manager sched_sim
DEST_BINDIR := $(DESTDIR)$(PREFIX)/bin
DEST_LIBEXECDIR := $(DESTDIR)$(PREFIX)/lib/$(PROJECT)
DEST_DATADIR := $(DESTDIR)$(PREFIX)/share

.PHONY: all clean install uninstall package-deb package-snap package-gnome-extension package-vscode-extension package-flatpak-bundle package-submission-artifacts owner-finalize test test-deb-install docker-build

all: $(BINS)

calc_gui: calc_gui.c
	$(CC) $(CFLAGS) $< -o $@

proc_manager: proc_manager.c
	$(CC) $(CFLAGS) $< -o $@

sched_sim: sched_sim.c
	$(CC) $(CFLAGS) $< -o $@

test: all
	bash -n unix.sh
	printf 'FCFS\n3\n5,3,2\n0,1,2\n\n1\n' > /tmp/unix-toolkit-sched-test.in
	./sched_sim --input /tmp/unix-toolkit-sched-test.in --output /tmp/unix-toolkit-sched-test.out
	grep -q 'Average Waiting Time' /tmp/unix-toolkit-sched-test.out
	rm -f /tmp/unix-toolkit-sched-test.in /tmp/unix-toolkit-sched-test.out

install: all
	install -d $(DEST_BINDIR)
	install -d $(DEST_LIBEXECDIR)
	install -d $(DEST_DATADIR)/applications
	install -d $(DEST_DATADIR)/doc/$(PROJECT)
	install -d $(DEST_DATADIR)/man/man1
	install -m 755 unix.sh $(DEST_BINDIR)/$(COMMAND)
	install -m 755 $(BINS) $(DEST_LIBEXECDIR)/
	install -m 644 README.md DEPLOYMENT.md CHANGELOG.md LICENSE $(DEST_DATADIR)/doc/$(PROJECT)/
	install -m 644 packaging/unix-toolkit.desktop $(DEST_DATADIR)/applications/unix-toolkit.desktop
	install -m 644 docs/unix-toolkit.1 $(DEST_DATADIR)/man/man1/unix-toolkit.1

uninstall:
	rm -f $(DEST_BINDIR)/$(COMMAND)
	rm -rf $(DEST_LIBEXECDIR)
	rm -f $(DEST_DATADIR)/applications/unix-toolkit.desktop
	rm -rf $(DEST_DATADIR)/doc/$(PROJECT)
	rm -f $(DEST_DATADIR)/man/man1/unix-toolkit.1

package-deb: all
	rm -rf dist/deb-root
	$(MAKE) install DESTDIR=$(CURDIR)/dist/deb-root PREFIX=/usr
	install -d dist/deb-root/DEBIAN
	sed -e 's/@VERSION@/$(VERSION)/g' -e 's/@ARCH@/$(DEB_ARCH)/g' packaging/deb/control.in > dist/deb-root/DEBIAN/control
	dpkg-deb -Zxz --root-owner-group --build dist/deb-root dist/$(PROJECT)_$(VERSION)_$(DEB_ARCH).deb

package-snap: all
	rm -rf dist/snap-root
	$(MAKE) install DESTDIR=$(CURDIR)/dist/snap-root PREFIX=/usr
	install -d dist/snap-root/meta
	sed -e 's/@VERSION@/$(VERSION)/g' packaging/snap.yaml.in > dist/snap-root/meta/snap.yaml
	snap pack --check-skeleton dist/snap-root
	snap pack --compression=xz --filename=$(PROJECT)_$(VERSION)_$(DEB_ARCH).snap dist/snap-root dist

package-gnome-extension:
	install -d dist
	@if command -v gnome-extensions >/dev/null 2>&1; then \
		gnome-extensions pack -f -o dist platforms/gnome/$(GNOME_UUID); \
	else \
		cd platforms/gnome/$(GNOME_UUID) && zip -qr ../../../dist/$(GNOME_UUID).shell-extension.zip .; \
	fi

package-vscode-extension:
	install -d dist
	cd platforms/vscode && npx --yes @vscode/vsce package --out ../../dist/$(PROJECT)-vscode-$(VERSION).vsix

package-flatpak-bundle:
	rm -rf dist/flatpak-build dist/flatpak-repo
	@builder="$$(command -v flatpak-builder || true)"; \
	if [ -z "$$builder" ] && flatpak info --user org.flatpak.Builder >/dev/null 2>&1; then \
		builder="flatpak run org.flatpak.Builder"; \
	fi; \
	if [ -z "$$builder" ]; then \
		echo "flatpak-builder is not installed; install it to build the Flatpak bundle."; \
		exit 1; \
	fi; \
	$$builder --force-clean --repo=dist/flatpak-repo dist/flatpak-build platforms/flatpak/$(FLATPAK_ID).yml
	flatpak build-bundle dist/flatpak-repo dist/$(FLATPAK_ID).flatpak $(FLATPAK_ID)

package-submission-artifacts: package-deb package-snap package-gnome-extension package-vscode-extension package-flatpak-bundle

owner-finalize:
	scripts/finalize-owner-deployment.sh --publish

test-deb-install: package-deb
	scripts/test-deb-install.sh dist/$(PROJECT)_$(VERSION)_$(DEB_ARCH).deb

docker-build:
	docker build -f packaging/docker/Dockerfile -t $(PROJECT):$(VERSION) .

clean:
	rm -f $(BINS)
	rm -rf dist
