StructuredBuffer<float> x;
RWStructuredBuffer<float> y;
uint64_t addu(uint64_t a, uint64_t b) { return a + b; }
float f(float a, float b, float c) { precise float t = a * b; precise float r = t + c; return r + fma(a, b, c) + asfloat(asuint(a) ^ 0x80000000u) + float(addu(uint64_t(asuint(b)), 3ull) >> 1); }
[shader("compute")] [numthreads(64,1,1)]
void main(uint3 tid : SV_DispatchThreadID) { uint i = tid.x; y[i] = f(x[i], x[i+1u], 1.0); }
