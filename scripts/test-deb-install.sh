#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 PACKAGE.deb" >&2
    exit 2
fi

package=$1
test_root=$(mktemp -d "${TMPDIR:-/tmp}/unix-toolkit-debtest.XXXXXX")

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/var/lib/dpkg" "$test_root/var/log"
touch "$test_root/var/lib/dpkg/status"

fakeroot dpkg \
    --root="$test_root" \
    --force-not-root \
    --force-depends \
    --install "$package" >/tmp/unix-toolkit-debtest.log 2>&1 || {
        cat /tmp/unix-toolkit-debtest.log >&2
        exit 1
    }

test -x "$test_root/usr/bin/unix-toolkit"
test -x "$test_root/usr/lib/unix-utility-suite/calc_gui"
test -x "$test_root/usr/lib/unix-utility-suite/proc_manager"
test -x "$test_root/usr/lib/unix-utility-suite/sched_sim"
test -f "$test_root/usr/share/applications/unix-toolkit.desktop"
test -f "$test_root/usr/share/man/man1/unix-toolkit.1"

bash -n "$test_root/usr/bin/unix-toolkit"

input_file="$test_root/sched-input.txt"
output_file="$test_root/sched-output.txt"
printf 'SJF\n3\n6,2,4\n0,1,2\n\n1\n' > "$input_file"
"$test_root/usr/lib/unix-utility-suite/sched_sim" --input "$input_file" --output "$output_file"
grep -q 'Average Waiting Time' "$output_file"

PATH="$test_root/fake-bin:$PATH"
mkdir -p "$test_root/fake-bin"
cat > "$test_root/fake-bin/zenity" <<'ZENITY'
#!/usr/bin/env sh
exit 1
ZENITY
chmod +x "$test_root/fake-bin/zenity"

UNIX_TOOLKIT_LIBEXEC="$test_root/usr/lib/unix-utility-suite" "$test_root/usr/bin/unix-toolkit"

echo "Debian package install test passed in $test_root"
