#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 76 "kernels/slang/f32_of_f64.slang"
float f64_to_f32_0(ulong d_0)
{

#line 77
    uint s_0 = uint(d_0 >> 63ULL);
    int e_0 = int((d_0 >> 52ULL) & 2047ULL);
    ulong f_0 = d_0 & 4503599627370495ULL;

#line 79
    uint sh_0;
    if(e_0 == int(2047))
    {

#line 81
        uint _S1 = (s_0 << 31U) | 2139095040U;

#line 81
        if(f_0 != 0ULL)
        {

#line 81
            sh_0 = 4194304U | uint(f_0 >> 29ULL);

#line 81
        }
        else
        {

#line 81
            sh_0 = 0U;

#line 81
        }

#line 81
        return (as_type<float>((_S1 | sh_0)));
    }
    bool _S2 = e_0 == int(0);

#line 83
    bool _S3;

#line 83
    if(_S2)
    {

#line 83
        _S3 = f_0 == 0ULL;

#line 83
    }
    else
    {

#line 83
        _S3 = false;

#line 83
    }

#line 83
    if(_S3)
    {

#line 84
        return (as_type<float>((s_0 << 31U)));
    }

#line 84
    ulong q_0;

    if(e_0 != int(0))
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
    ulong m_0 = f_0 | q_0;

#line 86
    int e_1;
    if(_S2)
    {

#line 87
        e_1 = int(1);

#line 87
    }
    else
    {

#line 87
        e_1 = e_0;

#line 87
    }


    int ef_0 = e_1 - int(896);

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


    ulong _S4 = ulong(sh_0);

#line 99
    ulong q_1 = m_0 >> _S4;
    ulong rem_0 = m_0 & ((1ULL << _S4) - 1ULL);
    ulong half_0 = 1ULL << ulong(sh_0 - 1U);
    if(rem_0 > half_0)
    {

#line 102
        _S3 = true;

#line 102
    }
    else
    {

#line 102
        if(rem_0 == half_0)
        {

#line 102
            _S3 = (q_1 & 1ULL) != 0ULL;

#line 102
        }
        else
        {

#line 102
            _S3 = false;

#line 102
        }

#line 102
    }

#line 102
    if(_S3)
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
        return (as_type<float>(((s_0 << 31U) | uint(q_0))));
    }
    if((q_0 >> 24ULL) != 0ULL)
    {

#line 109
        ulong _S5 = q_0 >> 1ULL;

#line 109
        ef_1 = ef_1 + int(1);

#line 109
        q_0 = _S5;

#line 108
    }



    if(ef_1 >= int(255))
    {

#line 113
        return (as_type<float>(((s_0 << 31U) | 2139095040U)));
    }
    return (as_type<float>((((s_0 << 31U) | (uint(ef_1) << 23U)) | uint(q_0 & 8388607ULL))));
}


#line 468
struct KernelContext_0
{
    uint device* p_0;
    float device* y_0;
    ulong device* a_0;
};


#line 463
[[kernel]] void main_0(uint3 tid_0 [[thread_position_in_grid]], uint device* p_1 [[buffer(1)]], float device* y_1 [[buffer(2)]], ulong device* a_1 [[buffer(0)]])
{

#line 463
    thread KernelContext_0 kernelContext_0;

#line 463
    (&kernelContext_0)->p_0 = p_1;

#line 463
    (&kernelContext_0)->y_0 = y_1;

#line 463
    (&kernelContext_0)->a_0 = a_1;
    uint t_0 = tid_0.x;
    if(t_0 >= p_1[0U])
    {

#line 466
        return;
    }
    *((&kernelContext_0)->y_0+t_0) = f64_to_f32_0((&kernelContext_0)->a_0[t_0]);
    return;
}

