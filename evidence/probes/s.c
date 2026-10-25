#include <Accelerate/Accelerate.h>
int main(){ float x[64]={1}; float s; vDSP_sve(x,1,&s,64); vDSP_measqv(x,1,&s,64); return (int)s; }
