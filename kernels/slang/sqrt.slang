[[vk::binding(0, 0)]]
StructuredBuffer<float> a;
[[vk::binding(1, 0)]]
StructuredBuffer<uint> p;
[[vk::binding(2, 0)]]
RWStructuredBuffer<float> y;

int hibit64(uint64_t x) {
  uint hi = uint((x >> 32ULL));
  if ((hi != 0u)) {
    return (int(firstbithigh(hi)) + 32);
  }
  return int(firstbithigh(uint((x & 4294967295ULL))));
}

uint64_t srs(uint64_t x, uint n) {
  if ((n == 0u)) {
    return x;
  }
  if ((n >= 63u)) {
    return ((x != 0ULL) ? 1ULL : 0ULL);
  }
  uint64_t lost = (x & ((1ULL << uint64_t(n)) - 1ULL));
  return ((x >> uint64_t(n)) | ((lost != 0ULL) ? 1ULL : 0ULL));
}

uint64_t pack64(uint64_t s, int e0, uint64_t m0) {
  int e = e0;
  uint64_t m = m0;
  if ((e < 1)) {
    m = srs(m, uint((1 - e)));
    e = 1;
  }
  uint64_t rem = (m & 511ULL);
  m = (m >> 9ULL);
  if (((rem > 256ULL) || ((rem == 256ULL) && ((m & 1ULL) != 0ULL)))) {
    m = (m + 1ULL);
  }
  if (((m >> 53ULL) != 0ULL)) {
    m = (m >> 1ULL);
    e = (e + 1);
  }
  if ((e >= 2047)) {
    return ((s << 63ULL) | 9218868437227405312ULL);
  }
  uint64_t field = (((m >> 52ULL) != 0ULL) ? uint64_t(e) : 0ULL);
  return (((s << 63ULL) | (field << 52ULL)) | (m & 4503599627370495ULL));
}

uint64_t f64_from_f32(float x) {
  uint b = asuint(x);
  uint64_t s = uint64_t((b >> 31u));
  uint e = ((b >> 23u) & 255u);
  uint f = (b & 8388607u);
  if ((e == 255u)) {
    return (((s << 63ULL) | 9218868437227405312ULL) | (uint64_t(f) << 29ULL));
  }
  if ((e == 0u)) {
    if ((f == 0u)) {
      return (s << 63ULL);
    }
    uint p = firstbithigh(f);
    return (((s << 63ULL) | (uint64_t((p + 874u)) << 52ULL)) | ((uint64_t(f) << uint64_t((52u - p))) & 4503599627370495ULL));
  }
  return (((s << 63ULL) | (uint64_t((e + 896u)) << 52ULL)) | (uint64_t(f) << 29ULL));
}

uint64_t f64_from_u32(uint n) {
  if ((n == 0u)) {
    return 0ULL;
  }
  uint p = firstbithigh(n);
  return ((uint64_t((p + 1023u)) << 52ULL) | ((uint64_t(n) << uint64_t((52u - p))) & 4503599627370495ULL));
}

float f64_to_f32(uint64_t d) {
  uint s = uint((d >> 63ULL));
  int e = int(((d >> 52ULL) & 2047ULL));
  uint64_t f = (d & 4503599627370495ULL);
  if ((e == 2047)) {
    return asfloat((((s << 31u) | 2139095040u) | ((f != 0ULL) ? (4194304u | uint((f >> 29ULL))) : 0u)));
  }
  if (((e == 0) && (f == 0ULL))) {
    return asfloat((s << 31u));
  }
  uint64_t m = (f | ((e != 0) ? 4503599627370496ULL : 0ULL));
  if ((e == 0)) {
    e = 1;
  }
  int ef = (e - 896);
  uint sh = 29u;
  if ((ef <= 0)) {
    sh = uint((30 - ef));
    ef = 0;
  }
  if ((sh > 63u)) {
    sh = 63u;
  }
  uint64_t q = (m >> uint64_t(sh));
  uint64_t rem = (m & ((1ULL << uint64_t(sh)) - 1ULL));
  uint64_t half = (1ULL << uint64_t((sh - 1u)));
  if (((rem > half) || ((rem == half) && ((q & 1ULL) != 0ULL)))) {
    q = (q + 1ULL);
  }
  if ((ef == 0)) {
    return asfloat(((s << 31u) | uint(q)));
  }
  if (((q >> 24ULL) != 0ULL)) {
    q = (q >> 1ULL);
    ef = (ef + 1);
  }
  if ((ef >= 255)) {
    return asfloat(((s << 31u) | 2139095040u));
  }
  return asfloat((((s << 31u) | (uint(ef) << 23u)) | uint((q & 8388607ULL))));
}

