// ggml-cpu reference outputs, one op per case, for the per-op MLX tests.
//
// This file is C because ggml is a C library: building a ggml graph needs its
// C API, and the reference must be the real ggml-cpu kernels, not a restatement.
// It runs one op at a time on the CPU (a unit-test fixture, not a model run).
//
//   ggml_ref <outdir> [case...]      # no case names: every case
//
// Each case writes <outdir>/<case>/in<i>.f32, out.f32 (raw little-endian f32)
// and meta.txt: one line per tensor, "<name> <ne0> <ne1> <ne2> <ne3>".
#include "ggml.h"
#include "ggml-cpu.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

// splitmix32: a fixed, seedable stream so the inputs are reproducible.
static uint32_t rng_state;
static uint32_t rnd(void) {
	uint32_t z = (rng_state += 0x9e3779b9u);
	z = (z ^ (z >> 16)) * 0x85ebca6bu;
	z = (z ^ (z >> 13)) * 0xc2b2ae35u;
	return z ^ (z >> 16);
}
// Uniform in [-a, a), 24 random mantissa bits.
static float unif(float a) { return a * ((float)(rnd() >> 8) * (1.0f / 8388608.0f) - 1.0f); }

static struct ggml_context *ctx;
static const char *outdir;
static char casedir[1024];
static FILE *meta;
static int nin;

static struct ggml_tensor *input(int64_t ne0, int64_t ne1, int64_t ne2, float a) {
	struct ggml_tensor *t = ggml_new_tensor_3d(ctx, GGML_TYPE_F32, ne0, ne1, ne2);
	float *d = (float *)t->data;
	for (int64_t i = 0; i < ggml_nelements(t); i++) d[i] = unif(a);
	return t;
}

static void save(const char *name, const struct ggml_tensor *t) {
	char p[1200];
	snprintf(p, sizeof p, "%s/%s.f32", casedir, name);
	FILE *f = fopen(p, "wb");
	if (!f) { perror(p); exit(1); }
	// Contiguous by construction: every saved tensor is an input or a ggml_cont result.
	fwrite(t->data, sizeof(float), (size_t)ggml_nelements(t), f);
	fclose(f);
	fprintf(meta, "%s %lld %lld %lld %lld\n", name, (long long)t->ne[0], (long long)t->ne[1],
	        (long long)t->ne[2], (long long)t->ne[3]);
}

static void begin(const char *name, uint32_t seed) {
	snprintf(casedir, sizeof casedir, "%s/%s", outdir, name);
	mkdir(outdir, 0755);
	mkdir(casedir, 0755);
	char p[1200];
	snprintf(p, sizeof p, "%s/meta.txt", casedir);
	meta = fopen(p, "w");
	rng_state = seed;
	nin = 0;
	struct ggml_init_params ip = { (size_t)3 << 30, NULL, false };
	ctx = ggml_init(ip);
}

static void in(struct ggml_tensor *t) {
	char n[16];
	snprintf(n, sizeof n, "in%d", nin++);
	save(n, t);
}

static void finish(struct ggml_tensor *out) {
	if (!ggml_is_contiguous(out)) out = ggml_cont(ctx, out);
	struct ggml_cgraph *g = ggml_new_graph(ctx);
	ggml_build_forward_expand(g, out);
	// One thread: no op here changes its per-element order with the thread
	// count, and one thread keeps the fixture independent of the host.
	if (ggml_graph_compute_with_ctx(ctx, g, 1) != GGML_STATUS_SUCCESS) { fprintf(stderr, "compute failed\n"); exit(1); }
	save("out", out);
	fclose(meta);
	ggml_free(ctx);
	printf("%s\n", casedir);
}

// ---- cases ---------------------------------------------------------------

static void mul_mat(const char *n, int64_t k, int64_t m, int64_t r, int64_t b, float aw, float ax) {
	begin(n, 1u);
	struct ggml_tensor *w = input(k, m, 1, aw), *x = input(k, r, b, ax);
	in(w); in(x);
	finish(ggml_mul_mat(ctx, w, x));
}

static void add_c(const char *n, int64_t a0, int64_t a1, int64_t a2) {
	begin(n, 2u);
	struct ggml_tensor *a = input(a0, a1, a2, 4.0f), *b = input(a0, a1, a2, 4.0f);
	in(a); in(b);
	finish(ggml_add(ctx, a, b));
}

