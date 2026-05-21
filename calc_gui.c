#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void trim_newline(char *value) {
    value[strcspn(value, "\r\n")] = '\0';
}

static int read_zenity_value(const char *command, char *buffer, size_t buffer_size) {
    FILE *pipe = popen(command, "r");
    int status;

    if (pipe == NULL) {
        return -1;
    }

    if (fgets(buffer, (int)buffer_size, pipe) == NULL) {
        status = pclose(pipe);
        (void)status;
        return -1;
    }

    status = pclose(pipe);
    trim_newline(buffer);

    return status == 0 ? 0 : -1;
}

static int parse_number(const char *text, double *value) {
    char *end = NULL;

    errno = 0;
    *value = strtod(text, &end);

    if (text == end || errno == ERANGE) {
        return -1;
    }

    while (*end != '\0') {
        if (!isspace((unsigned char)*end)) {
            return -1;
        }
        end++;
    }

    return 0;
}

static void show_error(const char *message) {
    char command[512];

    snprintf(command, sizeof(command),
             "zenity --error --title='Calculator' --width=360 --text='%s'",
             message);
    if (system(command) == -1) {
        fprintf(stderr, "%s\n", message);
    }
}

int main(void) {
    char first_text[64];
    char second_text[64];
    char op[8];
    char command[256];
    double first;
    double second;
    double result = 0.0;

    if (read_zenity_value("zenity --entry --title='Calculator' --text='Enter first number:'",
                          first_text, sizeof(first_text)) != 0) {
        return 0;
    }

    if (parse_number(first_text, &first) != 0) {
        show_error("Invalid first number.");
        return 1;
    }

    if (read_zenity_value("zenity --list --title='Select Operation' --column='Operator' '+' '-' '*' '/'",
                          op, sizeof(op)) != 0) {
        return 0;
    }

    if (read_zenity_value("zenity --entry --title='Calculator' --text='Enter second number:'",
                          second_text, sizeof(second_text)) != 0) {
        return 0;
    }

    if (parse_number(second_text, &second) != 0) {
        show_error("Invalid second number.");
        return 1;
    }

    switch (op[0]) {
        case '+':
            result = first + second;
            break;
        case '-':
            result = first - second;
            break;
        case '*':
            result = first * second;
            break;
        case '/':
            if (second == 0.0) {
                show_error("Division by zero is not allowed.");
                return 1;
            }
            result = first / second;
            break;
        default:
            show_error("Invalid operation.");
            return 1;
    }

    snprintf(command, sizeof(command),
             "zenity --info --title='Calculator Result' --width=360 --text='Result: %.10g'",
             result);
    if (system(command) == -1) {
        fprintf(stderr, "Result: %.10g\n", result);
    }

    return 0;
}
