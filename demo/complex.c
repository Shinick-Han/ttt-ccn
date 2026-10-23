#include <stdio.h>

int classify(int x, int y, int z) {
    int score = 0;
    if (x > 0) {
        for (int i = 0; i < x; i++) {
            if (i % 2 == 0) {
                if (y > 0) score += 1;
                else if (y < 0) score -= 1;
                else score += 2;
            } else if (i % 3 == 0) {
                if (z > 0) score += 3;
                else if (z < 0) score -= 3;
                else score += 4;
            }
        }
    } else if (x < 0) {
        while (y > 0) {
            if (z > 0) { score++; y--; }
            else if (z < 0) { score--; y++; }
            else { score += 2; break; }
        }
    } else {
        switch (z) {
        case 0: score = 1; break;
        case 1: score = 2; break;
        case 2: score = 3; break;
        default: score = 4;
        }
    }
    if (score > 10 && x > 1 && y > 1 && z > 1) return score * 2;
    return score;
}

int main(void) {
    printf("%d\n", classify(3, -1, 2));
    return 0;
}