static void mul_c(const char *n, int64_t a0, int64_t a1, int64_t a2) {
	begin(n, 3u);
	struct ggml_tensor *a = input(a0, a1, a2, 4.0f), *b = input(a0, a1, a2, 4.0f);
	in(a); in(b);
	finish(ggml_mul(ctx, a, b));
}

static void repeat_c(const char *n, int64_t a0, int64_t a1, int64_t a2) {
	begin(n, 4u);
	struct ggml_tensor *a = input(a0, 1, 1, 1.0f), *like = ggml_new_tensor_3d(ctx, GGML_TYPE_F32, a0, a1, a2);
	in(a);
	finish(ggml_repeat(ctx, a, like));
}

static void norm_c(const char *n, int64_t a0, int64_t a1, int64_t a2) {
	begin(n, 5u);
	struct ggml_tensor *a = input(a0, a1, a2, 3.0f);
	in(a);
	// Kimodo's eps (denoiser.cpp norm()).
	finish(ggml_norm(ctx, a, 1.e-5f));
}

static void scale_c(const char *n, int64_t a0, int64_t a1) {
	begin(n, 6u);
	struct ggml_tensor *a = input(a0, a1, 1, 40.0f);
	in(a);
	// Kimodo's attention scale, 1/sqrt(head_width) (denoiser.cpp layer()).
	finish(ggml_scale(ctx, a, 1.f / sqrtf(128.0f)));
}

static void soft_max_c(const char *n, int64_t a0, int64_t a1, float a) {
	begin(n, 7u);
	struct ggml_tensor *x = input(a0, a1, 1, a);
	in(x);
	finish(ggml_soft_max(ctx, x));
}

static void gelu_c(const char *n, int64_t a0, int64_t a1, int64_t a2) {
	begin(n, 8u);
	struct ggml_tensor *x = input(a0, a1, a2, 6.0f);
	in(x);
	finish(ggml_gelu_erf(ctx, x));
}

static void silu_c(const char *n, int64_t a0, int64_t a1, int64_t a2) {
	begin(n, 9u);
	struct ggml_tensor *x = input(a0, a1, a2, 12.0f);
	in(x);
	finish(ggml_silu(ctx, x));
}

static void concat_c(const char *n, int dim, int64_t a0, int64_t a1, int64_t a2, int64_t b) {
	begin(n, 10u);
	int64_t bn[3] = { a0, a1, a2 };
	bn[dim] = b;
	struct ggml_tensor *x = input(a0, a1, a2, 1.0f), *y = input(bn[0], bn[1], bn[2], 1.0f);
	in(x); in(y);
	finish(ggml_concat(ctx, x, y, dim));
}

static void transpose_c(const char *n, int64_t a0, int64_t a1) {
	begin(n, 11u);
	struct ggml_tensor *x = input(a0, a1, 1, 1.0f);
	in(x);
	finish(ggml_cont(ctx, ggml_transpose(ctx, x)));
}

// One head's slice of a packed qkv row block, as denoiser.cpp head() takes it.
static void view_c(const char *n, int64_t w, int64_t seq, int64_t hw, int64_t off) {
	begin(n, 12u);
	struct ggml_tensor *x = input(w, seq, 1, 1.0f);
	in(x);
	finish(ggml_cont(ctx, ggml_view_2d(ctx, x, hw, seq, x->nb[1], (size_t)off * sizeof(float))));
}

