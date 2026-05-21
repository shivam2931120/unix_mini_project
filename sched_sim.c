#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#define MAXN 64
#define GANTT_SIZE 16384

typedef struct {
    int pid;
    int arrival;
    int burst;
    int priority;
    int completion;
    int waiting;
    int turnaround;
    int remaining;
} Process;

static int cmp_arrival(const void *a, const void *b) {
    const Process *left = a;
    const Process *right = b;

    if (left->arrival != right->arrival) {
        return left->arrival - right->arrival;
    }

    return left->pid - right->pid;
}

static int cmp_pid(const void *a, const void *b) {
    const Process *left = a;
    const Process *right = b;

    return left->pid - right->pid;
}

static int is_round_robin(const char *algo) {
    return strcasecmp(algo, "ROUND ROBIN") == 0 || strcasecmp(algo, "RR") == 0;
}

static void trim_newline(char *value) {
    value[strcspn(value, "\r\n")] = '\0';
}

static int write_error(const char *output_path, const char *format, ...) {
    FILE *output = fopen(output_path, "w");
    va_list args;

    if (output == NULL) {
        output = stderr;
    }

    fprintf(output, "Error: ");
    va_start(args, format);
    vfprintf(output, format, args);
    va_end(args);
    fprintf(output, "\n");

    if (output != stderr) {
        fclose(output);
    }

    return 1;
}

static int parse_csv_ints(const char *text, int values[], int expected_count) {
    const char *cursor = text;
    int count = 0;

    while (*cursor != '\0') {
        char *end = NULL;
        long parsed;

        while (*cursor == ' ' || *cursor == '\t') {
            cursor++;
        }

        if (*cursor == '\0') {
            break;
        }

        errno = 0;
        parsed = strtol(cursor, &end, 10);
        if (cursor == end || errno == ERANGE || parsed < INT_MIN || parsed > INT_MAX) {
            return -1;
        }

        if (count >= expected_count) {
            return -1;
        }

        values[count++] = (int)parsed;
        cursor = end;

        while (*cursor == ' ' || *cursor == '\t') {
            cursor++;
        }

        if (*cursor == ',') {
            cursor++;
        } else if (*cursor != '\0') {
            return -1;
        }
    }

    return count == expected_count ? 0 : -1;
}

static int append_gantt(char gantt[], size_t size, int time, int pid) {
    size_t length = strlen(gantt);
    int written;

    if (length >= size) {
        return -1;
    }

    written = snprintf(gantt + length, size - length, "| t=%d P%d ", time, pid);
    if (written < 0 || (size_t)written >= size - length) {
        return -1;
    }

    return 0;
}

static int next_arrival_after_time(const Process processes[], int count, const int completed[], int time) {
    int next = INT_MAX;

    for (int i = 0; i < count; i++) {
        if (!completed[i] && processes[i].arrival > time && processes[i].arrival < next) {
            next = processes[i].arrival;
        }
    }

    return next == INT_MAX ? time + 1 : next;
}

static void calculate_metrics(Process *process, int completion_time) {
    process->completion = completion_time;
    process->turnaround = process->completion - process->arrival;
    process->waiting = process->turnaround - process->burst;
}

static int simulate_fcfs(Process processes[], int count, char gantt[], size_t gantt_size, int *finish_time) {
    int time = 0;

    qsort(processes, (size_t)count, sizeof(Process), cmp_arrival);

    for (int i = 0; i < count; i++) {
        if (time < processes[i].arrival) {
            time = processes[i].arrival;
        }

        if (append_gantt(gantt, gantt_size, time, processes[i].pid) != 0) {
            return -1;
        }

        time += processes[i].burst;
        calculate_metrics(&processes[i], time);
    }

    *finish_time = time;
    return 0;
}

static int simulate_sjf(Process processes[], int count, char gantt[], size_t gantt_size, int *finish_time) {
    int completed[MAXN] = {0};
    int done_count = 0;
    int time = 0;

    while (done_count < count) {
        int selected = -1;

        for (int i = 0; i < count; i++) {
            if (completed[i] || processes[i].arrival > time) {
                continue;
            }

            if (selected == -1 ||
                processes[i].burst < processes[selected].burst ||
                (processes[i].burst == processes[selected].burst && processes[i].arrival < processes[selected].arrival) ||
                (processes[i].burst == processes[selected].burst && processes[i].arrival == processes[selected].arrival &&
                 processes[i].pid < processes[selected].pid)) {
                selected = i;
            }
        }

        if (selected == -1) {
            time = next_arrival_after_time(processes, count, completed, time);
            continue;
        }

        if (append_gantt(gantt, gantt_size, time, processes[selected].pid) != 0) {
            return -1;
        }

        time += processes[selected].burst;
        calculate_metrics(&processes[selected], time);
        completed[selected] = 1;
        done_count++;
    }

    *finish_time = time;
    return 0;
}

