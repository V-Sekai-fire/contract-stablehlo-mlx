#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 10920 "hlsl.meta.slang"
uint firstbithigh_0(uint value_0)
{

#line 10933
    if(value_0 == 0U)
    {

#line 10934
        return 4294967295U;
    }

#line 10935
    uint _S1 = clz(value_0);

#line 10935
    return 31U - _S1;
}


#line 50 "kernels/slang/f64_of_f32.slang"
ulong f64_from_f32_0(float x_0)
{

#line 51
    uint b_0 = (as_type<uint>((x_0)));
    ulong s_0 = ulong(b_0 >> 31U);
    uint e_0 = (b_0 >> 23U) & 255U;
    uint f_0 = b_0 & 8388607U;
    if(e_0 == 255U)
    {

#line 56
        return ((s_0 << 63ULL) | 9218868437227405312ULL) | (ulong(f_0) << 29ULL);
    }
    if(e_0 == 0U)
    {

#line 59
        if(f_0 == 0U)
        {

#line 60
            return s_0 << 63ULL;
        }
        uint p_0 = firstbithigh_0(f_0);
        return ((s_0 << 63ULL) | (ulong(p_0 + 874U) << 52ULL)) | ((ulong(f_0) << ulong(52U - p_0)) & 4503599627370495ULL);
    }
    return ((s_0 << 63ULL) | (ulong(e_0 + 896U) << 52ULL)) | (ulong(f_0) << 29ULL);
}


#line 468
struct KernelContext_0
{
    uint device* p_1;
    ulong device* y_0;
    float device* a_0;
};


#line 463
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_2 [[buffer(1)]], ulong device* y_1 [[buffer(2)]], float device* a_1 [[buffer(0)]])
{

#line 463
    thread KernelContext_0 kernelContext_0;

#line 463
    (&kernelContext_0)->p_1 = p_2;

#line 463
    (&kernelContext_0)->y_0 = y_1;

#line 463
    (&kernelContext_0)->a_0 = a_1;
    uint t_0 = tid_0.x;
    if(t_0 >= p_2[0U])
    {

#line 466
        return;
    }
    *((&kernelContext_0)->y_0+t_0) = f64_from_f32_0((&kernelContext_0)->a_0[t_0]);
    return;
}

