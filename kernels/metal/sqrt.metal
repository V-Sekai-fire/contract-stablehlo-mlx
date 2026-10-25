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


#line 8 "kernels/slang/sqrt.slang"
int hibit64_0(ulong x_0)
{

#line 9
    uint hi_0 = uint(x_0 >> 32ULL);
    if(hi_0 != 0U)
    {

#line 11
        return int(firstbithigh_0(hi_0)) + int(32);
    }
    return int(firstbithigh_0(uint(x_0 & 4294967295ULL)));
}


#line 306
float f32_sqrt_0(float x_1)
{

#line 307
    uint b_0 = (as_type<uint>((x_1)));
    if((b_0 & 2147483647U) == 0U)
    {

#line 309
        return x_1;
    }
    if((b_0 >> 31U) != 0U)
    {

#line 312
        return (as_type<float>((2143289344U)));
    }
    if(b_0 >= 2139095040U)
    {

#line 315
        return x_1;
    }
    int e_0 = int(b_0 >> 23U);
    uint m_0 = b_0 & 8388607U;

#line 318
    int e_1;

#line 318
    uint m_1;
    if(e_0 == int(0))
    {
        int _S2 = int(23) - int(firstbithigh_0(m_0));

#line 321
        uint _S3 = m_0 << uint(_S2);

#line 321
        e_1 = int(1) - _S2;

#line 321
        m_1 = _S3;

#line 319
    }
    else
    {


        uint _S4 = m_0 | 8388608U;

#line 324
        e_1 = e_0;

#line 324
        m_1 = _S4;

#line 319
    }

#line 326
    int k_0 = e_1 - int(150);
    ulong w_0 = ulong(m_1);

#line 327
    int k_1;

#line 327
    ulong w_1;
    if((k_0 & int(1)) != int(0))
    {
        int _S5 = k_0 - int(1);

#line 330
        w_1 = w_0 << 1ULL;

#line 330
        k_1 = _S5;

#line 328
    }
    else
    {

#line 328
        w_1 = w_0;

#line 328
        k_1 = k_0;

#line 328
    }



    ulong _S6 = w_1 << 38ULL;
    int k_2 = k_1 - int(38);

#line 333
    ulong rem_0 = 0ULL;

#line 333
    w_1 = _S6;

#line 333
    ulong r_0 = 0ULL;

#line 333
    uint i_0 = 0U;


    for(;;)
    {

#line 336
        if(i_0 < 32U)
        {
        }
        else
        {

#line 336
            break;
        }

#line 337
        ulong rem_1 = (rem_0 << 2ULL) | ((w_1 >> 62ULL) & 3ULL);
        ulong _S7 = w_1 << 2ULL;
        ulong t_0 = (r_0 << 2ULL) | 1ULL;
        ulong r_1 = r_0 << 1ULL;
        if(rem_1 >= t_0)
        {
            ulong _S8 = r_1 | 1ULL;

#line 343
            rem_0 = rem_1 - t_0;

#line 343
            r_0 = _S8;

#line 341
        }
        else
        {

#line 341
            rem_0 = rem_1;

#line 341
            r_0 = r_1;

#line 341
        }

#line 336
        uint i_1 = i_0 + 1U;

#line 336
        w_1 = _S7;

#line 336
        i_0 = i_1;

#line 336
    }

#line 347
    int sh_0 = hibit64_0(r_0) - int(23);
    ulong _S9 = ulong(sh_0);

#line 348
    ulong q_0 = r_0 >> _S9;
    ulong lost_0 = r_0 & ((1ULL << _S9) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - int(1));

#line 350
    bool sticky_0;
    if(rem_0 != 0ULL)
    {

#line 351
        sticky_0 = true;

#line 351
    }
    else
    {

#line 351
        sticky_0 = (lost_0 & (half_0 - 1ULL)) != 0ULL;

#line 351
    }
    if((lost_0 & half_0) != 0ULL)
    {

#line 352
        if(sticky_0)
        {

#line 352
            sticky_0 = true;

#line 352
        }
        else
        {

#line 352
            sticky_0 = (q_0 & 1ULL) != 0ULL;

#line 352
        }

#line 352
    }
    else
    {

#line 352
        sticky_0 = false;

#line 352
    }

#line 352
    ulong q_1;

#line 352
    if(sticky_0)
    {

#line 352
        q_1 = q_0 + 1ULL;

#line 352
    }
    else
    {

#line 352
        q_1 = q_0;

#line 352
    }


    int ee_0 = k_2 / int(2) + sh_0 + int(150);

#line 355
    int ee_1;
    if((q_1 >> 24ULL) != 0ULL)
    {

#line 357
        ulong _S10 = q_1 >> 1ULL;

#line 357
        ee_1 = ee_0 + int(1);

#line 357
        q_1 = _S10;

#line 356
    }
    else
    {

#line 356
        ee_1 = ee_0;

#line 356
    }



    return (as_type<float>(((uint(ee_1) << 23U) | uint(q_1 & 8388607ULL))));
}


#line 394
struct KernelContext_0
{
    uint device* p_0;
    float device* y_0;
    float device* a_0;
};


#line 389
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_1 [[buffer(1)]], float device* y_1 [[buffer(2)]], float device* a_1 [[buffer(0)]])
{

#line 389
    thread KernelContext_0 kernelContext_0;

#line 389
    (&kernelContext_0)->p_0 = p_1;

#line 389
    (&kernelContext_0)->y_0 = y_1;

#line 389
    (&kernelContext_0)->a_0 = a_1;
    uint t_1 = tid_0.x;
    if(t_1 >= p_1[0U])
    {

#line 392
        return;
    }
    *((&kernelContext_0)->y_0+t_1) = f32_sqrt_0((&kernelContext_0)->a_0[t_1]);
    return;
}