static int simulate_priority(Process processes[], int count, char gantt[], size_t gantt_size, int *finish_time) {
    int completed[MAXN] = {0};
    int done_count = 0;
    int time = 0;

    while (done_count < count) {
        int selected = -1;

        for (int i = 0; i < count; i++) {
            if (completed[i] || processes[i].arrival > time) {
                continue;
            }

            if (selected == -1 ||
                processes[i].priority < processes[selected].priority ||
                (processes[i].priority == processes[selected].priority &&
                 processes[i].arrival < processes[selected].arrival) ||
                (processes[i].priority == processes[selected].priority &&
                 processes[i].arrival == processes[selected].arrival &&
                 processes[i].pid < processes[selected].pid)) {
                selected = i;
            }
        }

        if (selected == -1) {
            time = next_arrival_after_time(processes, count, completed, time);
            continue;
        }

        if (append_gantt(gantt, gantt_size, time, processes[selected].pid) != 0) {
            return -1;
        }

        time += processes[selected].burst;
        calculate_metrics(&processes[selected], time);
        completed[selected] = 1;
        done_count++;
    }

    *finish_time = time;
    return 0;
}

static int simulate_round_robin(Process processes[], int count, int quantum, char gantt[], size_t gantt_size,
                                int *finish_time) {
    int left = count;
    int time = processes[0].arrival;

    for (int i = 1; i < count; i++) {
        if (processes[i].arrival < time) {
            time = processes[i].arrival;
        }
    }

    while (left > 0) {
        int progressed = 0;

        for (int i = 0; i < count; i++) {
            int run_time;

            if (processes[i].remaining <= 0 || processes[i].arrival > time) {
                continue;
            }

            run_time = processes[i].remaining < quantum ? processes[i].remaining : quantum;
            if (append_gantt(gantt, gantt_size, time, processes[i].pid) != 0) {
                return -1;
            }

            time += run_time;
            processes[i].remaining -= run_time;
            progressed = 1;

            if (processes[i].remaining == 0) {
                calculate_metrics(&processes[i], time);
                left--;
            }
        }

        if (!progressed) {
            int next_time = INT_MAX;

            for (int i = 0; i < count; i++) {
                if (processes[i].remaining > 0 && processes[i].arrival > time && processes[i].arrival < next_time) {
                    next_time = processes[i].arrival;
                }
            }

            time = next_time == INT_MAX ? time + 1 : next_time;
        }
    }

    *finish_time = time;
    return 0;
}

static int write_results(const char *output_path, const char *algo, Process processes[], int count,
                         const char *gantt, int finish_time) {
    FILE *output = fopen(output_path, "w");
    double total_waiting = 0.0;
    double total_turnaround = 0.0;

    if (output == NULL) {
        return 1;
    }

    qsort(processes, (size_t)count, sizeof(Process), cmp_pid);

    fprintf(output, "Algorithm: %s\n\n", algo);
    fprintf(output, "%-6s %-8s %-8s %-9s %-12s %-10s\n",
            "PID", "Arrival", "Burst", "Priority", "Waiting", "Turnaround");

    for (int i = 0; i < count; i++) {
        total_waiting += processes[i].waiting;
        total_turnaround += processes[i].turnaround;
        fprintf(output, "P%-5d %-8d %-8d %-9d %-12d %-10d\n",
                processes[i].pid, processes[i].arrival, processes[i].burst, processes[i].priority,
                processes[i].waiting, processes[i].turnaround);
    }

    fprintf(output, "\nAverage Waiting Time: %.2f\n", total_waiting / count);
    fprintf(output, "Average Turnaround Time: %.2f\n", total_turnaround / count);
    fprintf(output, "\nGantt: %s| t=%d |\n", gantt, finish_time);
    fclose(output);

    return 0;
}

