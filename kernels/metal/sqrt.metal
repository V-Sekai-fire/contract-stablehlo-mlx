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


#line 321
float f32_sqrt_0(float x_1)
{

#line 322
    uint b_0 = (as_type<uint>((x_1)));
    if((b_0 & 2147483647U) == 0U)
    {

#line 324
        return x_1;
    }
    if((b_0 >> 31U) != 0U)
    {

#line 327
        return (as_type<float>((2143289344U)));
    }
    if(b_0 >= 2139095040U)
    {

#line 330
        return x_1;
    }
    int e_0 = int(b_0 >> 23U);
    uint m_0 = b_0 & 8388607U;

#line 333
    int e_1;

#line 333
    uint m_1;
    if(e_0 == int(0))
    {
        int _S2 = int(23) - int(firstbithigh_0(m_0));

#line 336
        uint _S3 = m_0 << uint(_S2);

#line 336
        e_1 = int(1) - _S2;

#line 336
        m_1 = _S3;

#line 334
    }
    else
    {


        uint _S4 = m_0 | 8388608U;

#line 339
        e_1 = e_0;

#line 339
        m_1 = _S4;

#line 334
    }

#line 341
    int k_0 = e_1 - int(150);
    ulong w_0 = ulong(m_1);

#line 342
    int k_1;

#line 342
    ulong w_1;
    if((k_0 & int(1)) != int(0))
    {
        int _S5 = k_0 - int(1);

#line 345
        w_1 = w_0 << 1ULL;

#line 345
        k_1 = _S5;

#line 343
    }
    else
    {

#line 343
        w_1 = w_0;

#line 343
        k_1 = k_0;

#line 343
    }



    ulong _S6 = w_1 << 38ULL;
    int k_2 = k_1 - int(38);

#line 348
    ulong rem_0 = 0ULL;

#line 348
    w_1 = _S6;

#line 348
    ulong r_0 = 0ULL;

#line 348
    uint i_0 = 0U;


    for(;;)
    {

#line 351
        if(i_0 < 32U)
        {
        }
        else
        {

#line 351
            break;
        }

#line 352
        ulong rem_1 = (rem_0 << 2ULL) | ((w_1 >> 62ULL) & 3ULL);
        ulong _S7 = w_1 << 2ULL;
        ulong t_0 = (r_0 << 2ULL) | 1ULL;
        ulong r_1 = r_0 << 1ULL;
        if(rem_1 >= t_0)
        {
            ulong _S8 = r_1 | 1ULL;

#line 358
            rem_0 = rem_1 - t_0;

#line 358
            r_0 = _S8;

#line 356
        }
        else
        {

#line 356
            rem_0 = rem_1;

#line 356
            r_0 = r_1;

#line 356
        }

#line 351
        uint i_1 = i_0 + 1U;

#line 351
        w_1 = _S7;

#line 351
        i_0 = i_1;

#line 351
    }

#line 362
    int sh_0 = hibit64_0(r_0) - int(23);
    ulong _S9 = ulong(sh_0);

#line 363
    ulong q_0 = r_0 >> _S9;
    ulong lost_0 = r_0 & ((1ULL << _S9) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - int(1));

#line 365
    bool sticky_0;
    if(rem_0 != 0ULL)
    {

#line 366
        sticky_0 = true;

#line 366
    }
    else
    {

#line 366
        sticky_0 = (lost_0 & (half_0 - 1ULL)) != 0ULL;

#line 366
    }
    if((lost_0 & half_0) != 0ULL)
    {

#line 367
        if(sticky_0)
        {

#line 367
            sticky_0 = true;

#line 367
        }
        else
        {

#line 367
            sticky_0 = (q_0 & 1ULL) != 0ULL;

#line 367
        }

#line 367
    }
    else
    {

#line 367
        sticky_0 = false;

#line 367
    }

#line 367
    ulong q_1;

#line 367
    if(sticky_0)
    {

#line 367
        q_1 = q_0 + 1ULL;

#line 367
    }
    else
    {

#line 367
        q_1 = q_0;

#line 367
    }


    int ee_0 = k_2 / int(2) + sh_0 + int(150);

#line 370
    int ee_1;
    if((q_1 >> 24ULL) != 0ULL)
    {

#line 372
        ulong _S10 = q_1 >> 1ULL;

#line 372
        ee_1 = ee_0 + int(1);

#line 372
        q_1 = _S10;

#line 371
    }
    else
    {

#line 371
        ee_1 = ee_0;

#line 371
    }



    return (as_type<float>(((uint(ee_1) << 23U) | uint(q_1 & 8388607ULL))));
}


#line 468
struct KernelContext_0
{
    uint device* p_0;
    float device* y_0;
    float device* a_0;
};


#line 463
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_1 [[buffer(1)]], float device* y_1 [[buffer(2)]], float device* a_1 [[buffer(0)]])
{

#line 463
    thread KernelContext_0 kernelContext_0;

#line 463
    (&kernelContext_0)->p_0 = p_1;

#line 463
    (&kernelContext_0)->y_0 = y_1;

#line 463
    (&kernelContext_0)->a_0 = a_1;
    uint t_1 = tid_0.x;
    if(t_1 >= p_1[0U])
    {

#line 466
        return;
    }
    *((&kernelContext_0)->y_0+t_1) = f32_sqrt_0((&kernelContext_0)->a_0[t_1]);
    return;
}

