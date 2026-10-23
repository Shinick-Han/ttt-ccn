#include <stdio.h>

int process(int x) {
    if (x > 0) {
        for (int i = 0; i < x; i++) {
            if (i % 2 == 0) printf("%d\n", i);
        }
    }
    return x;
}

int simple(int x) { return x + 1; }

int main(void) {
    return process(4) + simple(1);
}
