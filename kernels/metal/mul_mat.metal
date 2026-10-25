#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 479 "kernels/slang/mul_mat.slang"
struct KernelContext_0
{
    uint device* p_0;
    float device* w_0;
    float device* x_0;
    float device* y_0;
};


#line 465
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_1 [[buffer(2)]], float device* w_1 [[buffer(0)]], float device* x_1 [[buffer(1)]], float device* y_1 [[buffer(3)]])
{

#line 465
    uint _S1;

#line 465
    thread KernelContext_0 kernelContext_0;

#line 465
    (&kernelContext_0)->p_0 = p_1;

#line 465
    (&kernelContext_0)->w_0 = w_1;

#line 465
    (&kernelContext_0)->x_0 = x_1;

#line 465
    (&kernelContext_0)->y_0 = y_1;
    uint t_0 = tid_0.x;
    if(t_0 >= (p_1[2U] * p_1[1U]))
    {

#line 468
        return;
    }
    uint r_0 = t_0 / (&kernelContext_0)->p_0[1U];
    uint m_0 = t_0 % (&kernelContext_0)->p_0[1U];
    uint _S2 = r_0 / (&kernelContext_0)->p_0[4U];

#line 472
    uint _S3 = _S2 * (&kernelContext_0)->p_0[3U] + m_0 * (&kernelContext_0)->p_0[0U];
    uint _S4 = r_0 * (&kernelContext_0)->p_0[0U];

#line 473
    float s_0;

#line 473
    uint i_0;
    if((&kernelContext_0)->p_0[5U] != 0U)
    {

#line 474
        s_0 = (as_type<float>((0U)));

#line 474
        i_0 = 0U;

        for(;;)
        {

#line 476
            if(i_0 < ((&kernelContext_0)->p_0)[0U])
            {
            }
            else
            {

#line 476
                break;
            }

#line 477
            float _S5 = s_0 + (&kernelContext_0)->w_0[_S3 + i_0] * (&kernelContext_0)->x_0[_S4 + i_0];

#line 476
            uint i_1 = i_0 + 1U;

#line 476
            s_0 = _S5;

#line 476
            i_0 = i_1;

#line 476
        }


        *((&kernelContext_0)->y_0+t_0) = s_0;
        return;
    }
    float _S6 = (as_type<float>((0U)));

#line 498
    uint np_0 = (&kernelContext_0)->p_0[0U] & 4294967280U;

#line 498
    s_0 = _S6;

#line 498
    float a1_0 = _S6;

#line 498
    float a2_0 = _S6;

#line 498
    float a3_0 = _S6;

#line 498
    float a4_0 = _S6;

#line 498
    float a5_0 = _S6;

#line 498
    float a6_0 = _S6;

#line 498
    float a7_0 = _S6;

#line 498
    float a8_0 = _S6;

#line 498
    float a9_0 = _S6;

#line 498
    float a10_0 = _S6;

#line 498
    float a11_0 = _S6;

#line 498
    float a12_0 = _S6;

#line 498
    float a13_0 = _S6;

#line 498
    float a14_0 = _S6;

#line 498
    float a15_0 = _S6;

#line 498
    uint blk_0 = 0U;
    for(;;)
    {

#line 499
        if(blk_0 < (np_0 / 16U))
        {
        }
        else
        {

#line 499
            break;
        }

#line 500
        uint i_2 = blk_0 * 16U;
        uint _S7 = _S3 + i_2;

#line 501
        uint _S8 = _S4 + i_2;

#line 501
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

#line 499
        uint blk_1 = blk_0 + 1U;

#line 499
        s_0 = _S9;

#line 499
        a1_0 = _S10;

#line 499
        a2_0 = _S11;

#line 499
        a3_0 = _S12;

#line 499
        a4_0 = _S13;

#line 499
        a5_0 = _S14;

#line 499
        a6_0 = _S15;

#line 499
        a7_0 = _S16;

#line 499
        a8_0 = _S17;

#line 499
        a9_0 = _S18;

#line 499
        a10_0 = _S19;

#line 499
        a11_0 = _S20;

#line 499
        a12_0 = _S21;

#line 499
        a13_0 = _S22;

#line 499
        a14_0 = _S23;

#line 499
        a15_0 = _S24;

#line 499
        blk_0 = blk_1;

#line 499
    }

#line 530
    float _S25 = s_0 + a8_0 + (a4_0 + a12_0) + (a1_0 + a9_0 + (a5_0 + a13_0)) + (a2_0 + a10_0 + (a6_0 + a14_0) + (a3_0 + a11_0 + (a7_0 + a15_0)));
    uint tl_0 = (&kernelContext_0)->p_0[0U] - np_0;

#line 531
    uint nq_0;
    if(tl_0 >= 4U)
    {

#line 532
        nq_0 = tl_0 & 4294967292U;

#line 532
    }
    else
    {

#line 532
        nq_0 = 0U;

#line 532
    }

#line 532
    float sumf_0 = _S25;

#line 532
    i_0 = np_0;
    for(;;)
    {

#line 533
        uint _S26 = np_0 + nq_0;

#line 533
        _S1 = _S26;

#line 533
        if(i_0 < _S26)
        {
        }
        else
        {

#line 533
            break;
        }
        float _S27 = sumf_0 + (&kernelContext_0)->w_0[_S3 + i_0] * (&kernelContext_0)->x_0[_S4 + i_0];

#line 533
        uint i_3 = i_0 + 1U;

#line 533
        sumf_0 = _S27;

#line 533
        i_0 = i_3;

#line 533
    }

#line 533
    i_0 = _S1;



    for(;;)
    {

#line 537
        if(i_0 < ((&kernelContext_0)->p_0)[0U])
        {
        }
        else
        {

#line 537
            break;
        }

#line 538
        float _S28 = fma((&kernelContext_0)->w_0[_S3 + i_0], (&kernelContext_0)->x_0[_S4 + i_0], sumf_0);

#line 537
        uint i_4 = i_0 + 1U;

#line 537
        sumf_0 = _S28;

#line 537
        i_0 = i_4;

#line 537
    }


    *((&kernelContext_0)->y_0+t_0) = sumf_0;
    return;
}

