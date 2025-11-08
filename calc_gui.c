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
