#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 3 "t.slang"
ulong addu_0(ulong a_0, ulong b_0)
{

#line 3
    return a_0 + b_0;
}


#line 4
float f_0(float a_1, float b_1, float c_0)
{

#line 4
    precise float t_0 = a_1 * b_1;

#line 4
    precise float r_0 = t_0 + c_0;

#line 4
    return r_0 + fma(a_1, b_1, c_0) + (as_type<float>(((as_type<uint>((a_1))) ^ 2147483648U))) + float((addu_0(ulong((as_type<uint>((b_1)))), 3ULL)) >> 1U);
}


#line 6
struct KernelContext_0
{
    float device* y_0;
    float device* x_0;
};


#line 6
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], float device* y_1 [[buffer(1)]], float device* x_1 [[buffer(0)]])
{

#line 6
    thread KernelContext_0 kernelContext_0;

#line 6
    (&kernelContext_0)->y_0 = y_1;

#line 6
    (&kernelContext_0)->x_0 = x_1;

#line 6
    uint i_0 = tid_0.x;

#line 6
    *(y_1+i_0) = f_0(x_1[i_0], x_1[i_0 + 1U], 1.0f);

#line 6
    return;
}

