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


#line 363 "kernels/slang/silu.slang"
float ggml_v_expf_0(float x_0)
{

#line 364
    float r_0 = (as_type<float>((1262485504U)));
    float z_0 = fma(x_0, (as_type<float>((1069066811U))), r_0);
    float n_0 = z_0 - r_0;
    float _S2 = - n_0;

#line 367
    float b_0 = fma(_S2, (as_type<float>((901758606U))), fma(_S2, (as_type<float>((1060205056U))), x_0));
    uint e_0 = (as_type<uint>((z_0))) << 23U;
    float k_0 = (as_type<float>((e_0 + 1065353216U)));
    float uu_0 = b_0 * b_0;



    float j_0 = fma(fma(fma((as_type<float>((1007099920U))), b_0, (as_type<float>((1026268951U)))), uu_0, fma((as_type<float>((1042984755U))), b_0, (as_type<float>((1056964315U))))), uu_0, (as_type<float>((1065353206U))) * b_0);
    float an_0 = abs(n_0);

#line 375
    uint d_0;
    if(n_0 <= (as_type<float>((0U))))
    {

#line 376
        d_0 = 2181038080U;

#line 376
    }
    else
    {

#line 376
        d_0 = 0U;

#line 376
    }
    float s1_0 = (as_type<float>((d_0 + 2130706432U)));
    if(an_0 > (as_type<float>((1128267776U))))
    {

#line 379
        return s1_0 * s1_0;
    }
    if(an_0 > (as_type<float>((1123811328U))))
    {

#line 382
        float s2_0 = (as_type<float>((e_0 - d_0)));
        return fma(s2_0, j_0, s2_0) * s1_0;
    }
    return fma(k_0, j_0, k_0);
}


#line 50
ulong f64_from_f32_0(float x_1)
{

#line 51
    uint b_1 = (as_type<uint>((x_1)));
    ulong s_0 = ulong(b_1 >> 31U);
    uint e_1 = (b_1 >> 23U) & 255U;
    uint f_0 = b_1 & 8388607U;
    if(e_1 == 255U)
    {

#line 56
        return ((s_0 << 63ULL) | 9218868437227405312ULL) | (ulong(f_0) << 29ULL);
    }
    if(e_1 == 0U)
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
    return ((s_0 << 63ULL) | (ulong(e_1 + 896U) << 52ULL)) | (ulong(f_0) << 29ULL);
}


#line 8
int hibit64_0(ulong x_2)
{

#line 9
    uint hi_0 = uint(x_2 >> 32ULL);
    if(hi_0 != 0U)
    {

#line 11
        return int(firstbithigh_0(hi_0)) + int(32);
    }
    return int(firstbithigh_0(uint(x_2 & 4294967295ULL)));
}

ulong srs_0(ulong x_3, uint n_1)
{

#line 17
    if(n_1 == 0U)
    {

#line 18
        return x_3;
    }

#line 18
    ulong _S3;

    if(n_1 >= 63U)
    {

#line 21
        if(x_3 != 0ULL)
        {

#line 21
            _S3 = 1ULL;

#line 21
        }
        else
        {

#line 21
            _S3 = 0ULL;

#line 21
        }

#line 21
        return _S3;
    }
    ulong _S4 = ulong(n_1);
    ulong _S5 = x_3 >> _S4;

#line 24
    if((x_3 & ((1ULL << _S4) - 1ULL)) != 0ULL)
    {

#line 24
        _S3 = 1ULL;

#line 24
    }
    else
    {

#line 24
        _S3 = 0ULL;

#line 24
    }

#line 24
    return _S5 | _S3;
}

ulong pack64_0(ulong s_1, int e0_0, ulong m0_0)
{

#line 27
    ulong m_0;

#line 27
    int e_2;


    if(e0_0 < int(1))
    {

#line 30
        m_0 = srs_0(m0_0, uint(int(1) - e0_0));

#line 30
        e_2 = int(1);

#line 30
    }
    else
    {

#line 30
        m_0 = m0_0;

#line 30
        e_2 = e0_0;

#line 30
    }



    ulong rem_0 = m_0 & 511ULL;
    ulong m_1 = m_0 >> 9ULL;

#line 35
    bool _S6;
    if(rem_0 > 256ULL)
    {

#line 36
        _S6 = true;

#line 36
    }
    else
    {

#line 36
        if(rem_0 == 256ULL)
        {

#line 36
            _S6 = (m_1 & 1ULL) != 0ULL;

#line 36
        }
        else
        {

#line 36
            _S6 = false;

#line 36
        }

#line 36
    }

#line 36
    if(_S6)
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
        ulong _S7 = m_0 >> 1ULL;

#line 40
        e_2 = e_2 + int(1);

#line 40
        m_0 = _S7;

#line 39
    }



    if(e_2 >= int(2047))
    {

#line 44
        return (s_1 << 63ULL) | 9218868437227405312ULL;
    }

