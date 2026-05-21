#!/usr/bin/env bash

set -u

APP_NAME="Linux Utility Toolkit"
PROJECT_NAME="unix-utility-suite"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIBEXEC_DIR="${UNIX_TOOLKIT_LIBEXEC:-}"

if [ -z "$LIBEXEC_DIR" ]; then
    PREFIX_LIBEXEC="${SCRIPT_DIR%/bin}/lib/$PROJECT_NAME"
    if [ -x "$SCRIPT_DIR/sched_sim" ] || [ -x "$SCRIPT_DIR/calc_gui" ] || [ -x "$SCRIPT_DIR/proc_manager" ]; then
        LIBEXEC_DIR="$SCRIPT_DIR"
    elif [ -x "$PREFIX_LIBEXEC/sched_sim" ] || [ -x "$PREFIX_LIBEXEC/calc_gui" ] || [ -x "$PREFIX_LIBEXEC/proc_manager" ]; then
        LIBEXEC_DIR="$PREFIX_LIBEXEC"
    else
        LIBEXEC_DIR="/usr/lib/$PROJECT_NAME"
    fi
fi

notify_error() {
    local message=$1

    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$APP_NAME" --width=420 --text="$message"
    else
        printf '%s\n' "$message" >&2
    fi
}

notify_info() {
    local title=$1
    local message=$2

    if command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$title" --width=520 --text="$message"
    else
        printf '%s\n' "$message"
    fi
}

require_command() {
    local command_name=$1

    if ! command -v "$command_name" >/dev/null 2>&1; then
        notify_error "Missing dependency: $command_name"
        return 1
    fi
}

ensure_zenity() {
    require_command zenity || exit 1
}

run_in_terminal() {
    local title=$1
    local command_text=$2

    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal --title="$title" -- bash -lc "$command_text"
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        x-terminal-emulator -T "$title" -e bash -lc "$command_text"
    elif command -v xterm >/dev/null 2>&1; then
        xterm -T "$title" -e bash -lc "$command_text"
    else
        notify_error "No supported terminal emulator found. Install gnome-terminal, x-terminal-emulator, or xterm."
        return 1
    fi
}

helper_path() {
    local name=$1
    local source_file="$SCRIPT_DIR/$name.c"
    local source_binary="$SCRIPT_DIR/$name"
    local installed_binary="$LIBEXEC_DIR/$name"

    if [ -x "$installed_binary" ]; then
        printf '%s\n' "$installed_binary"
        return 0
    fi

    if [ -x "$source_binary" ]; then
        printf '%s\n' "$source_binary"
        return 0
    fi

    if [ -f "$source_file" ] && command -v gcc >/dev/null 2>&1; then
        if gcc -std=c11 -Wall -Wextra -pedantic -O2 "$source_file" -o "$source_binary"; then
            printf '%s\n' "$source_binary"
            return 0
        fi
    fi

    notify_error "Missing helper executable: $name. Run 'make' first, or reinstall the package."
    return 1
}

show_info() {
    local os kernel arch cpu ram disk

    os=$(uname -o 2>/dev/null || uname -s)
    kernel=$(uname -r)
    arch=$(uname -m)
    cpu=$(lscpu 2>/dev/null | awk -F':' '/Model name/ {print $2; exit}' | xargs)
    ram=$(free -h 2>/dev/null | awk '/Mem:/ {print $2; exit}')
    disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $4; exit}')

    notify_info "System Info" "OS: ${os:-Unknown}
Kernel: ${kernel:-Unknown}
Architecture: ${arch:-Unknown}
CPU: ${cpu:-Unknown}
RAM: ${ram:-Unknown}
Disk Free (/): ${disk:-Unknown}"
}

media_player() {
    local file player

    file=$(zenity --file-selection --title="Select media file") || return
    [ -n "$file" ] || return

    for player in mpv vlc; do
        if command -v "$player" >/dev/null 2>&1; then
            setsid "$player" "$file" >/dev/null 2>&1 &
            return
        fi
    done

    xdg-open "$file" >/dev/null 2>&1 || notify_error "Could not open media file."
}

file_search() {
    local pattern found

    pattern=$(zenity --entry --title="File Search" --text="Enter file name or pattern") || return
    [ -n "$pattern" ] || return

    found=$(find "$HOME" -iname "*${pattern}*" 2>/dev/null | head -n 50)
    zenity --text-info --title="File Search Results" --width=720 --height=420 \
        --filename=<(printf '%s\n' "${found:-No files found.}")
}

system_update() {
    if ! command -v apt >/dev/null 2>&1; then
        notify_error "System Update currently supports Debian/Ubuntu systems with apt."
        return 1
    fi

    run_in_terminal "System Update" "sudo apt update && sudo apt upgrade -y; echo; read -r -p 'Press Enter to close...'"
}

pdf_viewer() {
    local file

    file=$(zenity --file-selection --title="Select PDF" --file-filter="PDF files | *.pdf") || return
    [ -n "$file" ] || return

    xdg-open "$file" >/dev/null 2>&1 || notify_error "Could not open PDF file."
}

calculator() {
    local binary

    binary=$(helper_path calc_gui) || return
    "$binary"
}

process_manager() {
    local binary

    binary=$(helper_path proc_manager) || return
    "$binary"
}