struct entry { const char *name; void (*run)(const char *); };
#define CASE(nm, body) static void nm##_run(const char *n) { body; }
// Small cases: shapes chosen to reach every code path (vector body and scalar tail).
CASE(mul_mat_small, mul_mat(n, 37, 5, 3, 1, 1.0f, 1.0f))
CASE(mul_mat_k2, mul_mat(n, 2, 7, 1, 3, 1.0f, 1.0f))
CASE(add_small, add_c(n, 7, 3, 2))
CASE(mul_small, mul_c(n, 7, 3, 2))
CASE(repeat_small, repeat_c(n, 7, 3, 2))
CASE(norm_small, norm_c(n, 37, 3, 1))
CASE(scale_small, scale_c(n, 13, 4))
CASE(soft_max_small, soft_max_c(n, 16, 4, 30.0f))
CASE(soft_max_tail, soft_max_c(n, 13, 4, 30.0f))
CASE(gelu_erf_small, gelu_c(n, 64, 4, 1))
CASE(silu_small, silu_c(n, 16, 2, 1))
CASE(silu_tail, silu_c(n, 7, 2, 1))
CASE(concat0_small, concat_c(n, 0, 5, 3, 2, 4))
CASE(concat1_small, concat_c(n, 1, 5, 3, 2, 4))
CASE(concat2_small, concat_c(n, 2, 5, 3, 2, 4))
CASE(transpose_small, transpose_c(n, 5, 3))
CASE(view_small, view_c(n, 24, 3, 4, 8))
// Kimodo shapes (denoiser.cpp: width 1024, heads 8, head 128, seq 52+300, batch 3,
// feed-forward 2048, text 4096 x 50 tokens; root/body input 738/737; gguf metadata).
CASE(mul_mat_qkv, mul_mat(n, 1024, 3072, 352, 3, 0.05f, 2.0f))
CASE(mul_mat_ffn2, mul_mat(n, 2048, 1024, 352, 3, 0.05f, 2.0f))
CASE(mul_mat_text, mul_mat(n, 4096, 1024, 50, 3, 0.05f, 2.0f))
CASE(mul_mat_heading, mul_mat(n, 2, 1024, 1, 3, 0.5f, 1.0f))
CASE(mul_mat_root_in, mul_mat(n, 738, 1024, 300, 3, 0.05f, 2.0f))
CASE(mul_mat_body_in, mul_mat(n, 737, 1024, 300, 3, 0.05f, 2.0f))
CASE(mul_mat_scores, mul_mat(n, 128, 352, 352, 1, 2.0f, 2.0f))
CASE(mul_mat_value, mul_mat(n, 352, 128, 352, 1, 0.01f, 2.0f))
CASE(add_kimodo, add_c(n, 3072, 352, 3))
CASE(mul_kimodo, mul_c(n, 1024, 352, 3))
CASE(repeat_kimodo, repeat_c(n, 1024, 352, 3))
CASE(norm_kimodo, norm_c(n, 1024, 352, 3))
CASE(scale_kimodo, scale_c(n, 352, 352))
CASE(soft_max_kimodo, soft_max_c(n, 352, 352, 30.0f))
CASE(gelu_erf_kimodo, gelu_c(n, 2048, 352, 3))
CASE(silu_kimodo, silu_c(n, 1024, 1, 3))
CASE(concat0_kimodo, concat_c(n, 0, 896, 352, 1, 128))
CASE(concat1_kimodo, concat_c(n, 1, 1024, 52, 3, 300))
CASE(concat2_kimodo, concat_c(n, 2, 1024, 352, 2, 1))
CASE(transpose_kimodo, transpose_c(n, 128, 352))
CASE(view_kimodo, view_c(n, 3072, 352, 128, 1024 + 3 * 128))

#define E(nm) { #nm, nm##_run }
static const struct entry cases[] = {
	E(mul_mat_small), E(mul_mat_k2), E(add_small), E(mul_small), E(repeat_small), E(norm_small),
	E(scale_small), E(soft_max_small), E(soft_max_tail), E(gelu_erf_small), E(silu_small),
	E(silu_tail), E(concat0_small), E(concat1_small), E(concat2_small), E(transpose_small),
	E(view_small), E(mul_mat_qkv), E(mul_mat_ffn2), E(mul_mat_text), E(mul_mat_heading),
	E(mul_mat_root_in), E(mul_mat_body_in), E(mul_mat_scores), E(mul_mat_value), E(add_kimodo),
	E(mul_kimodo), E(repeat_kimodo), E(norm_kimodo), E(scale_kimodo), E(soft_max_kimodo),
	E(gelu_erf_kimodo), E(silu_kimodo), E(concat0_kimodo), E(concat1_kimodo), E(concat2_kimodo),
	E(transpose_kimodo), E(view_kimodo),
};

int main(int argc, char **argv) {
	if (argc < 2) { fprintf(stderr, "usage: ggml_ref <outdir> [case...]\n"); return 2; }
	outdir = argv[1];
	size_t n = sizeof cases / sizeof cases[0];
	for (size_t i = 0; i < n; i++) {
		int want = argc == 2;
		for (int a = 2; a < argc; a++) want |= strcmp(argv[a], cases[i].name) == 0;
		if (want) cases[i].run(cases[i].name);
	}
	return 0;
}
