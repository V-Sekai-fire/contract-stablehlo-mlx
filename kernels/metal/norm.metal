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


#line 50 "kernels/slang/norm.slang"
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


#line 118
ulong f64_add_0(ulong a_0, ulong b_1)
{

#line 119
    ulong _S7 = a_0 & 9223372036854775807ULL;

#line 119
    if(_S7 > 9218868437227405312ULL)
    {

#line 120
        return a_0 | 2251799813685248ULL;
    }
    ulong _S8 = b_1 & 9223372036854775807ULL;

#line 122
    if(_S8 > 9218868437227405312ULL)
    {

#line 123
        return b_1 | 2251799813685248ULL;
    }

#line 123
    bool _S9;

    if(_S7 == 9218868437227405312ULL)
    {

#line 126
        if(_S8 == 9218868437227405312ULL)
        {

#line 126
            _S9 = a_0 != b_1;

#line 126
        }
        else
        {

#line 126
            _S9 = false;

#line 126
        }

#line 126
        if(_S9)
        {

#line 127
            return 9221120237041090560ULL;
        }
        return a_0;
    }
    if(_S8 == 9218868437227405312ULL)
    {

#line 132
        return b_1;
    }
    if(_S7 == 0ULL)
    {

#line 135
        if(_S8 == 0ULL)
        {

#line 136
            return a_0 & b_1;
        }
        return b_1;
    }
    if(_S8 == 0ULL)
    {

#line 141
        return a_0;
    }
    ulong sa_0 = a_0 >> 63ULL;
    ulong sb_0 = b_1 >> 63ULL;
    int ae_0 = int((a_0 >> 52ULL) & 2047ULL);
    ulong am_0 = a_0 & 4503599627370495ULL;

#line 146
    ulong am_1;

#line 146
    int ae_1;
    if(ae_0 == int(0))
    {
        int _S10 = int(52) - hibit64_0(am_0);
        int _S11 = int(1) - _S10;

#line 150
        am_1 = am_0 << ulong(_S10);

#line 150
        ae_1 = _S11;

#line 147
    }
    else
    {

#line 147
        am_1 = am_0 | 4503599627370496ULL;

#line 147
        ae_1 = ae_0;

#line 147
    }

#line 154
    int be_0 = int((b_1 >> 52ULL) & 2047ULL);
    ulong bm_0 = b_1 & 4503599627370495ULL;

#line 155
    ulong bm_1;

#line 155
    int be_1;
    if(be_0 == int(0))
    {
        int _S12 = int(52) - hibit64_0(bm_0);
        int _S13 = int(1) - _S12;

#line 159
        bm_1 = bm_0 << ulong(_S12);

#line 159
        be_1 = _S13;

#line 156
    }
    else
    {

#line 156
        bm_1 = bm_0 | 4503599627370496ULL;

#line 156
        be_1 = be_0;

#line 156
    }

#line 163
    ulong am_2 = am_1 << 9ULL;
    ulong bm_2 = bm_1 << 9ULL;
    if(ae_1 < be_1)
    {

#line 165
        _S9 = true;

#line 165
    }
    else
    {

#line 165
        if(ae_1 == be_1)
        {

#line 165
            _S9 = am_2 < bm_2;

#line 165
        }
        else
        {

#line 165
            _S9 = false;

#line 165
        }

#line 165
    }

#line 165
    ulong sa_1;

#line 165
    ulong sb_1;

#line 165
    if(_S9)
    {

#line 145
        int _S14 = ae_1;

#line 145
        bm_1 = am_2;

#line 145
        ae_1 = be_1;

#line 145
        be_1 = _S14;

#line 145
        sa_1 = sb_0;

#line 145
        sb_1 = sa_0;

#line 145
        am_1 = bm_2;

#line 165
    }
    else
    {

#line 165
        bm_1 = bm_2;

#line 165
        sa_1 = sa_0;

#line 165
        sb_1 = sb_0;

#line 165
        am_1 = am_2;

#line 165
    }

#line 176
    ulong bm_3 = srs_0(bm_1, uint(ae_1 - be_1));

#line 176
    ulong m_2;
    if(sa_1 == sb_1)
    {

#line 177
        m_2 = am_1 + bm_3;

#line 177
    }
    else
    {

#line 177
        m_2 = am_1 - bm_3;

#line 177
    }
    if(m_2 == 0ULL)
    {

#line 179
        return 0ULL;
    }

    int h_0 = hibit64_0(m_2);

#line 182
    int e_2;
    if(h_0 > int(61))
    {

#line 184
        ulong _S15 = srs_0(m_2, 1U);

#line 184
        e_2 = ae_1 + int(1);

#line 184
        m_2 = _S15;

#line 183
    }
    else
    {

        int _S16 = int(61) - h_0;

#line 187
        ulong _S17 = m_2 << ulong(_S16);

#line 187
        e_2 = ae_1 - _S16;

#line 187
        m_2 = _S17;

#line 183
    }

#line 190
    return pack64_0(sa_1, e_2, m_2);
}