scheduling_simulator() {
    local binary algo n bursts arrivals prios quantum input_file output_file error_text

    binary=$(helper_path sched_sim) || return

    algo=$(zenity --list --title="Process Scheduling" --column="Algorithm" \
        "FCFS" "SJF" "PRIORITY" "ROUND ROBIN") || return

    n=$(zenity --entry --title="Number of Processes" --text="Enter count (1-64)" --entry-text="4") || return
    [ -n "$n" ] || return

    bursts=$(zenity --entry --title="Burst Times (CSV)" --text="Example: 5,3,8,6") || return
    arrivals=$(zenity --entry --title="Arrival Times (CSV, optional)" --text="Leave empty for all 0" --entry-text="") || true

    prios=""
    quantum=1
    if [ "$algo" = "PRIORITY" ]; then
        prios=$(zenity --entry --title="Priorities (CSV)" --text="Lower number = higher priority. Example: 1,3,2,4") || return
    fi

    if [ "$algo" = "ROUND ROBIN" ]; then
        quantum=$(zenity --entry --title="Time Quantum" --text="Enter a positive integer quantum" --entry-text="2") || return
    fi

    input_file=$(mktemp "${TMPDIR:-/tmp}/unix-toolkit-sched-input.XXXXXX") || {
        notify_error "Could not create temporary scheduler input file."
        return 1
    }
    output_file=$(mktemp "${TMPDIR:-/tmp}/unix-toolkit-sched-output.XXXXXX") || {
        rm -f "$input_file"
        notify_error "Could not create temporary scheduler output file."
        return 1
    }

    {
        printf '%s\n' "$algo"
        printf '%s\n' "$n"
        printf '%s\n' "$bursts"
        printf '%s\n' "$arrivals"
        printf '%s\n' "$prios"
        printf '%s\n' "$quantum"
    } > "$input_file"

    if "$binary" --input "$input_file" --output "$output_file"; then
        zenity --text-info --width=820 --height=520 --title="Scheduling Results" --filename="$output_file"
    else
        error_text=$(cat "$output_file" 2>/dev/null)
        notify_error "${error_text:-Failed to run simulator. Check inputs.}"
    fi

    rm -f "$input_file" "$output_file"
}

service_manager() {
    local srv action

    if ! command -v systemctl >/dev/null 2>&1; then
        notify_error "systemctl is not available on this system."
        return 1
    fi

    srv=$(systemctl list-units --type=service --state=running --no-pager --plain | \
        awk '/\.service/ {print $1}' | head -n 80 | \
        zenity --list --title="Service Manager" --text="Select a running service to manage:" \
        --column="Service Name" --height=460 --width=560) || return

    [ -n "$srv" ] || return

    if [[ ! "$srv" =~ ^[A-Za-z0-9_.@:-]+\.service$ ]]; then
        notify_error "Invalid service name selected."
        return 1
    fi

    action=$(zenity --list --title="Action for $srv" --column="Action" \
        "Status" "Restart" "Stop" --height=250) || return

    case "$action" in
        "Status")
            run_in_terminal "Service Status" "systemctl status '$srv'; echo; read -r -p 'Press Enter to close...'"
            ;;
        "Restart")
            run_in_terminal "Restart Service" "sudo systemctl restart '$srv' && echo 'Restarted $srv' || echo 'Failed to restart $srv'; read -r -p 'Press Enter to close...'"
            ;;
        "Stop")
            run_in_terminal "Stop Service" "sudo systemctl stop '$srv' && echo 'Stopped $srv' || echo 'Failed to stop $srv'; read -r -p 'Press Enter to close...'"
            ;;
    esac
}

network_monitor() {
    run_in_terminal "Network Monitor" '
        set -u
        iface=$(ip route 2>/dev/null | awk "/^default/ {print \$5; exit}")
        if [ -z "${iface:-}" ]; then
            iface=$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf "%f\n" | grep -v "^lo$" | head -n 1)
        fi

        if [ -z "${iface:-}" ] || [ ! -r "/sys/class/net/$iface/statistics/rx_bytes" ]; then
            echo "No readable network interface found."
            read -r -p "Press Enter to close..."
            exit 1
        fi

        echo "Monitoring interface: $iface"
        echo "Press Ctrl+C to exit."
        echo

        while true; do
            rx1=$(cat "/sys/class/net/$iface/statistics/rx_bytes")
            tx1=$(cat "/sys/class/net/$iface/statistics/tx_bytes")
            sleep 1
            rx2=$(cat "/sys/class/net/$iface/statistics/rx_bytes")
            tx2=$(cat "/sys/class/net/$iface/statistics/tx_bytes")
            printf "\rDownload: %s KB/s  |  Upload: %s KB/s   " "$(((rx2 - rx1) / 1024))" "$(((tx2 - tx1) / 1024))"
        done
    '
}

main() {
    local tool

    ensure_zenity

    while true; do
        tool=$(zenity --list --title="$APP_NAME" \
            --width=720 --height=600 \
            --column="Tool" --column="Description" \
            "System Info" "View OS, CPU, RAM, and disk info" \
            "Media Player" "Play audio or video files" \
            "File Search" "Search files by name or pattern" \
            "System Update" "Update Debian/Ubuntu packages" \
            "PDF Viewer" "Open PDF files" \
            "Calculator" "Perform arithmetic operations" \
            "Process Manager" "View and terminate processes" \
            "Scheduling Simulator" "FCFS, SJF, Priority, and Round Robin" \
            "Service Manager" "Manage running systemd services" \
            "Network Monitor" "Monitor network throughput" \
            --ok-label="Run" --cancel-label="Exit") || break

        case "$tool" in
            "System Info") show_info ;;
            "Media Player") media_player ;;
            "File Search") file_search ;;
            "System Update") system_update ;;
            "PDF Viewer") pdf_viewer ;;
            "Calculator") calculator ;;
            "Process Manager") process_manager ;;
            "Scheduling Simulator") scheduling_simulator ;;
            "Service Manager") service_manager ;;
            "Network Monitor") network_monitor ;;
            *) break ;;
        esac
    done
}

main "$@"