uint64_t f64_add(uint64_t a, uint64_t b) {
  if (((a & 9223372036854775807ULL) > 9218868437227405312ULL)) {
    return (a | 2251799813685248ULL);
  }
  if (((b & 9223372036854775807ULL) > 9218868437227405312ULL)) {
    return (b | 2251799813685248ULL);
  }
  if (((a & 9223372036854775807ULL) == 9218868437227405312ULL)) {
    if ((((b & 9223372036854775807ULL) == 9218868437227405312ULL) && (a != b))) {
      return 9221120237041090560ULL;
    }
    return a;
  }
  if (((b & 9223372036854775807ULL) == 9218868437227405312ULL)) {
    return b;
  }
  if (((a & 9223372036854775807ULL) == 0ULL)) {
    if (((b & 9223372036854775807ULL) == 0ULL)) {
      return (a & b);
    }
    return b;
  }
  if (((b & 9223372036854775807ULL) == 0ULL)) {
    return a;
  }
  uint64_t sa = (a >> 63ULL);
  uint64_t sb = (b >> 63ULL);
  int ae = int(((a >> 52ULL) & 2047ULL));
  uint64_t am = (a & 4503599627370495ULL);
  if ((ae == 0)) {
    int ah = hibit64(am);
    am = (am << uint64_t((52 - ah)));
    ae = (1 - (52 - ah));
  } else {
    am = (am | 4503599627370496ULL);
  }
  int be = int(((b >> 52ULL) & 2047ULL));
  uint64_t bm = (b & 4503599627370495ULL);
  if ((be == 0)) {
    int bh = hibit64(bm);
    bm = (bm << uint64_t((52 - bh)));
    be = (1 - (52 - bh));
  } else {
    bm = (bm | 4503599627370496ULL);
  }
  am = (am << 9ULL);
  bm = (bm << 9ULL);
  if (((ae < be) || ((ae == be) && (am < bm)))) {
    int te = ae;
    ae = be;
    be = te;
    uint64_t tm = am;
    am = bm;
    bm = tm;
    uint64_t ts = sa;
    sa = sb;
    sb = ts;
  }
  bm = srs(bm, uint((ae - be)));
  uint64_t m = ((sa == sb) ? (am + bm) : (am - bm));
  if ((m == 0ULL)) {
    return 0ULL;
  }
  int e = ae;
  int h = hibit64(m);
  if ((h > 61)) {
    m = srs(m, 1u);
    e = (e + 1);
  } else {
    m = (m << uint64_t((61 - h)));
    e = (e - (61 - h));
  }
  return pack64(sa, e, m);
}

