#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAX_PROCESSES 20

typedef struct {
    int pid;
    char pid_text[16];
    char command[128];
    char cpu[24];
    char memory[24];
} ProcessRow;

static void trim_newline(char *value) {
    value[strcspn(value, "\r\n")] = '\0';
}

static void show_static_dialog(const char *kind, const char *title, const char *message) {
    char command[512];

    snprintf(command, sizeof(command),
             "zenity --%s --title='%s' --width=420 --text='%s'",
             kind, title, message);
    if (system(command) == -1) {
        fprintf(stderr, "%s: %s\n", title, message);
    }
}

static int load_process_rows(ProcessRow rows[], int max_rows) {
    FILE *pipe;
    char line[512];
    int count = 0;

    pipe = popen("ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu", "r");
    if (pipe == NULL) {
        return -1;
    }

    while (count < max_rows && fgets(line, sizeof(line), pipe) != NULL) {
        int pid = 0;
        char command[128];
        char cpu[24];
        char memory[24];

        if (sscanf(line, "%d %127s %23s %23s", &pid, command, cpu, memory) != 4) {
            continue;
        }

        rows[count].pid = pid;
        snprintf(rows[count].pid_text, sizeof(rows[count].pid_text), "%d", pid);
        snprintf(rows[count].command, sizeof(rows[count].command), "%s", command);
        snprintf(rows[count].cpu, sizeof(rows[count].cpu), "%s", cpu);
        snprintf(rows[count].memory, sizeof(rows[count].memory), "%s", memory);
        count++;
    }

    pclose(pipe);
    return count;
}

static int run_zenity_list(const ProcessRow rows[], int row_count, char *selection, size_t selection_size) {
    int pipe_fds[2];
    pid_t child;
    ssize_t bytes_read;
    int status = 0;
    char *argv[12 + (MAX_PROCESSES * 4) + 1];
    int arg = 0;

    if (pipe(pipe_fds) != 0) {
        return -1;
    }

    child = fork();
    if (child < 0) {
        close(pipe_fds[0]);
        close(pipe_fds[1]);
        return -1;
    }

    if (child == 0) {
        close(pipe_fds[0]);
        dup2(pipe_fds[1], STDOUT_FILENO);
        close(pipe_fds[1]);

        argv[arg++] = "zenity";
        argv[arg++] = "--list";
        argv[arg++] = "--title=Process Manager";
        argv[arg++] = "--width=740";
        argv[arg++] = "--height=440";
        argv[arg++] = "--column=PID";
        argv[arg++] = "--column=Command";
        argv[arg++] = "--column=CPU %";
        argv[arg++] = "--column=Memory %";
        argv[arg++] = "--print-column=1";

        for (int i = 0; i < row_count; i++) {
            argv[arg++] = (char *)rows[i].pid_text;
            argv[arg++] = (char *)rows[i].command;
            argv[arg++] = (char *)rows[i].cpu;
            argv[arg++] = (char *)rows[i].memory;
        }

        argv[arg] = NULL;
        execvp("zenity", argv);
        _exit(127);
    }

    close(pipe_fds[1]);
    bytes_read = read(pipe_fds[0], selection, selection_size - 1);
    close(pipe_fds[0]);
    waitpid(child, &status, 0);

    if (bytes_read <= 0 || status != 0) {
        return 1;
    }

    selection[bytes_read] = '\0';
    trim_newline(selection);
    return selection[0] == '\0' ? 1 : 0;
}

static int confirm_termination(const char *pid_text) {
    char command[256];

    snprintf(command, sizeof(command),
             "zenity --question --title='Confirm Process Termination' --width=420 --text='Terminate process PID %s?'",
             pid_text);
    return system(command) == 0;
}

int main(void) {
    ProcessRow rows[MAX_PROCESSES];
    char selection[32];
    int row_count;
    int selected_pid;

    row_count = load_process_rows(rows, MAX_PROCESSES);
    if (row_count < 0) {
        show_static_dialog("error", "Process Manager", "Could not read process list.");
        return 1;
    }

    if (row_count == 0) {
        show_static_dialog("info", "Process Manager", "No processes found.");
        return 0;
    }

    if (run_zenity_list(rows, row_count, selection, sizeof(selection)) != 0) {
        return 0;
    }

    selected_pid = atoi(selection);
    if (selected_pid <= 1) {
        show_static_dialog("error", "Process Manager", "Refusing to terminate this process.");
        return 1;
    }

    if (!confirm_termination(selection)) {
        return 0;
    }

    if (kill(selected_pid, SIGTERM) == 0) {
        show_static_dialog("info", "Process Manager", "Termination signal sent.");
        return 0;
    }

    if (errno == EPERM) {
        show_static_dialog("error", "Process Manager", "Permission denied. Try running with appropriate privileges.");
    } else if (errno == ESRCH) {
        show_static_dialog("error", "Process Manager", "Process no longer exists.");
    } else {
        show_static_dialog("error", "Process Manager", "Failed to terminate process.");
    }

    return 1;
}
