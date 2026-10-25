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


#line 50 "kernels/slang/erff_map.slang"
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


#line 8
int hibit64_0(ulong x_1)
{

#line 9
    uint hi_0 = uint(x_1 >> 32ULL);
    if(hi_0 != 0U)
    {

#line 11
        return int(firstbithigh_0(hi_0)) + int(32);
    }
    return int(firstbithigh_0(uint(x_1 & 4294967295ULL)));
}

ulong srs_0(ulong x_2, uint n_0)
{

#line 17
    if(n_0 == 0U)
    {

#line 18
        return x_2;
    }

#line 18
    ulong _S2;

    if(n_0 >= 63U)
    {

#line 21
        if(x_2 != 0ULL)
        {

#line 21
            _S2 = 1ULL;

#line 21
        }
        else
        {

#line 21
            _S2 = 0ULL;

#line 21
        }

#line 21
        return _S2;
    }
    ulong _S3 = ulong(n_0);
    ulong _S4 = x_2 >> _S3;

#line 24
    if((x_2 & ((1ULL << _S3) - 1ULL)) != 0ULL)
    {

#line 24
        _S2 = 1ULL;

#line 24
    }
    else
    {

#line 24
        _S2 = 0ULL;

#line 24
    }

#line 24
    return _S4 | _S2;
}

ulong pack64_0(ulong s_1, int e0_0, ulong m0_0)
{

#line 27
    ulong m_0;

#line 27
    int e_1;


    if(e0_0 < int(1))
    {

#line 30
        m_0 = srs_0(m0_0, uint(int(1) - e0_0));

#line 30
        e_1 = int(1);

#line 30
    }
    else
    {

#line 30
        m_0 = m0_0;

#line 30
        e_1 = e0_0;

#line 30
    }



    ulong rem_0 = m_0 & 511ULL;
    ulong m_1 = m_0 >> 9ULL;

#line 35
    bool _S5;
    if(rem_0 > 256ULL)
    {

#line 36
        _S5 = true;

#line 36
    }
    else
    {

#line 36
        if(rem_0 == 256ULL)
        {

#line 36
            _S5 = (m_1 & 1ULL) != 0ULL;

#line 36
        }
        else
        {

#line 36
            _S5 = false;

#line 36
        }

#line 36
    }

#line 36
    if(_S5)
    {

#line 36
        m_0 = m_1 + 1ULL;

#line 36
    }
    else
    {

#line 36
        m_0 = m_1;

#line 36
    }


    if((m_0 >> 53ULL) != 0ULL)
    {

#line 40
        ulong _S6 = m_0 >> 1ULL;

#line 40
        e_1 = e_1 + int(1);

#line 40
        m_0 = _S6;

#line 39
    }



    if(e_1 >= int(2047))
    {

#line 44
        return (s_1 << 63ULL) | 9218868437227405312ULL;
    }

#line 44
    ulong field_0;

    if((m_0 >> 52ULL) != 0ULL)
    {

#line 46
        field_0 = ulong(e_1);

#line 46
    }
    else
    {

#line 46
        field_0 = 0ULL;

#line 46
    }
    return ((s_1 << 63ULL) | (field_0 << 52ULL)) | (m_0 & 4503599627370495ULL);
}


