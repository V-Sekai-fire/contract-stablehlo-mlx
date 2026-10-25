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


#line 10 "kernels/slang/f64_ew.slang"
int hibit64_0(ulong x_0)
{

#line 11
    uint hi_0 = uint(x_0 >> 32ULL);
    if(hi_0 != 0U)
    {

#line 13
        return int(firstbithigh_0(hi_0)) + int(32);
    }
    return int(firstbithigh_0(uint(x_0 & 4294967295ULL)));
}

ulong srs_0(ulong x_1, uint n_0)
{

#line 19
    if(n_0 == 0U)
    {

#line 20
        return x_1;
    }

#line 20
    ulong _S2;

    if(n_0 >= 63U)
    {

#line 23
        if(x_1 != 0ULL)
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
    ulong _S4 = x_1 >> _S3;

#line 26
    if((x_1 & ((1ULL << _S3) - 1ULL)) != 0ULL)
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

ulong pack64_0(ulong s_0, int e0_0, ulong m0_0)
{

#line 29
    ulong m_0;

#line 29
    int e_0;


    if(e0_0 < int(1))
    {

#line 32
        m_0 = srs_0(m0_0, uint(int(1) - e0_0));

#line 32
        e_0 = int(1);

#line 32
    }
    else
    {

#line 32
        m_0 = m0_0;

#line 32
        e_0 = e0_0;

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
        e_0 = e_0 + int(1);

#line 42
        m_0 = _S6;

#line 41
    }



    if(e_0 >= int(2047))
    {

#line 46
        return (s_0 << 63ULL) | 9218868437227405312ULL;
    }

#line 46
    ulong field_0;

    if((m_0 >> 52ULL) != 0ULL)
    {

#line 48
        field_0 = ulong(e_0);

#line 48
    }
    else
    {

#line 48
        field_0 = 0ULL;

#line 48
    }
    return ((s_0 << 63ULL) | (field_0 << 52ULL)) | (m_0 & 4503599627370495ULL);
}


#line 120
ulong f64_add_0(ulong a_0, ulong b_0)
{

#line 121
    ulong _S7 = a_0 & 9223372036854775807ULL;

#line 121
    if(_S7 > 9218868437227405312ULL)
    {

#line 122
        return a_0 | 2251799813685248ULL;
    }
    ulong _S8 = b_0 & 9223372036854775807ULL;

#line 124
    if(_S8 > 9218868437227405312ULL)
    {

#line 125
        return b_0 | 2251799813685248ULL;
    }

#line 125
    bool _S9;

    if(_S7 == 9218868437227405312ULL)
    {

#line 128
        if(_S8 == 9218868437227405312ULL)
        {

#line 128
            _S9 = a_0 != b_0;

#line 128
        }
        else
        {

#line 128
            _S9 = false;

#line 128
        }

#line 128
        if(_S9)
        {

#line 129
            return 9221120237041090560ULL;
        }
        return a_0;
    }
    if(_S8 == 9218868437227405312ULL)
    {

#line 134
        return b_0;
    }
    if(_S7 == 0ULL)
    {

#line 137
        if(_S8 == 0ULL)
        {

#line 138
            return a_0 & b_0;
        }
        return b_0;
    }
    if(_S8 == 0ULL)
    {

#line 143
        return a_0;
    }
    ulong sa_0 = a_0 >> 63ULL;
    ulong sb_0 = b_0 >> 63ULL;
    int ae_0 = int((a_0 >> 52ULL) & 2047ULL);
    ulong am_0 = a_0 & 4503599627370495ULL;

#line 148
    ulong am_1;

#line 148
    int ae_1;
    if(ae_0 == int(0))
    {
        int _S10 = int(52) - hibit64_0(am_0);
        int _S11 = int(1) - _S10;

#line 152
        am_1 = am_0 << ulong(_S10);

#line 152
        ae_1 = _S11;

#line 149
    }
    else
    {

#line 149
        am_1 = am_0 | 4503599627370496ULL;

#line 149
        ae_1 = ae_0;

#line 149
    }

#line 156
    int be_0 = int((b_0 >> 52ULL) & 2047ULL);
    ulong bm_0 = b_0 & 4503599627370495ULL;

#line 157
    ulong bm_1;

#line 157
    int be_1;
    if(be_0 == int(0))
    {
        int _S12 = int(52) - hibit64_0(bm_0);
        int _S13 = int(1) - _S12;

#line 161
        bm_1 = bm_0 << ulong(_S12);

#line 161
        be_1 = _S13;

#line 158
    }
    else
    {

#line 158
        bm_1 = bm_0 | 4503599627370496ULL;

#line 158
        be_1 = be_0;

#line 158
    }

#line 165
    ulong am_2 = am_1 << 9ULL;
    ulong bm_2 = bm_1 << 9ULL;
    if(ae_1 < be_1)
    {

#line 167
        _S9 = true;

#line 167
    }
    else
    {

#line 167
        if(ae_1 == be_1)
        {

#line 167
            _S9 = am_2 < bm_2;

#line 167
        }
        else
        {

#line 167
            _S9 = false;

#line 167
        }

#line 167
    }

#line 167
    ulong sa_1;

#line 167
    ulong sb_1;

#line 167
    if(_S9)
    {

#line 147
        int _S14 = ae_1;

#line 147
        bm_1 = am_2;

#line 147
        ae_1 = be_1;

#line 147
        be_1 = _S14;

#line 147
        sa_1 = sb_0;

#line 147
        sb_1 = sa_0;

#line 147
        am_1 = bm_2;

#line 167
    }
    else
    {

#line 167
        bm_1 = bm_2;

#line 167
        sa_1 = sa_0;

#line 167
        sb_1 = sb_0;

#line 167
        am_1 = am_2;

#line 167
    }

#line 178
    ulong bm_3 = srs_0(bm_1, uint(ae_1 - be_1));

#line 178
    ulong m_2;
    if(sa_1 == sb_1)
    {

#line 179
        m_2 = am_1 + bm_3;

#line 179
    }
    else
    {

#line 179
        m_2 = am_1 - bm_3;

#line 179
    }
    if(m_2 == 0ULL)
    {

#line 181
        return 0ULL;
    }

    int h_0 = hibit64_0(m_2);

#line 184
    int e_1;
    if(h_0 > int(61))
    {

#line 186
        ulong _S15 = srs_0(m_2, 1U);

#line 186
        e_1 = ae_1 + int(1);

#line 186
        m_2 = _S15;

#line 185
    }
    else
    {

        int _S16 = int(61) - h_0;

#line 189
        ulong _S17 = m_2 << ulong(_S16);

#line 189
        e_1 = ae_1 - _S16;

#line 189
        m_2 = _S17;

#line 185
    }

#line 192
    return pack64_0(sa_1, e_1, m_2);
}


#line 380
ulong f64_sub_0(ulong a_1, ulong b_1)
{

#line 381
    if((a_1 & 9223372036854775807ULL) > 9218868437227405312ULL)
    {

#line 382
        return a_1 | 2251799813685248ULL;
    }
    if((b_1 & 9223372036854775807ULL) > 9218868437227405312ULL)
    {

#line 385
        return b_1 | 2251799813685248ULL;
    }
    return f64_add_0(a_1, b_1 ^ 9223372036854775808ULL);
}


#line 195
ulong f64_mul_0(ulong a_2, ulong b_2)
{

#line 196
    ulong s_1 = (a_2 ^ b_2) >> 63ULL;
    ulong _S18 = a_2 & 9223372036854775807ULL;

#line 197
    if(_S18 > 9218868437227405312ULL)
    {

#line 198
        return a_2 | 2251799813685248ULL;
    }
    ulong _S19 = b_2 & 9223372036854775807ULL;

#line 200
    if(_S19 > 9218868437227405312ULL)
    {

#line 201
        return b_2 | 2251799813685248ULL;
    }
    if(_S18 == 9218868437227405312ULL)
    {

#line 204
        if(_S19 == 0ULL)
        {

#line 205
            return 9221120237041090560ULL;
        }
        return (s_1 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S19 == 9218868437227405312ULL)
    {

#line 210
        if(_S18 == 0ULL)
        {

#line 211
            return 9221120237041090560ULL;
        }
        return (s_1 << 63ULL) | 9218868437227405312ULL;
    }

#line 213
    bool _S20;

    if(_S18 == 0ULL)
    {

#line 215
        _S20 = true;

#line 215
    }
    else
    {

#line 215
        _S20 = _S19 == 0ULL;

#line 215
    }

#line 215
    if(_S20)
    {

#line 216
        return s_1 << 63ULL;
    }
    int ae_2 = int((a_2 >> 52ULL) & 2047ULL);
    ulong am_3 = a_2 & 4503599627370495ULL;

#line 219
    ulong am_4;

#line 219
    int ae_3;
    if(ae_2 == int(0))
    {
        int _S21 = int(52) - hibit64_0(am_3);
        int _S22 = int(1) - _S21;

#line 223
        am_4 = am_3 << ulong(_S21);

#line 223
        ae_3 = _S22;

#line 220
    }
    else
    {

#line 220
        am_4 = am_3 | 4503599627370496ULL;

#line 220
        ae_3 = ae_2;

#line 220
    }

#line 227
    int be_2 = int((b_2 >> 52ULL) & 2047ULL);
    ulong bm_4 = b_2 & 4503599627370495ULL;

#line 228
    ulong bm_5;

#line 228
    int be_3;
    if(be_2 == int(0))
    {
        int _S23 = int(52) - hibit64_0(bm_4);
        int _S24 = int(1) - _S23;

#line 232
        bm_5 = bm_4 << ulong(_S23);

#line 232
        be_3 = _S24;

#line 229
    }
    else
    {

#line 229
        bm_5 = bm_4 | 4503599627370496ULL;

#line 229
        be_3 = be_2;

#line 229
    }

#line 236
    ulong a0_0 = am_4 & 4294967295ULL;
    ulong a1_0 = am_4 >> 32ULL;
    ulong b0_0 = bm_5 & 4294967295ULL;
    ulong b1_0 = bm_5 >> 32ULL;
    ulong p00_0 = a0_0 * b0_0;
    ulong p01_0 = a0_0 * b1_0;
    ulong p10_0 = a1_0 * b0_0;

    ulong mid_0 = (p00_0 >> 32ULL) + (p01_0 & 4294967295ULL) + (p10_0 & 4294967295ULL);
    ulong lo_0 = (p00_0 & 4294967295ULL) | (mid_0 << 32ULL);

    ulong _S25 = ((a1_0 * b1_0 + (p01_0 >> 32ULL) + (p10_0 >> 32ULL) + (mid_0 >> 32ULL)) << 21ULL) | (lo_0 >> 43ULL);

#line 247
    if((lo_0 & 8796093022207ULL) != 0ULL)
    {

#line 247
        am_4 = 1ULL;

#line 247
    }
    else
    {

#line 247
        am_4 = 0ULL;

#line 247
    }

#line 247
    ulong m_3 = _S25 | am_4;
    int e_2 = ae_3 + be_3 - int(1023);

#line 248
    ulong m_4;

#line 248
    int e_3;
    if((m_3 >> 62ULL) != 0ULL)
    {

#line 250
        ulong _S26 = srs_0(m_3, 1U);

#line 250
        e_3 = e_2 + int(1);

#line 250
        m_4 = _S26;

#line 249
    }
    else
    {

#line 249
        e_3 = e_2;

#line 249
        m_4 = m_3;

#line 249
    }



    return pack64_0(s_1, e_3, m_4);
}

ulong f64_div_0(ulong a_3, ulong b_3)
{

#line 257
    ulong s_2 = (a_3 ^ b_3) >> 63ULL;
    ulong _S27 = a_3 & 9223372036854775807ULL;

#line 258
    if(_S27 > 9218868437227405312ULL)
    {

#line 259
        return a_3 | 2251799813685248ULL;
    }
    ulong _S28 = b_3 & 9223372036854775807ULL;

#line 261
    if(_S28 > 9218868437227405312ULL)
    {

#line 262
        return b_3 | 2251799813685248ULL;
    }
    if(_S27 == 9218868437227405312ULL)
    {

#line 265
        if(_S28 == 9218868437227405312ULL)
        {

#line 266
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S28 == 9218868437227405312ULL)
    {

#line 271
        return s_2 << 63ULL;
    }
    if(_S28 == 0ULL)
    {

#line 274
        if(_S27 == 0ULL)
        {

#line 275
            return 9221120237041090560ULL;
        }
        return (s_2 << 63ULL) | 9218868437227405312ULL;
    }
    if(_S27 == 0ULL)
    {

#line 280
        return s_2 << 63ULL;
    }
    int ae_4 = int((a_3 >> 52ULL) & 2047ULL);
    ulong am_5 = a_3 & 4503599627370495ULL;

#line 283
    int ae_5;

#line 283
    ulong am_6;
    if(ae_4 == int(0))
    {
        int _S29 = int(52) - hibit64_0(am_5);

#line 286
        ulong _S30 = am_5 << ulong(_S29);

#line 286
        ae_5 = int(1) - _S29;

#line 286
        am_6 = _S30;

#line 284
    }
    else
    {


        ulong _S31 = am_5 | 4503599627370496ULL;

#line 289
        ae_5 = ae_4;

#line 289
        am_6 = _S31;

#line 284
    }

#line 291
    int be_4 = int((b_3 >> 52ULL) & 2047ULL);
    ulong bm_6 = b_3 & 4503599627370495ULL;

#line 292
    int be_5;

#line 292
    ulong bm_7;
    if(be_4 == int(0))
    {
        int _S32 = int(52) - hibit64_0(bm_6);

#line 295
        ulong _S33 = bm_6 << ulong(_S32);

#line 295
        be_5 = int(1) - _S32;

#line 295
        bm_7 = _S33;

#line 293
    }
    else
    {


        ulong _S34 = bm_6 | 4503599627370496ULL;

#line 298
        be_5 = be_4;

#line 298
        bm_7 = _S34;

#line 293
    }

#line 300
    int e_4 = ae_5 - be_5 + int(1023);

#line 300
    int e_5;
    if(am_6 < bm_7)
    {
        int _S35 = e_4 - int(1);

#line 303
        am_6 = am_6 << 1ULL;

#line 303
        e_5 = _S35;

#line 301
    }
    else
    {

#line 301
        e_5 = e_4;

#line 301
    }

#line 301
    ulong q_0 = 0ULL;

#line 301
    ulong r_0 = am_6;

#line 301
    uint i_0 = 0U;

#line 307
    for(;;)
    {

#line 307
        if(i_0 < 55U)
        {
        }
        else
        {

#line 307
            break;
        }

#line 308
        ulong q_1 = q_0 << 1ULL;

#line 308
        ulong r_1;
        if(r_0 >= bm_7)
        {
            ulong _S36 = q_1 | 1ULL;

#line 311
            r_1 = r_0 - bm_7;

#line 311
            q_0 = _S36;

#line 309
        }
        else
        {

#line 309
            r_1 = r_0;

#line 309
            q_0 = q_1;

#line 309
        }



        ulong _S37 = r_1 << 1ULL;

#line 307
        uint i_1 = i_0 + 1U;

#line 307
        r_0 = _S37;

#line 307
        i_0 = i_1;

#line 307
    }

#line 315
    ulong _S38 = q_0 << 7ULL;

#line 315
    if(r_0 != 0ULL)
    {

#line 315
        am_6 = 1ULL;

#line 315
    }
    else
    {

#line 315
        am_6 = 0ULL;

#line 315
    }
    return pack64_0(s_2, e_5, _S38 | am_6);
}


#line 390
ulong f64_floor_0(ulong a_4)
{

#line 391
    ulong _S39 = a_4 & 9223372036854775807ULL;

#line 391
    if(_S39 > 9218868437227405312ULL)
    {

#line 392
        return a_4 | 2251799813685248ULL;
    }
    if(_S39 == 0ULL)
    {

#line 395
        return a_4;
    }
    int e_6 = int((a_4 >> 52ULL) & 2047ULL);
    if(e_6 >= int(1075))
    {

#line 399
        return a_4;
    }
    if(e_6 < int(1023))
    {

#line 401
        ulong _S40;
        if((a_4 >> 63ULL) != 0ULL)
        {

#line 402
            _S40 = 13830554455654793216ULL;

#line 402
        }
        else
        {

#line 402
            _S40 = 0ULL;

#line 402
        }

#line 402
        return _S40;
    }
    ulong mask_0 = (1ULL << ulong(int(1075) - e_6)) - 1ULL;
    if((a_4 & mask_0) == 0ULL)
    {

#line 406
        return a_4;
    }
    if((a_4 >> 63ULL) == 0ULL)
    {

#line 409
        return a_4 & (mask_0 ^ 18446744073709551615ULL);
    }
    return (a_4 & (mask_0 ^ 18446744073709551615ULL)) + mask_0 + 1ULL;
}

ulong f64_to_i64_0(ulong a_5)
{

#line 415
    if((a_5 & 9223372036854775807ULL) > 9218868437227405312ULL)
    {

#line 416
        return 0ULL;
    }
    int e_7 = int((a_5 >> 52ULL) & 2047ULL);
    ulong s_3 = a_5 >> 63ULL;
    if(e_7 < int(1023))
    {

#line 421
        return 0ULL;
    }

#line 421
    ulong q_2;

    if(e_7 >= int(1086))
    {

#line 424
        if(s_3 != 0ULL)
        {

#line 424
            q_2 = 9223372036854775808ULL;

#line 424
        }
        else
        {

#line 424
            q_2 = 9223372036854775807ULL;

#line 424
        }

#line 424
        return q_2;
    }
    ulong m_5 = (a_5 & 4503599627370495ULL) | 4503599627370496ULL;

    if(e_7 >= int(1075))
    {

#line 428
        q_2 = m_5 << ulong(e_7 - int(1075));

#line 428
    }
    else
    {

#line 428
        q_2 = m_5 >> ulong(int(1075) - e_7);

#line 428
    }

#line 433
    if(s_3 != 0ULL)
    {

#line 434
        return (q_2 ^ 18446744073709551615ULL) + 1ULL;
    }
    return q_2;
}


#line 492
struct KernelContext_0
{
    uint device* p_0;
    ulong device* a_6;
    ulong device* b_4;
    ulong device* y_0;
};


#line 465
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_1 [[buffer(2)]], ulong device* a_7 [[buffer(0)]], ulong device* b_5 [[buffer(1)]], ulong device* y_1 [[buffer(3)]])
{

#line 465
    thread KernelContext_0 kernelContext_0;

#line 465
    (&kernelContext_0)->p_0 = p_1;

#line 465
    (&kernelContext_0)->a_6 = a_7;

#line 465
    (&kernelContext_0)->b_4 = b_5;

#line 465
    (&kernelContext_0)->y_0 = y_1;
    uint t_0 = tid_0.x;
    if(t_0 >= p_1[0U])
    {

#line 468
        return;
    }
    uint op_0 = (&kernelContext_0)->p_0[1U];
    ulong x_2 = (&kernelContext_0)->a_6[t_0];
    ulong z_0 = (&kernelContext_0)->b_4[t_0];

#line 472
    ulong r_2;

    if(op_0 == 0U)
    {

#line 474
        r_2 = f64_add_0(x_2, z_0);

#line 474
    }
    else
    {

#line 474
        r_2 = 0ULL;

#line 474
    }


    if(op_0 == 1U)
    {

#line 477
        r_2 = f64_sub_0(x_2, z_0);

#line 477
    }


    if(op_0 == 2U)
    {

#line 480
        r_2 = f64_mul_0(x_2, z_0);

#line 480
    }


    if(op_0 == 3U)
    {

#line 483
        r_2 = f64_div_0(x_2, z_0);

#line 483
    }


    if(op_0 == 4U)
    {

#line 486
        r_2 = f64_floor_0(x_2);

#line 486
    }


    if(op_0 == 5U)
    {

#line 489
        r_2 = f64_to_i64_0(x_2);

#line 489
    }


    *((&kernelContext_0)->y_0+t_0) = r_2;
    return;
}