int main(int argc, char *argv[]) {
    const char *input_path = getenv("SCHED_INPUT");
    const char *output_path = getenv("SCHED_OUTPUT");
    FILE *input;
    char algo[32] = "FCFS";
    char bursts_text[4096] = "";
    char arrivals_text[4096] = "";
    char priorities_text[4096] = "";
    char gantt[GANTT_SIZE] = "";
    int n = 0;
    int quantum = 1;
    int bursts[MAXN] = {0};
    int arrivals[MAXN] = {0};
    int priorities[MAXN] = {0};
    Process processes[MAXN] = {0};
    int have_arrivals;
    int have_priorities;
    int finish_time = 0;
    int simulation_status = 0;

    if (input_path == NULL || input_path[0] == '\0') {
        input_path = "/tmp/sched_input.txt";
    }

    if (output_path == NULL || output_path[0] == '\0') {
        output_path = "/tmp/sched_out.txt";
    }

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--input") == 0 && i + 1 < argc) {
            input_path = argv[++i];
        } else if (strcmp(argv[i], "--output") == 0 && i + 1 < argc) {
            output_path = argv[++i];
        } else {
            return write_error(output_path, "Usage: %s [--input FILE] [--output FILE]", argv[0]);
        }
    }

    input = fopen(input_path, "r");
    if (input == NULL) {
        return write_error(output_path, "Could not open input file.");
    }

    if (fgets(algo, sizeof(algo), input) == NULL ||
        fscanf(input, "%d\n", &n) != 1 ||
        fgets(bursts_text, sizeof(bursts_text), input) == NULL ||
        fgets(arrivals_text, sizeof(arrivals_text), input) == NULL ||
        fgets(priorities_text, sizeof(priorities_text), input) == NULL ||
        fscanf(input, "%d", &quantum) != 1) {
        fclose(input);
        return write_error(output_path, "Input file is incomplete or malformed.");
    }

    fclose(input);

    trim_newline(algo);
    trim_newline(bursts_text);
    trim_newline(arrivals_text);
    trim_newline(priorities_text);

    if (n <= 0 || n > MAXN) {
        return write_error(output_path, "Process count must be between 1 and %d.", MAXN);
    }

    if (parse_csv_ints(bursts_text, bursts, n) != 0) {
        return write_error(output_path, "Burst times must contain exactly %d comma-separated integers.", n);
    }

    have_arrivals = arrivals_text[0] != '\0';
    if (have_arrivals && parse_csv_ints(arrivals_text, arrivals, n) != 0) {
        return write_error(output_path, "Arrival times must contain exactly %d comma-separated integers.", n);
    }

    have_priorities = priorities_text[0] != '\0';
    if (strcasecmp(algo, "PRIORITY") == 0 && !have_priorities) {
        return write_error(output_path, "Priority scheduling requires %d priority values.", n);
    }

    if (have_priorities && parse_csv_ints(priorities_text, priorities, n) != 0) {
        return write_error(output_path, "Priorities must contain exactly %d comma-separated integers.", n);
    }

    if (is_round_robin(algo) && quantum <= 0) {
        return write_error(output_path, "Round Robin quantum must be a positive integer.");
    }

    for (int i = 0; i < n; i++) {
        if (bursts[i] <= 0) {
            return write_error(output_path, "Burst times must be positive integers.");
        }

        if (arrivals[i] < 0) {
            return write_error(output_path, "Arrival times cannot be negative.");
        }

        processes[i].pid = i + 1;
        processes[i].arrival = have_arrivals ? arrivals[i] : 0;
        processes[i].burst = bursts[i];
        processes[i].priority = have_priorities ? priorities[i] : 0;
        processes[i].remaining = bursts[i];
    }

    if (strcasecmp(algo, "FCFS") == 0) {
        simulation_status = simulate_fcfs(processes, n, gantt, sizeof(gantt), &finish_time);
    } else if (strcasecmp(algo, "SJF") == 0) {
        simulation_status = simulate_sjf(processes, n, gantt, sizeof(gantt), &finish_time);
    } else if (strcasecmp(algo, "PRIORITY") == 0) {
        simulation_status = simulate_priority(processes, n, gantt, sizeof(gantt), &finish_time);
    } else if (is_round_robin(algo)) {
        simulation_status = simulate_round_robin(processes, n, quantum, gantt, sizeof(gantt), &finish_time);
    } else {
        return write_error(output_path, "Unknown scheduling algorithm: %s.", algo);
    }

    if (simulation_status != 0) {
        return write_error(output_path, "Gantt chart is too large for the selected inputs.");
    }

    if (write_results(output_path, algo, processes, n, gantt, finish_time) != 0) {
        return write_error(output_path, "Could not write output file.");
    }

    return 0;
}