#line 76
float f64_to_f32_0(ulong d_0)
{

#line 77
    uint s_2 = uint(d_0 >> 63ULL);
    int e_3 = int((d_0 >> 52ULL) & 2047ULL);
    ulong f_1 = d_0 & 4503599627370495ULL;

#line 79
    uint sh_0;
    if(e_3 == int(2047))
    {

#line 81
        uint _S18 = (s_2 << 31U) | 2139095040U;

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
        return (as_type<float>((_S18 | sh_0)));
    }
    bool _S19 = e_3 == int(0);

#line 83
    bool _S20;

#line 83
    if(_S19)
    {

#line 83
        _S20 = f_1 == 0ULL;

#line 83
    }
    else
    {

#line 83
        _S20 = false;

#line 83
    }

#line 83
    if(_S20)
    {

#line 84
        return (as_type<float>((s_2 << 31U)));
    }

#line 84
    ulong q_0;

    if(e_3 != int(0))
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
    ulong m_3 = f_1 | q_0;

#line 86
    int e_4;
    if(_S19)
    {

#line 87
        e_4 = int(1);

#line 87
    }
    else
    {

#line 87
        e_4 = e_3;

#line 87
    }


    int ef_0 = e_4 - int(896);

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


    ulong _S21 = ulong(sh_0);

#line 99
    ulong q_1 = m_3 >> _S21;
    ulong rem_1 = m_3 & ((1ULL << _S21) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - 1U);
    if(rem_1 > half_0)
    {

#line 102
        _S20 = true;

#line 102
    }
    else
    {

#line 102
        if(rem_1 == half_0)
        {

#line 102
            _S20 = (q_1 & 1ULL) != 0ULL;

#line 102
        }
        else
        {

#line 102
            _S20 = false;

#line 102
        }

#line 102
    }

#line 102
    if(_S20)
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
        return (as_type<float>(((s_2 << 31U) | uint(q_0))));
    }
    if((q_0 >> 24ULL) != 0ULL)
    {

#line 109
        ulong _S22 = q_0 >> 1ULL;

#line 109
        ef_1 = ef_1 + int(1);

#line 109
        q_0 = _S22;

#line 108
    }



    if(ef_1 >= int(255))
    {

#line 113
        return (as_type<float>(((s_2 << 31U) | 2139095040U)));
    }
    return (as_type<float>((((s_2 << 31U) | (uint(ef_1) << 23U)) | uint(q_0 & 8388607ULL))));
}


