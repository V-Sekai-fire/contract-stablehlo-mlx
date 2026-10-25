#include <metal_stdlib>
#pragma METAL fp contract(off)
using namespace metal;
kernel void k(device float* y [[buffer(0)]], uint t [[thread_position_in_grid]]) { float p = y[t]*y[t+1]; y[t] = y[t+2] + p; }
