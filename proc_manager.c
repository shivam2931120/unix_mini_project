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