uint64_t f64_mul(uint64_t a, uint64_t b) {
  uint64_t s = ((a ^ b) >> 63ULL);
  if ((((a & 9223372036854775807ULL) > 9218868437227405311ULL) || ((b & 9223372036854775807ULL) > 9218868437227405311ULL))) {
    return 9221120237041090560ULL;
  }
  if ((((a & 9223372036854775807ULL) == 0ULL) || ((b & 9223372036854775807ULL) == 0ULL))) {
    return (s << 63ULL);
  }
  int ae = int(((a >> 52ULL) & 2047ULL));
  uint64_t am = (a & 4503599627370495ULL);
  if ((ae == 0)) {
    int ah = hibit64(am);
    am = (am << uint64_t((52 - ah)));
    ae = (1 - (52 - ah));
  } else {
    am = (am | 4503599627370496ULL);
  }
  int be = int(((b >> 52ULL) & 2047ULL));
  uint64_t bm = (b & 4503599627370495ULL);
  if ((be == 0)) {
    int bh = hibit64(bm);
    bm = (bm << uint64_t((52 - bh)));
    be = (1 - (52 - bh));
  } else {
    bm = (bm | 4503599627370496ULL);
  }
  uint64_t a0 = (am & 4294967295ULL);
  uint64_t a1 = (am >> 32ULL);
  uint64_t b0 = (bm & 4294967295ULL);
  uint64_t b1 = (bm >> 32ULL);
  uint64_t p00 = (a0 * b0);
  uint64_t p01 = (a0 * b1);
  uint64_t p10 = (a1 * b0);
  uint64_t p11 = (a1 * b1);
  uint64_t mid = (((p00 >> 32ULL) + (p01 & 4294967295ULL)) + (p10 & 4294967295ULL));
  uint64_t lo = ((p00 & 4294967295ULL) | (mid << 32ULL));
  uint64_t hi = (((p11 + (p01 >> 32ULL)) + (p10 >> 32ULL)) + (mid >> 32ULL));
  uint64_t m = (((hi << 21ULL) | (lo >> 43ULL)) | (((lo & 8796093022207ULL) != 0ULL) ? 1ULL : 0ULL));
  int e = ((ae + be) - 1023);
  if (((m >> 62ULL) != 0ULL)) {
    m = srs(m, 1u);
    e = (e + 1);
  }
  return pack64(s, e, m);
}

uint64_t f64_div(uint64_t a, uint64_t b) {
  uint64_t s = ((a ^ b) >> 63ULL);
  if (((a & 9223372036854775807ULL) > 9218868437227405312ULL)) {
    return (a | 2251799813685248ULL);
  }
  if (((b & 9223372036854775807ULL) > 9218868437227405312ULL)) {
    return (b | 2251799813685248ULL);
  }
  if (((a & 9223372036854775807ULL) == 9218868437227405312ULL)) {
    if (((b & 9223372036854775807ULL) == 9218868437227405312ULL)) {
      return 9221120237041090560ULL;
    }
    return ((s << 63ULL) | 9218868437227405312ULL);
  }
  if (((b & 9223372036854775807ULL) == 9218868437227405312ULL)) {
    return (s << 63ULL);
  }
  if (((b & 9223372036854775807ULL) == 0ULL)) {
    if (((a & 9223372036854775807ULL) == 0ULL)) {
      return 9221120237041090560ULL;
    }
    return ((s << 63ULL) | 9218868437227405312ULL);
  }
  if (((a & 9223372036854775807ULL) == 0ULL)) {
    return (s << 63ULL);
  }
  int ae = int(((a >> 52ULL) & 2047ULL));
  uint64_t am = (a & 4503599627370495ULL);
  if ((ae == 0)) {
    int ah = hibit64(am);
    am = (am << uint64_t((52 - ah)));
    ae = (1 - (52 - ah));
  } else {
    am = (am | 4503599627370496ULL);
  }
  int be = int(((b >> 52ULL) & 2047ULL));
  uint64_t bm = (b & 4503599627370495ULL);
  if ((be == 0)) {
    int bh = hibit64(bm);
    bm = (bm << uint64_t((52 - bh)));
    be = (1 - (52 - bh));
  } else {
    bm = (bm | 4503599627370496ULL);
  }
  int e = ((ae - be) + 1023);
  if ((am < bm)) {
    am = (am << 1ULL);
    e = (e - 1);
  }
  uint64_t r = am;
  uint64_t q = 0ULL;
  for (uint i = 0u; i < 55u; ++i) {
    q = (q << 1ULL);
    if ((r >= bm)) {
      r = (r - bm);
      q = (q | 1ULL);
    }
    r = (r << 1ULL);
  }
  uint64_t m = ((q << 7ULL) | ((r != 0ULL) ? 1ULL : 0ULL));
  return pack64(s, e, m);
}