#line 239
ulong f64_div_0(ulong a_1, ulong b_2)
{

#line 240
    ulong s_3 = (a_1 ^ b_2) >> 63ULL;
    ulong _S23 = a_1 & 9223372036854775807ULL;

#line 241
    if(_S23 > 9218868437227405312ULL)
    {

#line 242
        return a_1 | 2251799813685248ULL;
    }
    ulong _S24 = b_2 & 9223372036854775807ULL;

#line 244
    if(_S24 > 9218868437227405312ULL)
    {

#line 245
        return b_2 | 2251799813685248ULL;
    }
    if(_S23 == 9218868437227405312ULL)
    {

#line 248
        if(_S24 == 9218868437227405312ULL)
        {

#line 249
            return 9221120237041090560ULL;
        }
        return (s_3 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S24 == 9218868437227405312ULL)
    {

#line 254
        return s_3 << 63ULL;
    }
    if(_S24 == 0ULL)
    {

#line 257
        if(_S23 == 0ULL)
        {

#line 258
            return 9221120237041090560ULL;
        }
        return (s_3 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S23 == 0ULL)
    {

#line 263
        return s_3 << 63ULL;
    }
    int ae_2 = int((a_1 >> 52ULL) & 2047ULL);
    ulong am_3 = a_1 & 4503599627370495ULL;

#line 266
    int ae_3;

#line 266
    ulong am_4;
    if(ae_2 == int(0))
    {
        int _S25 = int(52) - hibit64_0(am_3);

#line 269
        ulong _S26 = am_3 << ulong(_S25);

#line 269
        ae_3 = int(1) - _S25;

#line 269
        am_4 = _S26;

#line 267
    }
    else
    {


        ulong _S27 = am_3 | 4503599627370496ULL;

#line 272
        ae_3 = ae_2;

#line 272
        am_4 = _S27;

#line 267
    }

#line 274
    int be_2 = int((b_2 >> 52ULL) & 2047ULL);
    ulong bm_4 = b_2 & 4503599627370495ULL;

#line 275
    int be_3;

#line 275
    ulong bm_5;
    if(be_2 == int(0))
    {
        int _S28 = int(52) - hibit64_0(bm_4);

#line 278
        ulong _S29 = bm_4 << ulong(_S28);

#line 278
        be_3 = int(1) - _S28;

#line 278
        bm_5 = _S29;

#line 276
    }
    else
    {


        ulong _S30 = bm_4 | 4503599627370496ULL;

#line 281
        be_3 = be_2;

#line 281
        bm_5 = _S30;

#line 276
    }

#line 283
    int e_5 = ae_3 - be_3 + int(1023);

#line 283
    int e_6;
    if(am_4 < bm_5)
    {
        int _S31 = e_5 - int(1);

#line 286
        am_4 = am_4 << 1ULL;

#line 286
        e_6 = _S31;

#line 284
    }
    else
    {

#line 284
        e_6 = e_5;

#line 284
    }

#line 284
    ulong q_2 = 0ULL;

#line 284
    ulong r_0 = am_4;

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
        ulong q_3 = q_2 << 1ULL;

#line 291
        ulong r_1;
        if(r_0 >= bm_5)
        {
            ulong _S32 = q_3 | 1ULL;

#line 294
            r_1 = r_0 - bm_5;

#line 294
            q_2 = _S32;

#line 292
        }
        else
        {

#line 292
            r_1 = r_0;

#line 292
            q_2 = q_3;

#line 292
        }



        ulong _S33 = r_1 << 1ULL;

#line 290
        uint i_1 = i_0 + 1U;

#line 290
        r_0 = _S33;

#line 290
        i_0 = i_1;

#line 290
    }

#line 298
    ulong _S34 = q_2 << 7ULL;

#line 298
    if(r_0 != 0ULL)
    {

#line 298
        am_4 = 1ULL;

#line 298
    }
    else
    {

#line 298
        am_4 = 0ULL;

#line 298
    }
    return pack64_0(s_3, e_6, _S34 | am_4);
}

float f32_div_0(float a_2, float b_3)
{

#line 303
    return f64_to_f32_0(f64_div_0(f64_from_f32_0(a_2), f64_from_f32_0(b_3)));
}


#line 68
ulong f64_from_u32_0(uint n_1)
{

#line 69
    if(n_1 == 0U)
    {

#line 70
        return 0ULL;
    }
    uint p_1 = firstbithigh_0(n_1);
    return (ulong(p_1 + 1023U) << 52ULL) | ((ulong(n_1) << ulong(52U - p_1)) & 4503599627370495ULL);
}


#line 306
float f32_sqrt_0(float x_3)
{

#line 307
    uint b_4 = (as_type<uint>((x_3)));
    if((b_4 & 2147483647U) == 0U)
    {

#line 309
        return x_3;
    }
    if((b_4 >> 31U) != 0U)
    {

#line 312
        return (as_type<float>((2143289344U)));
    }
    if(b_4 >= 2139095040U)
    {

#line 315
        return x_3;
    }
    int e_7 = int(b_4 >> 23U);
    uint m_4 = b_4 & 8388607U;

#line 318
    int e_8;

#line 318
    uint m_5;
    if(e_7 == int(0))
    {
        int _S35 = int(23) - int(firstbithigh_0(m_4));

#line 321
        uint _S36 = m_4 << uint(_S35);

#line 321
        e_8 = int(1) - _S35;

#line 321
        m_5 = _S36;

#line 319
    }
    else
    {


        uint _S37 = m_4 | 8388608U;

#line 324
        e_8 = e_7;

#line 324
        m_5 = _S37;

#line 319
    }

#line 326
    int k_0 = e_8 - int(150);
    ulong w_0 = ulong(m_5);

#line 327
    int k_1;

#line 327
    ulong w_1;
    if((k_0 & int(1)) != int(0))
    {
        int _S38 = k_0 - int(1);

#line 330
        w_1 = w_0 << 1ULL;

#line 330
        k_1 = _S38;

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



    ulong _S39 = w_1 << 38ULL;
    int k_2 = k_1 - int(38);

#line 333
    ulong rem_2 = 0ULL;

#line 333
    w_1 = _S39;

#line 333
    ulong r_2 = 0ULL;

#line 333
    uint i_2 = 0U;


    for(;;)
    {

#line 336
        if(i_2 < 32U)
        {
        }
        else
        {

#line 336
            break;
        }

#line 337
        ulong rem_3 = (rem_2 << 2ULL) | ((w_1 >> 62ULL) & 3ULL);
        ulong _S40 = w_1 << 2ULL;
        ulong t_0 = (r_2 << 2ULL) | 1ULL;
        ulong r_3 = r_2 << 1ULL;
        if(rem_3 >= t_0)
        {
            ulong _S41 = r_3 | 1ULL;

#line 343
            rem_2 = rem_3 - t_0;

#line 343
            r_2 = _S41;

#line 341
        }
        else
        {

#line 341
            rem_2 = rem_3;

#line 341
            r_2 = r_3;

#line 341
        }

#line 336
        uint i_3 = i_2 + 1U;

#line 336
        w_1 = _S40;

#line 336
        i_2 = i_3;

#line 336
    }

#line 347
    int sh_1 = hibit64_0(r_2) - int(23);
    ulong _S42 = ulong(sh_1);

#line 348
    ulong q_4 = r_2 >> _S42;
    ulong lost_0 = r_2 & ((1ULL << _S42) - 1ULL);
    ulong half_1 = 1ULL << ulong(sh_1 - int(1));

#line 350
    bool sticky_0;
    if(rem_2 != 0ULL)
    {

#line 351
        sticky_0 = true;

#line 351
    }
    else
    {

#line 351
        sticky_0 = (lost_0 & (half_1 - 1ULL)) != 0ULL;

#line 351
    }
    if((lost_0 & half_1) != 0ULL)
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
            sticky_0 = (q_4 & 1ULL) != 0ULL;

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
    ulong q_5;

#line 352
    if(sticky_0)
    {

#line 352
        q_5 = q_4 + 1ULL;

#line 352
    }
    else
    {

#line 352
        q_5 = q_4;

#line 352
    }


    int ee_0 = k_2 / int(2) + sh_1 + int(150);

#line 355
    int ee_1;
    if((q_5 >> 24ULL) != 0ULL)
    {

#line 357
        ulong _S43 = q_5 >> 1ULL;

#line 357
        ee_1 = ee_0 + int(1);

#line 357
        q_5 = _S43;

#line 356
    }
    else
    {

#line 356
        ee_1 = ee_0;

#line 356
    }



    return (as_type<float>(((uint(ee_1) << 23U) | uint(q_5 & 8388607ULL))));
}


#line 409
struct KernelContext_0
{
    uint device* p_2;
    float device* x_4;
    float device* y_0;
};


#line 389
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_3 [[buffer(1)]], float device* x_5 [[buffer(0)]], float device* y_1 [[buffer(2)]])
{

#line 389
    thread KernelContext_0 kernelContext_0;

#line 389
    (&kernelContext_0)->p_2 = p_3;

#line 389
    (&kernelContext_0)->x_4 = x_5;

#line 389
    (&kernelContext_0)->y_0 = y_1;
    uint t_1 = tid_0.x;
    if(t_1 >= p_3[1U])
    {

#line 392
        return;
    }
    uint _S44 = t_1 * (&kernelContext_0)->p_2[0U];
    float eps_0 = (as_type<float>(((&kernelContext_0)->p_2[2U])));

#line 395
    uint i_4;
    if((&kernelContext_0)->p_2[3U] != 0U)
    {

#line 397
        float _S45 = (as_type<float>((0U)));

#line 397
        float s_4 = _S45;

#line 397
        i_4 = 0U;
        for(;;)
        {

#line 398
            if(i_4 < ((&kernelContext_0)->p_2)[0U])
            {
            }
            else
            {

#line 398
                break;
            }

#line 399
            float _S46 = s_4 + (&kernelContext_0)->x_4[_S44 + i_4];

#line 398
            uint i_5 = i_4 + 1U;

#line 398
            s_4 = _S46;

#line 398
            i_4 = i_5;

#line 398
        }


        float _S47 = s_4 / float((&kernelContext_0)->p_2[0U]);

#line 401
        float s2_0 = _S45;

#line 401
        i_4 = 0U;

        for(;;)
        {

#line 403
            if(i_4 < ((&kernelContext_0)->p_2)[0U])
            {
            }
            else
            {

#line 403
                break;
            }

#line 404
            float d_1 = (&kernelContext_0)->x_4[_S44 + i_4] - _S47;
            float _S48 = s2_0 + d_1 * d_1;

#line 403
            uint i_6 = i_4 + 1U;

#line 403
            s2_0 = _S48;

#line 403
            i_4 = i_6;

#line 403
        }



        float _S49 = (as_type<float>((1065353216U))) / sqrt(s2_0 / float((&kernelContext_0)->p_2[0U]) + eps_0);

#line 407
        i_4 = 0U;
        for(;;)
        {

#line 408
            if(i_4 < ((&kernelContext_0)->p_2)[0U])
            {
            }
            else
            {

#line 408
                break;
            }

#line 409
            uint _S50 = _S44 + i_4;

#line 409
            *((&kernelContext_0)->y_0+_S50) = ((&kernelContext_0)->x_4[_S50] - _S47) * _S49;

#line 408
            i_4 = i_4 + 1U;

#line 408
        }


        return;
    }

#line 411
    ulong sum_0 = 0ULL;

#line 411
    i_4 = 0U;


    for(;;)
    {

#line 414
        if(i_4 < ((&kernelContext_0)->p_2)[0U])
        {
        }
        else
        {

#line 414
            break;
        }

#line 415
        ulong _S51 = f64_add_0(sum_0, f64_from_f32_0((&kernelContext_0)->x_4[_S44 + i_4]));

#line 414
        uint i_7 = i_4 + 1U;

#line 414
        sum_0 = _S51;

#line 414
        i_4 = i_7;

#line 414
    }


    float _S52 = f32_div_0(f64_to_f32_0(sum_0), float((&kernelContext_0)->p_2[0U]));

    uint nb_0 = (&kernelContext_0)->p_2[0U] & 4294967292U;

#line 419
    ulong s2_1 = 0ULL;

#line 419
    uint g_0 = 0U;
    for(;;)
    {

#line 420
        if(g_0 < (nb_0 / 4U))
        {
        }
        else
        {

#line 420
            break;
        }

#line 421
        uint i_8 = _S44 + g_0 * 4U;
        float d0_0 = (&kernelContext_0)->x_4[i_8] - _S52;
        float d1_0 = (&kernelContext_0)->x_4[i_8 + 1U] - _S52;
        float d2_0 = (&kernelContext_0)->x_4[i_8 + 2U] - _S52;
        float d3_0 = (&kernelContext_0)->x_4[i_8 + 3U] - _S52;

#line 430
        ulong _S53 = f64_add_0(s2_1, f64_from_f32_0(d0_0 * d0_0 + d1_0 * d1_0 + (d2_0 * d2_0 + d3_0 * d3_0)));

#line 420
        uint g_1 = g_0 + 1U;

#line 420
        s2_1 = _S53;

#line 420
        g_0 = g_1;

#line 420
    }

#line 420
    i_4 = nb_0;

#line 432
    for(;;)
    {

#line 432
        if(i_4 < ((&kernelContext_0)->p_2)[0U])
        {
        }
        else
        {

#line 432
            break;
        }

#line 433
        float d_2 = (&kernelContext_0)->x_4[_S44 + i_4] - _S52;

        ulong _S54 = f64_add_0(s2_1, f64_from_f32_0(d_2 * d_2));

#line 432
        uint i_9 = i_4 + 1U;

#line 432
        s2_1 = _S54;

#line 432
        i_4 = i_9;

#line 432
    }

#line 438
    float _S55 = f32_div_0((as_type<float>((1065353216U))), f32_sqrt_0(f64_to_f32_0(f64_div_0(s2_1, f64_from_u32_0((&kernelContext_0)->p_2[0U]))) + eps_0));

#line 438
    i_4 = 0U;
    for(;;)
    {

#line 439
        if(i_4 < ((&kernelContext_0)->p_2)[0U])
        {
        }
        else
        {

#line 439
            break;
        }

#line 440
        uint _S56 = _S44 + i_4;

#line 440
        *((&kernelContext_0)->y_0+_S56) = ((&kernelContext_0)->x_4[_S56] - _S52) * _S55;

#line 439
        i_4 = i_4 + 1U;

#line 439
    }


    return;
}