#line 44
    ulong field_0;

    if((m_0 >> 52ULL) != 0ULL)
    {

#line 46
        field_0 = ulong(e_2);

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


#line 239
ulong f64_div_0(ulong a_0, ulong b_2)
{

#line 240
    ulong s_2 = (a_0 ^ b_2) >> 63ULL;
    ulong _S8 = a_0 & 9223372036854775807ULL;

#line 241
    if(_S8 > 9218868437227405312ULL)
    {

#line 242
        return a_0 | 2251799813685248ULL;
    }
    ulong _S9 = b_2 & 9223372036854775807ULL;

#line 244
    if(_S9 > 9218868437227405312ULL)
    {

#line 245
        return b_2 | 2251799813685248ULL;
    }
    if(_S8 == 9218868437227405312ULL)
    {

#line 248
        if(_S9 == 9218868437227405312ULL)
        {

#line 249
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S9 == 9218868437227405312ULL)
    {

#line 254
        return s_2 << 63ULL;
    }
    if(_S9 == 0ULL)
    {

#line 257
        if(_S8 == 0ULL)
        {

#line 258
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S8 == 0ULL)
    {

#line 263
        return s_2 << 63ULL;
    }
    int ae_0 = int((a_0 >> 52ULL) & 2047ULL);
    ulong am_0 = a_0 & 4503599627370495ULL;

#line 266
    int ae_1;

#line 266
    ulong am_1;
    if(ae_0 == int(0))
    {
        int _S10 = int(52) - hibit64_0(am_0);

#line 269
        ulong _S11 = am_0 << ulong(_S10);

#line 269
        ae_1 = int(1) - _S10;

#line 269
        am_1 = _S11;

#line 267
    }
    else
    {


        ulong _S12 = am_0 | 4503599627370496ULL;

#line 272
        ae_1 = ae_0;

#line 272
        am_1 = _S12;

#line 267
    }

#line 274
    int be_0 = int((b_2 >> 52ULL) & 2047ULL);
    ulong bm_0 = b_2 & 4503599627370495ULL;

#line 275
    int be_1;

#line 275
    ulong bm_1;
    if(be_0 == int(0))
    {
        int _S13 = int(52) - hibit64_0(bm_0);

#line 278
        ulong _S14 = bm_0 << ulong(_S13);

#line 278
        be_1 = int(1) - _S13;

#line 278
        bm_1 = _S14;

#line 276
    }
    else
    {


        ulong _S15 = bm_0 | 4503599627370496ULL;

#line 281
        be_1 = be_0;

#line 281
        bm_1 = _S15;

#line 276
    }

#line 283
    int e_3 = ae_1 - be_1 + int(1023);

#line 283
    int e_4;
    if(am_1 < bm_1)
    {
        int _S16 = e_3 - int(1);

#line 286
        am_1 = am_1 << 1ULL;

#line 286
        e_4 = _S16;

#line 284
    }
    else
    {

#line 284
        e_4 = e_3;

#line 284
    }

#line 284
    ulong q_0 = 0ULL;

#line 284
    ulong r_1 = am_1;

#line 284
    uint i_0 = 0U;

#line 290
    for(;;)
    {

#line 290
        if(i_0 < 55U)
        {
        }
        else
        {

#line 290
            break;
        }

#line 291
        ulong q_1 = q_0 << 1ULL;

#line 291
        ulong r_2;
        if(r_1 >= bm_1)
        {
            ulong _S17 = q_1 | 1ULL;

#line 294
            r_2 = r_1 - bm_1;

#line 294
            q_0 = _S17;

#line 292
        }
        else
        {

#line 292
            r_2 = r_1;

#line 292
            q_0 = q_1;

#line 292
        }



        ulong _S18 = r_2 << 1ULL;

#line 290
        uint i_1 = i_0 + 1U;

#line 290
        r_1 = _S18;

#line 290
        i_0 = i_1;

#line 290
    }

#line 298
    ulong _S19 = q_0 << 7ULL;

#line 298
    if(r_1 != 0ULL)
    {

#line 298
        am_1 = 1ULL;

#line 298
    }
    else
    {

#line 298
        am_1 = 0ULL;

#line 298
    }
    return pack64_0(s_2, e_4, _S19 | am_1);
}


#line 76
float f64_to_f32_0(ulong d_1)
{

#line 77
    uint s_3 = uint(d_1 >> 63ULL);
    int e_5 = int((d_1 >> 52ULL) & 2047ULL);
    ulong f_1 = d_1 & 4503599627370495ULL;

#line 79
    uint sh_0;
    if(e_5 == int(2047))
    {

#line 81
        uint _S20 = (s_3 << 31U) | 2139095040U;

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
        return (as_type<float>((_S20 | sh_0)));
    }
    bool _S21 = e_5 == int(0);

#line 83
    bool _S22;

#line 83
    if(_S21)
    {

#line 83
        _S22 = f_1 == 0ULL;

#line 83
    }
    else
    {

#line 83
        _S22 = false;

#line 83
    }

#line 83
    if(_S22)
    {

#line 84
        return (as_type<float>((s_3 << 31U)));
    }

#line 84
    ulong q_2;

    if(e_5 != int(0))
    {

#line 86
        q_2 = 4503599627370496ULL;

#line 86
    }
    else
    {

#line 86
        q_2 = 0ULL;

#line 86
    }

#line 86
    ulong m_2 = f_1 | q_2;

#line 86
    int e_6;
    if(_S21)
    {

#line 87
        e_6 = int(1);

#line 87
    }
    else
    {

#line 87
        e_6 = e_5;

#line 87
    }


    int ef_0 = e_6 - int(896);

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


    ulong _S23 = ulong(sh_0);

#line 99
    ulong q_3 = m_2 >> _S23;
    ulong rem_1 = m_2 & ((1ULL << _S23) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - 1U);
    if(rem_1 > half_0)
    {

#line 102
        _S22 = true;

#line 102
    }
    else
    {

#line 102
        if(rem_1 == half_0)
        {

#line 102
            _S22 = (q_3 & 1ULL) != 0ULL;

#line 102
        }
        else
        {

#line 102
            _S22 = false;

#line 102
        }

#line 102
    }

#line 102
    if(_S22)
    {

#line 102
        q_2 = q_3 + 1ULL;

#line 102
    }
    else
    {

#line 102
        q_2 = q_3;

#line 102
    }


    if(ef_1 == int(0))
    {

#line 106
        return (as_type<float>(((s_3 << 31U) | uint(q_2))));
    }
    if((q_2 >> 24ULL) != 0ULL)
    {

#line 109
        ulong _S24 = q_2 >> 1ULL;

#line 109
        ef_1 = ef_1 + int(1);

#line 109
        q_2 = _S24;

#line 108
    }



    if(ef_1 >= int(255))
    {

#line 113
        return (as_type<float>(((s_3 << 31U) | 2139095040U)));
    }
    return (as_type<float>((((s_3 << 31U) | (uint(ef_1) << 23U)) | uint(q_2 & 8388607ULL))));
}


#line 302
float f32_div_0(float a_1, float b_3)
{

#line 303
    return f64_to_f32_0(f64_div_0(f64_from_f32_0(a_1), f64_from_f32_0(b_3)));
}


#line 396
struct KernelContext_0
{
    uint device* p_1;
    float device* x_4;
    float device* y_0;
};


#line 389
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_2 [[buffer(1)]], float device* x_5 [[buffer(0)]], float device* y_1 [[buffer(2)]])
{

#line 389
    thread KernelContext_0 kernelContext_0;

#line 389
    (&kernelContext_0)->p_1 = p_2;

#line 389
    (&kernelContext_0)->x_4 = x_5;

#line 389
    (&kernelContext_0)->y_0 = y_1;
    uint t_0 = tid_0.x;
    if(t_0 >= p_2[0U])
    {

#line 392
        return;
    }
    float xv_0 = (&kernelContext_0)->x_4[t_0];
    if((&kernelContext_0)->p_1[1U] != 0U)
    {

#line 396
        *((&kernelContext_0)->y_0+t_0) = xv_0 / ((as_type<float>((1065353216U))) + exp(- xv_0));
        return;
    }
    *((&kernelContext_0)->y_0+t_0) = f32_div_0(xv_0, (as_type<float>((1065353216U))) + ggml_v_expf_0((as_type<float>((0U))) - xv_0));
    return;
}

