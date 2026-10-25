#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 405 "kernels/slang/mul_mat.slang"
struct KernelContext_0
{
    uint device* p_0;
    float device* w_0;
    float device* x_0;
    float device* y_0;
};


#line 391
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_1 [[buffer(2)]], float device* w_1 [[buffer(0)]], float device* x_1 [[buffer(1)]], float device* y_1 [[buffer(3)]])
{

#line 391
    uint _S1;

#line 391
    thread KernelContext_0 kernelContext_0;

#line 391
    (&kernelContext_0)->p_0 = p_1;

#line 391
    (&kernelContext_0)->w_0 = w_1;

#line 391
    (&kernelContext_0)->x_0 = x_1;

#line 391
    (&kernelContext_0)->y_0 = y_1;
    uint t_0 = tid_0.x;
    if(t_0 >= (p_1[2U] * p_1[1U]))
    {

#line 394
        return;
    }
    uint r_0 = t_0 / (&kernelContext_0)->p_0[1U];
    uint m_0 = t_0 % (&kernelContext_0)->p_0[1U];
    uint _S2 = r_0 / (&kernelContext_0)->p_0[4U];

#line 398
    uint _S3 = _S2 * (&kernelContext_0)->p_0[3U] + m_0 * (&kernelContext_0)->p_0[0U];
    uint _S4 = r_0 * (&kernelContext_0)->p_0[0U];

#line 399
    float s_0;

#line 399
    uint i_0;
    if((&kernelContext_0)->p_0[5U] != 0U)
    {

#line 400
        s_0 = (as_type<float>((0U)));

#line 400
        i_0 = 0U;

        for(;;)
        {

#line 402
            if(i_0 < ((&kernelContext_0)->p_0)[0U])
            {
            }
            else
            {

#line 402
                break;
            }

#line 403
            float _S5 = s_0 + (&kernelContext_0)->w_0[_S3 + i_0] * (&kernelContext_0)->x_0[_S4 + i_0];

#line 402
            uint i_1 = i_0 + 1U;

#line 402
            s_0 = _S5;

#line 402
            i_0 = i_1;

#line 402
        }


        *((&kernelContext_0)->y_0+t_0) = s_0;
        return;
    }
    float _S6 = (as_type<float>((0U)));

#line 424
    uint np_0 = (&kernelContext_0)->p_0[0U] & 4294967280U;

#line 424
    s_0 = _S6;

#line 424
    float a1_0 = _S6;

#line 424
    float a2_0 = _S6;

#line 424
    float a3_0 = _S6;

#line 424
    float a4_0 = _S6;

#line 424
    float a5_0 = _S6;

#line 424
    float a6_0 = _S6;

#line 424
    float a7_0 = _S6;

#line 424
    float a8_0 = _S6;

#line 424
    float a9_0 = _S6;

#line 424
    float a10_0 = _S6;

#line 424
    float a11_0 = _S6;

#line 424
    float a12_0 = _S6;

#line 424
    float a13_0 = _S6;

#line 424
    float a14_0 = _S6;

#line 424
    float a15_0 = _S6;

#line 424
    uint blk_0 = 0U;
    for(;;)
    {

#line 425
        if(blk_0 < (np_0 / 16U))
        {
        }
        else
        {

#line 425
            break;
        }

#line 426
        uint i_2 = blk_0 * 16U;
        uint _S7 = _S3 + i_2;

#line 427
        uint _S8 = _S4 + i_2;

#line 427
        float _S9 = fma((&kernelContext_0)->w_0[_S7], (&kernelContext_0)->x_0[_S8], s_0);
        float _S10 = fma((&kernelContext_0)->w_0[_S7 + 1U], (&kernelContext_0)->x_0[_S8 + 1U], a1_0);
        float _S11 = fma((&kernelContext_0)->w_0[_S7 + 2U], (&kernelContext_0)->x_0[_S8 + 2U], a2_0);
        float _S12 = fma((&kernelContext_0)->w_0[_S7 + 3U], (&kernelContext_0)->x_0[_S8 + 3U], a3_0);
        float _S13 = fma((&kernelContext_0)->w_0[_S7 + 4U], (&kernelContext_0)->x_0[_S8 + 4U], a4_0);
        float _S14 = fma((&kernelContext_0)->w_0[_S7 + 5U], (&kernelContext_0)->x_0[_S8 + 5U], a5_0);
        float _S15 = fma((&kernelContext_0)->w_0[_S7 + 6U], (&kernelContext_0)->x_0[_S8 + 6U], a6_0);
        float _S16 = fma((&kernelContext_0)->w_0[_S7 + 7U], (&kernelContext_0)->x_0[_S8 + 7U], a7_0);
        float _S17 = fma((&kernelContext_0)->w_0[_S7 + 8U], (&kernelContext_0)->x_0[_S8 + 8U], a8_0);
        float _S18 = fma((&kernelContext_0)->w_0[_S7 + 9U], (&kernelContext_0)->x_0[_S8 + 9U], a9_0);
        float _S19 = fma((&kernelContext_0)->w_0[_S7 + 10U], (&kernelContext_0)->x_0[_S8 + 10U], a10_0);
        float _S20 = fma((&kernelContext_0)->w_0[_S7 + 11U], (&kernelContext_0)->x_0[_S8 + 11U], a11_0);
        float _S21 = fma((&kernelContext_0)->w_0[_S7 + 12U], (&kernelContext_0)->x_0[_S8 + 12U], a12_0);
        float _S22 = fma((&kernelContext_0)->w_0[_S7 + 13U], (&kernelContext_0)->x_0[_S8 + 13U], a13_0);
        float _S23 = fma((&kernelContext_0)->w_0[_S7 + 14U], (&kernelContext_0)->x_0[_S8 + 14U], a14_0);
        float _S24 = fma((&kernelContext_0)->w_0[_S7 + 15U], (&kernelContext_0)->x_0[_S8 + 15U], a15_0);

#line 425
        uint blk_1 = blk_0 + 1U;

#line 425
        s_0 = _S9;

#line 425
        a1_0 = _S10;

#line 425
        a2_0 = _S11;

#line 425
        a3_0 = _S12;

#line 425
        a4_0 = _S13;

#line 425
        a5_0 = _S14;

#line 425
        a6_0 = _S15;

#line 425
        a7_0 = _S16;

#line 425
        a8_0 = _S17;

#line 425
        a9_0 = _S18;

#line 425
        a10_0 = _S19;

#line 425
        a11_0 = _S20;

#line 425
        a12_0 = _S21;

#line 425
        a13_0 = _S22;

#line 425
        a14_0 = _S23;

#line 425
        a15_0 = _S24;

#line 425
        blk_0 = blk_1;

#line 425
    }

#line 456
    float _S25 = s_0 + a8_0 + (a4_0 + a12_0) + (a1_0 + a9_0 + (a5_0 + a13_0)) + (a2_0 + a10_0 + (a6_0 + a14_0) + (a3_0 + a11_0 + (a7_0 + a15_0)));
    uint tl_0 = (&kernelContext_0)->p_0[0U] - np_0;

#line 457
    uint nq_0;
    if(tl_0 >= 4U)
    {

#line 458
        nq_0 = tl_0 & 4294967292U;

#line 458
    }
    else
    {

#line 458
        nq_0 = 0U;

#line 458
    }

#line 458
    float sumf_0 = _S25;

#line 458
    i_0 = np_0;
    for(;;)
    {

#line 459
        uint _S26 = np_0 + nq_0;

#line 459
        _S1 = _S26;

#line 459
        if(i_0 < _S26)
        {
        }
        else
        {

#line 459
            break;
        }
        float _S27 = sumf_0 + (&kernelContext_0)->w_0[_S3 + i_0] * (&kernelContext_0)->x_0[_S4 + i_0];

#line 459
        uint i_3 = i_0 + 1U;

#line 459
        sumf_0 = _S27;

#line 459
        i_0 = i_3;

#line 459
    }

#line 459
    i_0 = _S1;



    for(;;)
    {

#line 463
        if(i_0 < ((&kernelContext_0)->p_0)[0U])
        {
        }
        else
        {

#line 463
            break;
        }

#line 464
        float _S28 = fma((&kernelContext_0)->w_0[_S3 + i_0], (&kernelContext_0)->x_0[_S4 + i_0], sumf_0);

#line 463
        uint i_4 = i_0 + 1U;

#line 463
        sumf_0 = _S28;

#line 463
        i_0 = i_4;

#line 463
    }


    *((&kernelContext_0)->y_0+t_0) = sumf_0;
    return;
}