#line 193
ulong f64_mul_0(ulong a_0, ulong b_1)
{

#line 194
    ulong s_2 = (a_0 ^ b_1) >> 63ULL;
    ulong _S7 = a_0 & 9223372036854775807ULL;

#line 195
    if(_S7 > 9218868437227405312ULL)
    {

#line 196
        return a_0 | 2251799813685248ULL;
    }
    ulong _S8 = b_1 & 9223372036854775807ULL;

#line 198
    if(_S8 > 9218868437227405312ULL)
    {

#line 199
        return b_1 | 2251799813685248ULL;
    }
    if(_S7 == 9218868437227405312ULL)
    {

#line 202
        if(_S8 == 0ULL)
        {

#line 203
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S8 == 9218868437227405312ULL)
    {

#line 208
        if(_S7 == 0ULL)
        {

#line 209
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }

#line 211
    bool _S9;

    if(_S7 == 0ULL)
    {

#line 213
        _S9 = true;

#line 213
    }
    else
    {

#line 213
        _S9 = _S8 == 0ULL;

#line 213
    }

#line 213
    if(_S9)
    {

#line 214
        return s_2 << 63ULL;
    }
    int ae_0 = int((a_0 >> 52ULL) & 2047ULL);
    ulong am_0 = a_0 & 4503599627370495ULL;

#line 217
    ulong am_1;

#line 217
    int ae_1;
    if(ae_0 == int(0))
    {
        int _S10 = int(52) - hibit64_0(am_0);
        int _S11 = int(1) - _S10;

#line 221
        am_1 = am_0 << ulong(_S10);

#line 221
        ae_1 = _S11;

#line 218
    }
    else
    {

#line 218
        am_1 = am_0 | 4503599627370496ULL;

#line 218
        ae_1 = ae_0;

#line 218
    }

#line 225
    int be_0 = int((b_1 >> 52ULL) & 2047ULL);
    ulong bm_0 = b_1 & 4503599627370495ULL;

#line 226
    ulong bm_1;

#line 226
    int be_1;
    if(be_0 == int(0))
    {
        int _S12 = int(52) - hibit64_0(bm_0);
        int _S13 = int(1) - _S12;

#line 230
        bm_1 = bm_0 << ulong(_S12);

#line 230
        be_1 = _S13;

#line 227
    }
    else
    {

#line 227
        bm_1 = bm_0 | 4503599627370496ULL;

#line 227
        be_1 = be_0;

#line 227
    }

#line 234
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

#line 245
    if((lo_0 & 8796093022207ULL) != 0ULL)
    {

#line 245
        am_1 = 1ULL;

#line 245
    }
    else
    {

#line 245
        am_1 = 0ULL;

#line 245
    }

#line 245
    ulong m_2 = _S14 | am_1;
    int e_2 = ae_1 + be_1 - int(1023);

#line 246
    ulong m_3;

#line 246
    int e_3;
    if((m_2 >> 62ULL) != 0ULL)
    {

#line 248
        ulong _S15 = srs_0(m_2, 1U);

#line 248
        e_3 = e_2 + int(1);

#line 248
        m_3 = _S15;

#line 247
    }
    else
    {

#line 247
        e_3 = e_2;

#line 247
        m_3 = m_2;

#line 247
    }



    return pack64_0(s_2, e_3, m_3);
}


#line 76
float f64_to_f32_0(ulong d_0)
{

#line 77
    uint s_3 = uint(d_0 >> 63ULL);
    int e_4 = int((d_0 >> 52ULL) & 2047ULL);
    ulong f_1 = d_0 & 4503599627370495ULL;

#line 79
    uint sh_0;
    if(e_4 == int(2047))
    {

#line 81
        uint _S16 = (s_3 << 31U) | 2139095040U;

#line 81
        if(f_1 != 0ULL)
        {

#line 81
            sh_0 = 4194304U | uint(f_1 >> 29ULL);

#line 81
        }
        else
        {

#line 81
            sh_0 = 0U;

#line 81
        }

#line 81
        return (as_type<float>((_S16 | sh_0)));
    }
    bool _S17 = e_4 == int(0);

#line 83
    bool _S18;

#line 83
    if(_S17)
    {

#line 83
        _S18 = f_1 == 0ULL;

#line 83
    }
    else
    {

#line 83
        _S18 = false;

#line 83
    }

#line 83
    if(_S18)
    {

#line 84
        return (as_type<float>((s_3 << 31U)));
    }

#line 84
    ulong q_0;

    if(e_4 != int(0))
    {

#line 86
        q_0 = 4503599627370496ULL;

#line 86
    }
    else
    {

#line 86
        q_0 = 0ULL;

#line 86
    }

#line 86
    ulong m_4 = f_1 | q_0;

#line 86
    int e_5;
    if(_S17)
    {

#line 87
        e_5 = int(1);

#line 87
    }
    else
    {

#line 87
        e_5 = e_4;

#line 87
    }


    int ef_0 = e_5 - int(896);

#line 90
    int ef_1;

    if(ef_0 <= int(0))
    {

#line 92
        sh_0 = uint(int(30) - ef_0);

#line 92
        ef_1 = int(0);

#line 92
    }
    else
    {

#line 92
        sh_0 = 29U;

#line 92
        ef_1 = ef_0;

#line 92
    }



    if(sh_0 > 63U)
    {

#line 96
        sh_0 = 63U;

#line 96
    }


    ulong _S19 = ulong(sh_0);

#line 99
    ulong q_1 = m_4 >> _S19;
    ulong rem_1 = m_4 & ((1ULL << _S19) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - 1U);
    if(rem_1 > half_0)
    {

#line 102
        _S18 = true;

#line 102
    }
    else
    {

#line 102
        if(rem_1 == half_0)
        {

#line 102
            _S18 = (q_1 & 1ULL) != 0ULL;

#line 102
        }
        else
        {

#line 102
            _S18 = false;

#line 102
        }

#line 102
    }

#line 102
    if(_S18)
    {

#line 102
        q_0 = q_1 + 1ULL;

#line 102
    }
    else
    {

#line 102
        q_0 = q_1;

#line 102
    }


    if(ef_1 == int(0))
    {

#line 106
        return (as_type<float>(((s_3 << 31U) | uint(q_0))));
    }
    if((q_0 >> 24ULL) != 0ULL)
    {

#line 109
        ulong _S20 = q_0 >> 1ULL;

#line 109
        ef_1 = ef_1 + int(1);

#line 109
        q_0 = _S20;

#line 108
    }



    if(ef_1 >= int(255))
    {

#line 113
        return (as_type<float>(((s_3 << 31U) | 2139095040U)));
    }
    return (as_type<float>((((s_3 << 31U) | (uint(ef_1) << 23U)) | uint(q_0 & 8388607ULL))));
}


#line 482
struct KernelContext_0
{
    uint device* p_1;
    uint device* y_0;
    float device* erffTable_0;
};


#line 462
float platform_erff_0(float x_3, KernelContext_0 thread* kernelContext_0)
{

#line 463
    uint xb_0 = (as_type<uint>((x_3)));
    uint w9_0 = xb_0 & 2147483647U;
    float ax_0 = (as_type<float>((w9_0)));
    if((w9_0 >> 23U) > 254U)
    {

#line 467
        if(w9_0 == 2139095040U)
        {

#line 468
            return (as_type<float>(((xb_0 & 2147483648U) | 1065353216U)));
        }
        return (as_type<float>((xb_0 | 4194304U)));
    }
    if(w9_0 > 1046609920U)
    {

#line 473
        uint sg_0 = xb_0 & 2147483648U;
        if(w9_0 > 1081791743U)
        {

#line 475
            return (as_type<float>((sg_0 | (as_type<uint>(((as_type<float>((1065353216U))) - (as_type<float>((8388608U)))))))));
        }
        float tt_0 = ax_0 + (as_type<float>((1237319680U)));

        uint ix_0 = ((as_type<uint>((tt_0))) & 31U) * 8U;
        float r_0 = ax_0 - (tt_0 + (as_type<float>((3384803328U))));

#line 489
        return (as_type<float>((sg_0 | (as_type<uint>((kernelContext_0->erffTable_0[ix_0] + fma(r_0, kernelContext_0->erffTable_0[ix_0 + 2U], fma(r_0, fma(r_0, fma(r_0 * r_0, fma(r_0, kernelContext_0->erffTable_0[ix_0 + 7U], kernelContext_0->erffTable_0[ix_0 + 6U]), fma(r_0, kernelContext_0->erffTable_0[ix_0 + 5U], kernelContext_0->erffTable_0[ix_0 + 4U])), kernelContext_0->erffTable_0[ix_0 + 3U]), kernelContext_0->erffTable_0[ix_0 + 1U]))))))));
    }
    if(w9_0 > 619091348U)
    {

#line 492
        float x2_0 = x_3 * x_3;

#line 497
        return fma(x_3, (as_type<float>((1066430139U))), x_3 * fma(x2_0, fma(x2_0, fma(x2_0, (as_type<float>((3168266449U))), (as_type<float>((1038552905U)))), (as_type<float>((3200291742U)))), (as_type<float>((3011311510U)))));
    }
    return f64_to_f32_0(f64_mul_0(f64_from_f32_0(x_3), 4607760587169110893ULL));
}


[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_2 [[buffer(1)]], uint device* y_1 [[buffer(2)]], float device* erffTable_1 [[buffer(0)]])
{

#line 503
    thread KernelContext_0 kernelContext_1;

#line 503
    (&kernelContext_1)->p_1 = p_2;

#line 503
    (&kernelContext_1)->y_0 = y_1;

#line 503
    (&kernelContext_1)->erffTable_0 = erffTable_1;
    uint t_0 = tid_0.x;
    if(t_0 >= p_2[1U])
    {

#line 506
        return;
    }
    uint device* _S21 = (&kernelContext_1)->y_0+t_0;

#line 508
    float _S22 = platform_erff_0((as_type<float>(((&kernelContext_1)->p_1[0U] + t_0))), &kernelContext_1);

#line 508
    *_S21 = (as_type<uint>((_S22)));
    return;
}