float f32_div(float a, float b) {
  return f64_to_f32(f64_div(f64_from_f32(a), f64_from_f32(b)));
}

float f32_sqrt(float x) {
  uint b = asuint(x);
  if (((b & 2147483647u) == 0u)) {
    return x;
  }
  if (((b >> 31u) != 0u)) {
    return asfloat(2143289344u);
  }
  if ((b >= 2139095040u)) {
    return x;
  }
  int e = int((b >> 23u));
  uint m = (b & 8388607u);
  if ((e == 0)) {
    int p = int(firstbithigh(m));
    m = (m << uint((23 - p)));
    e = (1 - (23 - p));
  } else {
    m = (m | 8388608u);
  }
  int k = (e - 150);
  uint64_t w = uint64_t(m);
  if (((k & 1) != 0)) {
    w = (w << 1ULL);
    k = (k - 1);
  }
  w = (w << 38ULL);
  k = (k - 38);
  uint64_t r = 0ULL;
  uint64_t rem = 0ULL;
  for (uint i = 0u; i < 32u; ++i) {
    rem = ((rem << 2ULL) | ((w >> 62ULL) & 3ULL));
    w = (w << 2ULL);
    uint64_t t = ((r << 2ULL) | 1ULL);
    r = (r << 1ULL);
    if ((rem >= t)) {
      rem = (rem - t);
      r = (r | 1ULL);
    }
  }
  int h = hibit64(r);
  int sh = (h - 23);
  uint64_t q = (r >> uint64_t(sh));
  uint64_t lost = (r & ((1ULL << uint64_t(sh)) - 1ULL));
  uint64_t half = (1ULL << uint64_t((sh - 1)));
  bool sticky = ((rem != 0ULL) || ((lost & (half - 1ULL)) != 0ULL));
  if ((((lost & half) != 0ULL) && (sticky || ((q & 1ULL) != 0ULL)))) {
    q = (q + 1ULL);
  }
  int ee = (((k / 2) + sh) + 150);
  if (((q >> 24ULL) != 0ULL)) {
    q = (q >> 1ULL);
    ee = (ee + 1);
  }
  return asfloat(((uint(ee) << 23u) | uint((q & 8388607ULL))));
}

float ggml_v_expf(float x) {
  float r = asfloat(1262485504u);
  float z = fma(x, asfloat(1069066811u), r);
  float n = (z - r);
  float b = fma((-n), asfloat(901758606u), fma((-n), asfloat(1060205056u), x));
  uint e = (asuint(z) << 23u);
  float k = asfloat((e + 1065353216u));
  float uu = (b * b);
  float p1 = fma(asfloat(1042984755u), b, asfloat(1056964315u));
  float p2 = fma(asfloat(1007099920u), b, asfloat(1026268951u));
  float p3 = fma(p2, uu, p1);
  float j = fma(p3, uu, (asfloat(1065353206u) * b));
  float an = abs(n);
  uint d = ((n <= asfloat(0u)) ? 2181038080u : 0u);
  float s1 = asfloat((d + 2130706432u));
  if ((an > asfloat(1128267776u))) {
    return (s1 * s1);
  }
  if ((an > asfloat(1123811328u))) {
    float s2 = asfloat((e - d));
    return (fma(s2, j, s2) * s1);
  }
  return fma(k, j, k);
}

[shader("compute")] [numthreads(256, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  uint t = tid.x;
  if ((t >= p[0u])) {
    return;
  }
  y[t] = f32_sqrt(a[t]);
}
