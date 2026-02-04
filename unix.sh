#!/bin/bash

show_info() {
    zenity --info --title="🖥️ System Info" --width=550 --height=350 \
        --text="<span font='12'>OS: $(uname -o)\nKernel: $(uname -r)\nArch: $(uname -m)\nCPU: $(lscpu | awk -F':' '/Model name/ {print \$2}' | xargs)\nRAM: $(free -h | awk '/Mem/{print \$2}')\nDisk Free (/): $(df -h / | awk 'NR==2{print \$4}')</span>"
}

media_player() {
    file=$(zenity --file-selection --title="🎵🎬 Select media file") || return
    [ -z "$file" ] && return
    for p in mpv vlc; do
        command -v $p >/dev/null && exec $p "$file"
    done
    xdg-open "$file"
}

file_search() {
    pattern=$(zenity --entry --title="🔎 File Search" --text="Enter file name or pattern")
    [ -n "$pattern" ] || return
    found=$(find ~ -iname "*$pattern*" 2>/dev/null | head -20)
    zenity --info --title="🔎 File Search Results" --text="${found:-No files found.}"
}

system_update() {
    gnome-terminal -- bash -c 'sudo apt update && sudo apt upgrade -y; exec bash'
}

pdf_viewer() {
    file=$(zenity --file-selection --title="📄 Select PDF" --file-filter="*.pdf")
    [ -n "$file" ] && xdg-open "$file"
}

#calculator
if [ ! -f ./calc_gui ]; then
    cat > calc_gui.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>

int main() {
    char a_str[32], b_str[32], op[4], command[256];
    double a, b, result;
    int valid = 1;

    system("zenity --entry --title='🧮 Calculator' --text='Enter first number:' > /tmp/a.txt");
    FILE *fa = fopen("/tmp/a.txt", "r");
    if (!fa) return 1;
    fscanf(fa, "%31s", a_str);
    fclose(fa);
    a = atof(a_str);

    system("zenity --list --title='Select Operation' --column='Operator' '+' '-' '*' '/' > /tmp/op.txt");
    FILE *fo = fopen("/tmp/op.txt", "r");
    if (!fo) return 1;
    fscanf(fo, "%3s", op);
    fclose(fo);

    system("zenity --entry --title='🧮 Calculator' --text='Enter second number:' > /tmp/b.txt");
    FILE *fb = fopen("/tmp/b.txt", "r");
    if (!fb) return 1;
    fscanf(fb, "%31s", b_str);
    fclose(fb);
    b = atof(b_str);

    if (op[0] == '+') result = a + b;
    else if (op[0] == '-') result = a - b;
    else if (op[0] == '*') result = a * b;
    else if (op[0] == '/') {
        if (b != 0) result = a / b;
        else { valid = 0; system("zenity --error --text='Division by zero is not allowed!'"); }
    } else valid = 0;

    if (valid) {
        snprintf(command, sizeof(command),
                 "zenity --info --title='🧮 Result' --text='Result: %.2f'", result);
        system(command);
    }
    return 0;
}
EOF
    gcc calc_gui.c -o calc_gui 2>/dev/null
fi

calculator() { ./calc_gui; }

#process manager
if [ ! -f ./proc_manager ]; then
    cat > proc_manager.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>

int main() {
    system("ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -15 > /tmp/proc_list.txt");
    system("zenity --list --title='⚙️ Process Manager' --width=700 --height=420 "
           "--column='PID' --column='Command' --column='CPU %' --column='Memory %' "
           "--print-column=1 --separator=' ' $(awk 'NR>1{print $1\" \"$2\" \"$3\" \"$4}' /tmp/proc_list.txt) > /tmp/killpid.txt");

    FILE *fp = fopen("/tmp/killpid.txt", "r");
    if (!fp) return 0;
    int pid;
    if (fscanf(fp, "%d", &pid) == 1) {
        char cmd[64];
        snprintf(cmd, sizeof(cmd), "kill -9 %d", pid);
        int r = system(cmd);
        if (r == 0) system("zenity --info --text='✅ Process terminated successfully!'");
        else system("zenity --error --text='❌ Failed to terminate process.'");
    }
    fclose(fp);
    return 0;
}
EOF
    gcc proc_manager.c -o proc_manager 2>/dev/null
fi

process_manager() { ./proc_manager; }

