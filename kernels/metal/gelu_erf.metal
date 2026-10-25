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


#line 52 "kernels/slang/gelu_erf.slang"
ulong f64_from_f32_0(float x_0)
{

#line 53
    uint b_0 = (as_type<uint>((x_0)));
    ulong s_0 = ulong(b_0 >> 31U);
    uint e_0 = (b_0 >> 23U) & 255U;
    uint f_0 = b_0 & 8388607U;
    if(e_0 == 255U)
    {

#line 58
        return ((s_0 << 63ULL) | 9218868437227405312ULL) | (ulong(f_0) << 29ULL);
    }
    if(e_0 == 0U)
    {

#line 61
        if(f_0 == 0U)
        {

#line 62
            return s_0 << 63ULL;
        }
        uint p_0 = firstbithigh_0(f_0);
        return ((s_0 << 63ULL) | (ulong(p_0 + 874U) << 52ULL)) | ((ulong(f_0) << ulong(52U - p_0)) & 4503599627370495ULL);
    }
    return ((s_0 << 63ULL) | (ulong(e_0 + 896U) << 52ULL)) | (ulong(f_0) << 29ULL);
}


#line 10
int hibit64_0(ulong x_1)
{

#line 11
    uint hi_0 = uint(x_1 >> 32ULL);
    if(hi_0 != 0U)
    {

#line 13
        return int(firstbithigh_0(hi_0)) + int(32);
    }
    return int(firstbithigh_0(uint(x_1 & 4294967295ULL)));
}

ulong srs_0(ulong x_2, uint n_0)
{

#line 19
    if(n_0 == 0U)
    {

#line 20
        return x_2;
    }

#line 20
    ulong _S2;

    if(n_0 >= 63U)
    {

#line 23
        if(x_2 != 0ULL)
        {

#line 23
            _S2 = 1ULL;

#line 23
        }
        else
        {

#line 23
            _S2 = 0ULL;

#line 23
        }

#line 23
        return _S2;
    }
    ulong _S3 = ulong(n_0);
    ulong _S4 = x_2 >> _S3;

#line 26
    if((x_2 & ((1ULL << _S3) - 1ULL)) != 0ULL)
    {

#line 26
        _S2 = 1ULL;

#line 26
    }
    else
    {

#line 26
        _S2 = 0ULL;

#line 26
    }

#line 26
    return _S4 | _S2;
}

ulong pack64_0(ulong s_1, int e0_0, ulong m0_0)
{

#line 29
    ulong m_0;

#line 29
    int e_1;


    if(e0_0 < int(1))
    {

#line 32
        m_0 = srs_0(m0_0, uint(int(1) - e0_0));

#line 32
        e_1 = int(1);

#line 32
    }
    else
    {

#line 32
        m_0 = m0_0;

#line 32
        e_1 = e0_0;

#line 32
    }



    ulong rem_0 = m_0 & 511ULL;
    ulong m_1 = m_0 >> 9ULL;

#line 37
    bool _S5;
    if(rem_0 > 256ULL)
    {

#line 38
        _S5 = true;

#line 38
    }
    else
    {

#line 38
        if(rem_0 == 256ULL)
        {

#line 38
            _S5 = (m_1 & 1ULL) != 0ULL;

#line 38
        }
        else
        {

#line 38
            _S5 = false;

#line 38
        }

#line 38
    }

#line 38
    if(_S5)
    {

#line 38
        m_0 = m_1 + 1ULL;

#line 38
    }
    else
    {

#line 38
        m_0 = m_1;

#line 38
    }


    if((m_0 >> 53ULL) != 0ULL)
    {

#line 42
        ulong _S6 = m_0 >> 1ULL;

#line 42
        e_1 = e_1 + int(1);

#line 42
        m_0 = _S6;

#line 41
    }



    if(e_1 >= int(2047))
    {

#line 46
        return (s_1 << 63ULL) | 9218868437227405312ULL;
    }

#line 46
    ulong field_0;

    if((m_0 >> 52ULL) != 0ULL)
    {

#line 48
        field_0 = ulong(e_1);

#line 48
    }
    else
    {

#line 48
        field_0 = 0ULL;

#line 48
    }
    return ((s_1 << 63ULL) | (field_0 << 52ULL)) | (m_0 & 4503599627370495ULL);
}


