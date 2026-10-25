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


#line 52 "kernels/slang/divide.slang"
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


#line 241
ulong f64_div_0(ulong a_0, ulong b_1)
{

#line 242
    ulong s_2 = (a_0 ^ b_1) >> 63ULL;
    ulong _S7 = a_0 & 9223372036854775807ULL;

#line 243
    if(_S7 > 9218868437227405312ULL)
    {

#line 244
        return a_0 | 2251799813685248ULL;
    }
    ulong _S8 = b_1 & 9223372036854775807ULL;

#line 246
    if(_S8 > 9218868437227405312ULL)
    {

#line 247
        return b_1 | 2251799813685248ULL;
    }
    if(_S7 == 9218868437227405312ULL)
    {

#line 250
        if(_S8 == 9218868437227405312ULL)
        {

#line 251
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S8 == 9218868437227405312ULL)
    {

#line 256
        return s_2 << 63ULL;
    }
    if(_S8 == 0ULL)
    {

#line 259
        if(_S7 == 0ULL)
        {

#line 260
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S7 == 0ULL)
    {

#line 265
        return s_2 << 63ULL;
    }
    int ae_0 = int((a_0 >> 52ULL) & 2047ULL);
    ulong am_0 = a_0 & 4503599627370495ULL;

#line 268
    int ae_1;

#line 268
    ulong am_1;
    if(ae_0 == int(0))
    {
        int _S9 = int(52) - hibit64_0(am_0);

#line 271
        ulong _S10 = am_0 << ulong(_S9);

#line 271
        ae_1 = int(1) - _S9;

#line 271
        am_1 = _S10;

#line 269
    }
    else
    {


        ulong _S11 = am_0 | 4503599627370496ULL;

#line 274
        ae_1 = ae_0;

#line 274
        am_1 = _S11;

#line 269
    }

#line 276
    int be_0 = int((b_1 >> 52ULL) & 2047ULL);
    ulong bm_0 = b_1 & 4503599627370495ULL;

#line 277
    int be_1;

#line 277
    ulong bm_1;
    if(be_0 == int(0))
    {
        int _S12 = int(52) - hibit64_0(bm_0);

#line 280
        ulong _S13 = bm_0 << ulong(_S12);

#line 280
        be_1 = int(1) - _S12;

#line 280
        bm_1 = _S13;

#line 278
    }
    else
    {


        ulong _S14 = bm_0 | 4503599627370496ULL;

#line 283
        be_1 = be_0;

#line 283
        bm_1 = _S14;

#line 278
    }

#line 285
    int e_2 = ae_1 - be_1 + int(1023);

#line 285
    int e_3;
    if(am_1 < bm_1)
    {
        int _S15 = e_2 - int(1);

#line 288
        am_1 = am_1 << 1ULL;

#line 288
        e_3 = _S15;

#line 286
    }
    else
    {

#line 286
        e_3 = e_2;

#line 286
    }

#line 286
    ulong q_0 = 0ULL;

#line 286
    ulong r_0 = am_1;

#line 286
    uint i_0 = 0U;

#line 292
    for(;;)
    {

#line 292
        if(i_0 < 55U)
        {
        }
        else
        {

#line 292
            break;
        }

#line 293
        ulong q_1 = q_0 << 1ULL;

#line 293
        ulong r_1;
        if(r_0 >= bm_1)
        {
            ulong _S16 = q_1 | 1ULL;

#line 296
            r_1 = r_0 - bm_1;

#line 296
            q_0 = _S16;

#line 294
        }
        else
        {

#line 294
            r_1 = r_0;

#line 294
            q_0 = q_1;

#line 294
        }



        ulong _S17 = r_1 << 1ULL;

#line 292
        uint i_1 = i_0 + 1U;

#line 292
        r_0 = _S17;

#line 292
        i_0 = i_1;

#line 292
    }

#line 300
    ulong _S18 = q_0 << 7ULL;

#line 300
    if(r_0 != 0ULL)
    {

#line 300
        am_1 = 1ULL;

#line 300
    }
    else
    {

#line 300
        am_1 = 0ULL;

#line 300
    }
    return pack64_0(s_2, e_3, _S18 | am_1);
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
        uint _S19 = (s_3 << 31U) | 2139095040U;

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
        return (as_type<float>((_S19 | sh_0)));
    }
    bool _S20 = e_4 == int(0);

#line 85
    bool _S21;

#line 85
    if(_S20)
    {

#line 85
        _S21 = f_1 == 0ULL;

#line 85
    }
    else
    {

#line 85
        _S21 = false;

#line 85
    }

#line 85
    if(_S21)
    {

#line 86
        return (as_type<float>((s_3 << 31U)));
    }

#line 86
    ulong q_2;

    if(e_4 != int(0))
    {

#line 88
        q_2 = 4503599627370496ULL;

#line 88
    }
    else
    {

#line 88
        q_2 = 0ULL;

#line 88
    }

#line 88
    ulong m_2 = f_1 | q_2;

#line 88
    int e_5;
    if(_S20)
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


    ulong _S22 = ulong(sh_0);

#line 101
    ulong q_3 = m_2 >> _S22;
    ulong rem_1 = m_2 & ((1ULL << _S22) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - 1U);
    if(rem_1 > half_0)
    {

#line 104
        _S21 = true;

#line 104
    }
    else
    {

#line 104
        if(rem_1 == half_0)
        {

#line 104
            _S21 = (q_3 & 1ULL) != 0ULL;

#line 104
        }
        else
        {

#line 104
            _S21 = false;

#line 104
        }

#line 104
    }

#line 104
    if(_S21)
    {

#line 104
        q_2 = q_3 + 1ULL;

#line 104
    }
    else
    {

#line 104
        q_2 = q_3;

#line 104
    }


    if(ef_1 == int(0))
    {

#line 108
        return (as_type<float>(((s_3 << 31U) | uint(q_2))));
    }
    if((q_2 >> 24ULL) != 0ULL)
    {

#line 111
        ulong _S23 = q_2 >> 1ULL;

#line 111
        ef_1 = ef_1 + int(1);

#line 111
        q_2 = _S23;

#line 110
    }



    if(ef_1 >= int(255))
    {

#line 115
        return (as_type<float>(((s_3 << 31U) | 2139095040U)));
    }
    return (as_type<float>((((s_3 << 31U) | (uint(ef_1) << 23U)) | uint(q_2 & 8388607ULL))));
}


#line 304
float f32_div_0(float a_1, float b_2)
{

#line 305
    return f64_to_f32_0(f64_div_0(f64_from_f32_0(a_1), f64_from_f32_0(b_2)));
}


#line 396
struct KernelContext_0
{
    uint device* p_1;
    float device* y_0;
    float device* a_2;
    float device* b_3;
};


#line 391
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_2 [[buffer(2)]], float device* y_1 [[buffer(3)]], float device* a_3 [[buffer(0)]], float device* b_4 [[buffer(1)]])
{

#line 391
    thread KernelContext_0 kernelContext_0;

#line 391
    (&kernelContext_0)->p_1 = p_2;

#line 391
    (&kernelContext_0)->y_0 = y_1;

#line 391
    (&kernelContext_0)->a_2 = a_3;

#line 391
    (&kernelContext_0)->b_3 = b_4;
    uint t_0 = tid_0.x;
    if(t_0 >= p_2[0U])
    {

#line 394
        return;
    }
    *((&kernelContext_0)->y_0+t_0) = f32_div_0((&kernelContext_0)->a_2[t_0], (&kernelContext_0)->b_3[t_0]);
    return;
}