#scheduling simulator
scheduling_simulator() {
    algo=$(zenity --list --title="🧪 Process Scheduling" --column="Algorithm" \
           "FCFS" "SJF" "PRIORITY" "ROUND ROBIN") || return

    n=$(zenity --entry --title="Number of Processes" --text="Enter count (1-64)" --entry-text="4") || return
    [ -z "$n" ] && return

    bursts=$(zenity --entry --title="Burst Times (CSV)" --text="e.g., 5,3,8,6") || return
    arrivals=$(zenity --entry --title="Arrival Times (CSV, optional)" --text="Leave empty for all 0" --entry-text="") || true

    prios=""
    quantum=1
    if [ "$algo" = "PRIORITY" ]; then
        prios=$(zenity --entry --title="Priorities (CSV)" --text="Lower number = higher priority (e.g., 1,3,2,4)") || return
    fi
    if [ "$algo" = "ROUND ROBIN" ]; then
        quantum=$(zenity --entry --title="Time Quantum" --text="Enter quantum (positive integer)" --entry-text="2") || return
    fi

    {
        echo "$algo"
        echo "$n"
        echo "$bursts"
        echo "$arrivals"
        echo "$prios"
        echo "$quantum"
    } > /tmp/sched_input.txt

    ./sched_sim
    if [ -f /tmp/sched_out.txt ]; then
        zenity --text-info --width=820 --height=520 \
            --title="🧪 Scheduling Results" --filename=/tmp/sched_out.txt
    else
        zenity --error --text="Failed to run simulator. Check inputs."
    fi
}


service_manager() {
    # Get list of active services
    srv=$(systemctl list-units --type=service --state=running --no-pager --plain | \
          awk '{print $1}' | grep ".service" | head -n 50 | \
          zenity --list --title="📦 Service Manager" --text="Select a running service to manage:" \
          --column="Service Name" --height=400 --width=500)
    
    [ -z "$srv" ] && return
    
    action=$(zenity --list --title="Action for $srv" --column="Action" \
             "Status" "Restart" "Stop" --height=250)
    
    [ -z "$action" ] && return
    
    case "$action" in
        "Status") 
            gnome-terminal -- bash -c "systemctl status $srv; echo; read -p 'Press Enter to exit...'" ;;
        "Restart") 
            gnome-terminal -- bash -c "sudo systemctl restart $srv && echo '✅ Restarted $srv' || echo '❌ Failed'; read -p 'Press Enter...'" ;;
        "Stop") 
            gnome-terminal -- bash -c "sudo systemctl stop $srv && echo '✅ Stopped $srv' || echo '❌ Failed'; read -p 'Press Enter...'" ;;
    esac
}

network_monitor() {
    gnome-terminal --title="📊 Network Monitor" -- bash -c '
        echo "Monitoring Network Interface (Active)..."
        # Find primary interface
        IFACE=$(ip route | awk "/^default/ {print \$5}" | head -1)
        [ -z "$IFACE" ] && IFACE=$(ls /sys/class/net | head -1)
        
        echo "Interface: $IFACE"
        echo "Press Ctrl+C to exit."
        echo ""
        
        while true; do
            R1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
            T1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
            sleep 1
            R2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
            T2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
            
            RKB=$(( (R2 - R1) / 1024 ))
            TKB=$(( (T2 - T1) / 1024 ))
            
            echo -ne "\r⬇ Download: ${RKB} KB/s  |  ⬆ Upload: ${TKB} KB/s   "
        done
    '
}


#menu
while true; do
    tool=$(zenity --list --title="🛠️ Linux Utility Toolkit" \
        --width=720 --height=600 \
        --column="Tool" --column="Description" \
        "System Info" "🖥️ View OS, CPU, RAM, disk info" \
        "Media Player" "🎵🎬 Play audio/video files" \
        "File Search" "🔎 Search files by name/pattern" \
        "System Update" "⬆️ Update system packages" \
        "PDF Viewer" "📄 View PDF files" \
        "Calculator" "🧮 Perform arithmetic operations" \
        "Process Manager" "⚙️ View & kill processes" \
        "Scheduling Simulator" "🧪 FCFS / SJF / Priority / RR" \
        "Service Manager" "📦 Manage system services" \
        "Network Monitor" "📊 Monitor data usage" \
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

echo -e "\nThank you for using the Linux Utility Toolkit! Goodbye!"