#line 195
ulong f64_mul_0(ulong a_0, ulong b_1)
{

#line 196
    ulong s_2 = (a_0 ^ b_1) >> 63ULL;
    ulong _S7 = a_0 & 9223372036854775807ULL;

#line 197
    if(_S7 > 9218868437227405312ULL)
    {

#line 198
        return a_0 | 2251799813685248ULL;
    }
    ulong _S8 = b_1 & 9223372036854775807ULL;

#line 200
    if(_S8 > 9218868437227405312ULL)
    {

#line 201
        return b_1 | 2251799813685248ULL;
    }
    if(_S7 == 9218868437227405312ULL)
    {

#line 204
        if(_S8 == 0ULL)
        {

#line 205
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S8 == 9218868437227405312ULL)
    {

#line 210
        if(_S7 == 0ULL)
        {

#line 211
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }

#line 213
    bool _S9;

    if(_S7 == 0ULL)
    {

#line 215
        _S9 = true;

#line 215
    }
    else
    {

#line 215
        _S9 = _S8 == 0ULL;

#line 215
    }

#line 215
    if(_S9)
    {

#line 216
        return s_2 << 63ULL;
    }
    int ae_0 = int((a_0 >> 52ULL) & 2047ULL);
    ulong am_0 = a_0 & 4503599627370495ULL;

#line 219
    ulong am_1;

#line 219
    int ae_1;
    if(ae_0 == int(0))
    {
        int _S10 = int(52) - hibit64_0(am_0);
        int _S11 = int(1) - _S10;

#line 223
        am_1 = am_0 << ulong(_S10);

#line 223
        ae_1 = _S11;

#line 220
    }
    else
    {

#line 220
        am_1 = am_0 | 4503599627370496ULL;

#line 220
        ae_1 = ae_0;

#line 220
    }

#line 227
    int be_0 = int((b_1 >> 52ULL) & 2047ULL);
    ulong bm_0 = b_1 & 4503599627370495ULL;

#line 228
    ulong bm_1;

#line 228
    int be_1;
    if(be_0 == int(0))
    {
        int _S12 = int(52) - hibit64_0(bm_0);
        int _S13 = int(1) - _S12;

#line 232
        bm_1 = bm_0 << ulong(_S12);

#line 232
        be_1 = _S13;

#line 229
    }
    else
    {

#line 229
        bm_1 = bm_0 | 4503599627370496ULL;

#line 229
        be_1 = be_0;

#line 229
    }

#line 236
    ulong a0_0 = am_1 & 4294967295ULL;
    ulong a1_0 = am_1 >> 32ULL;
    ulong b0_0 = bm_1 & 4294967295ULL;
    ulong b1_0 = bm_1 >> 32ULL;
    ulong p00_0 = a0_0 * b0_0;
    ulong p01_0 = a0_0 * b1_0;
    ulong p10_0 = a1_0 * b0_0;

    ulong mid_0 = (p00_0 >> 32ULL) + (p01_0 & 4294967295ULL) + (p10_0 & 4294967295ULL);
    ulong lo_0 = (p00_0 & 4294967295ULL) | (mid_0 << 32ULL);

    ulong _S14 = ((a1_0 * b1_0 + (p01_0 >> 32ULL) + (p10_0 >> 32ULL) + (mid_0 >> 32ULL)) << 21ULL) | (lo_0 >> 43ULL);

#line 247
    if((lo_0 & 8796093022207ULL) != 0ULL)
    {

#line 247
        am_1 = 1ULL;

#line 247
    }
    else
    {

#line 247
        am_1 = 0ULL;

#line 247
    }

#line 247
    ulong m_2 = _S14 | am_1;
    int e_2 = ae_1 + be_1 - int(1023);

#line 248
    ulong m_3;

#line 248
    int e_3;
    if((m_2 >> 62ULL) != 0ULL)
    {

#line 250
        ulong _S15 = srs_0(m_2, 1U);

#line 250
        e_3 = e_2 + int(1);

#line 250
        m_3 = _S15;

#line 249
    }
    else
    {

#line 249
        e_3 = e_2;

#line 249
        m_3 = m_2;

#line 249
    }



    return pack64_0(s_2, e_3, m_3);
}


#line 78
float f64_to_f32_0(ulong d_0)
{

#line 79
    uint s_3 = uint(d_0 >> 63ULL);
    int e_4 = int((d_0 >> 52ULL) & 2047ULL);
    ulong f_1 = d_0 & 4503599627370495ULL;

#line 81
    uint sh_0;
    if(e_4 == int(2047))
    {

#line 83
        uint _S16 = (s_3 << 31U) | 2139095040U;

#line 83
        if(f_1 != 0ULL)
        {

#line 83
            sh_0 = 4194304U | uint(f_1 >> 29ULL);

#line 83
        }
        else
        {

#line 83
            sh_0 = 0U;

#line 83
        }

#line 83
        return (as_type<float>((_S16 | sh_0)));
    }
    bool _S17 = e_4 == int(0);

#line 85
    bool _S18;

#line 85
    if(_S17)
    {

#line 85
        _S18 = f_1 == 0ULL;

#line 85
    }
    else
    {

#line 85
        _S18 = false;

#line 85
    }

#line 85
    if(_S18)
    {

#line 86
        return (as_type<float>((s_3 << 31U)));
    }

#line 86
    ulong q_0;

    if(e_4 != int(0))
    {

#line 88
        q_0 = 4503599627370496ULL;

#line 88
    }
    else
    {

#line 88
        q_0 = 0ULL;

#line 88
    }

#line 88
    ulong m_4 = f_1 | q_0;

#line 88
    int e_5;
    if(_S17)
    {

#line 89
        e_5 = int(1);

#line 89
    }
    else
    {

#line 89
        e_5 = e_4;

#line 89
    }


    int ef_0 = e_5 - int(896);

#line 92
    int ef_1;

    if(ef_0 <= int(0))
    {

#line 94
        sh_0 = uint(int(30) - ef_0);

#line 94
        ef_1 = int(0);

#line 94
    }
    else
    {

#line 94
        sh_0 = 29U;

#line 94
        ef_1 = ef_0;

#line 94
    }



    if(sh_0 > 63U)
    {

#line 98
        sh_0 = 63U;

#line 98
    }


    ulong _S19 = ulong(sh_0);

#line 101
    ulong q_1 = m_4 >> _S19;
    ulong rem_1 = m_4 & ((1ULL << _S19) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - 1U);
    if(rem_1 > half_0)
    {

#line 104
        _S18 = true;

#line 104
    }
    else
    {

#line 104
        if(rem_1 == half_0)
        {

#line 104
            _S18 = (q_1 & 1ULL) != 0ULL;

#line 104
        }
        else
        {

#line 104
            _S18 = false;

#line 104
        }

#line 104
    }

#line 104
    if(_S18)
    {

#line 104
        q_0 = q_1 + 1ULL;

#line 104
    }
    else
    {

#line 104
        q_0 = q_1;

#line 104
    }


    if(ef_1 == int(0))
    {

#line 108
        return (as_type<float>(((s_3 << 31U) | uint(q_0))));
    }
    if((q_0 >> 24ULL) != 0ULL)
    {

#line 111
        ulong _S20 = q_0 >> 1ULL;

#line 111
        ef_1 = ef_1 + int(1);

#line 111
        q_0 = _S20;

#line 110
    }



    if(ef_1 >= int(255))
    {

#line 115
        return (as_type<float>(((s_3 << 31U) | 2139095040U)));
    }
    return (as_type<float>((((s_3 << 31U) | (uint(ef_1) << 23U)) | uint(q_0 & 8388607ULL))));
}


#line 515
struct KernelContext_0
{
    uint device* p_1;
    float device* x_3;
    float device* erffTable_0;
    float device* y_0;
};


#line 464
float platform_erff_0(float x_4, KernelContext_0 thread* kernelContext_0)
{

#line 465
    uint xb_0 = (as_type<uint>((x_4)));
    uint w9_0 = xb_0 & 2147483647U;
    float ax_0 = (as_type<float>((w9_0)));
    if((w9_0 >> 23U) > 254U)
    {

#line 469
        if(w9_0 == 2139095040U)
        {

#line 470
            return (as_type<float>(((xb_0 & 2147483648U) | 1065353216U)));
        }
        return (as_type<float>((xb_0 | 4194304U)));
    }
    if(w9_0 > 1046609920U)
    {

#line 475
        uint sg_0 = xb_0 & 2147483648U;
        if(w9_0 > 1081791743U)
        {

#line 477
            return (as_type<float>((sg_0 | (as_type<uint>(((as_type<float>((1065353216U))) - (as_type<float>((8388608U)))))))));
        }
        float tt_0 = ax_0 + (as_type<float>((1237319680U)));

        uint ix_0 = ((as_type<uint>((tt_0))) & 31U) * 8U;
        float r_0 = ax_0 - (tt_0 + (as_type<float>((3384803328U))));

#line 491
        return (as_type<float>((sg_0 | (as_type<uint>((kernelContext_0->erffTable_0[ix_0] + fma(r_0, kernelContext_0->erffTable_0[ix_0 + 2U], fma(r_0, fma(r_0, fma(r_0 * r_0, fma(r_0, kernelContext_0->erffTable_0[ix_0 + 7U], kernelContext_0->erffTable_0[ix_0 + 6U]), fma(r_0, kernelContext_0->erffTable_0[ix_0 + 5U], kernelContext_0->erffTable_0[ix_0 + 4U])), kernelContext_0->erffTable_0[ix_0 + 3U]), kernelContext_0->erffTable_0[ix_0 + 1U]))))))));
    }
    if(w9_0 > 619091348U)
    {

#line 494
        float x2_0 = x_4 * x_4;

#line 499
        return fma(x_4, (as_type<float>((1066430139U))), x_4 * fma(x2_0, fma(x2_0, fma(x2_0, (as_type<float>((3168266449U))), (as_type<float>((1038552905U)))), (as_type<float>((3200291742U)))), (as_type<float>((3011311510U)))));
    }
    return f64_to_f32_0(f64_mul_0(f64_from_f32_0(x_4), 4607760587169110893ULL));
}


[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_2 [[buffer(2)]], float device* x_5 [[buffer(0)]], float device* erffTable_1 [[buffer(1)]], float device* y_1 [[buffer(3)]])
{

#line 505
    thread KernelContext_0 kernelContext_1;

#line 505
    (&kernelContext_1)->p_1 = p_2;

#line 505
    (&kernelContext_1)->x_3 = x_5;

#line 505
    (&kernelContext_1)->erffTable_0 = erffTable_1;

#line 505
    (&kernelContext_1)->y_0 = y_1;
    uint t_0 = tid_0.x;
    if(t_0 >= p_2[0U])
    {

#line 508
        return;
    }
    float xv_0 = (&kernelContext_1)->x_3[t_0];

#line 510
    float _S21 = platform_erff_0(xv_0 * (as_type<float>((1060439283U))), &kernelContext_1);

#line 510
    float ev_0;

    if((&kernelContext_1)->p_1[1U] != 0U)
    {

#line 512
        ev_0 = tanh((as_type<float>((1061962282U))) * xv_0 * ((as_type<float>((1065353216U))) + (as_type<float>((1027024659U))) * xv_0 * xv_0));

#line 512
    }
    else
    {

#line 512
        ev_0 = _S21;

#line 512
    }


    *((&kernelContext_1)->y_0+t_0) = (as_type<float>((1056964608U))) * xv_0 * ((as_type<float>((1065353216U))) + ev_0);
    uint _S22 = (as_type<uint>((xv_0)));

#line 516
    if((_S22 & 2147483647U) > 2139095040U)
    {

#line 517
        *((&kernelContext_1)->y_0+t_0) = (as_type<float>((_S22 | 4194304U)));

#line 516
    }


    return;
}

