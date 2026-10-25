#include <math.h>
#include <stdio.h>
int main(int c, char**v){ volatile float x=0.3f; printf("%a %a\n", erff(x), expf(x)); return 0;}
