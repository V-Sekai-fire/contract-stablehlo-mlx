// The C ABI shim between Lean and mlx-c. Trusted, and kept thin: every
// function unpacks Lean objects, makes one mlx-c call, and boxes the result.
// No numerics live here; the op table and the kernels are Lean.
#include <lean/lean.h>
#include <mlx/c/mlx.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// IO.Error.toString, exported by the Lean runtime.
extern lean_object *lean_io_error_to_string(lean_object *err);

static char last_error[2048];
static void on_error(const char *msg, void *data) {
	(void)data;
	snprintf(last_error, sizeof last_error, "%s", msg);
}

static mlx_stream gpu;
static int ready;
static void init(void) {
	if (ready) return;
	mlx_set_error_handler(on_error, NULL, NULL);
	gpu = mlx_default_gpu_stream_new();
	ready = 1;
}

// An error raised by the Lean function under trace: mlx reports only that the
// closure failed, so the Lean message is kept here and reported first.
static char trace_error[2048];

static lean_obj_res io_err(const char *what) {
	char b[4400];
	if (trace_error[0]) snprintf(b, sizeof b, "%s: %s", what, trace_error);
	else snprintf(b, sizeof b, "%s: %s", what, last_error);
	last_error[0] = 0;
	trace_error[0] = 0;
	return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(b)));
}

// ---- the Arr external class ------------------------------------------------

static void arr_finalize(void *p) {
	mlx_array_free(*(mlx_array *)p);
	free(p);
}
static void arr_foreach(void *p, b_lean_obj_arg f) { (void)p; (void)f; }
static lean_external_class *arr_class;

static lean_object *box_arr(mlx_array a) {
	if (!arr_class) arr_class = lean_register_external_class(arr_finalize, arr_foreach);
	mlx_array *p = malloc(sizeof *p);
	*p = a;
	return lean_alloc_external(arr_class, p);
}
static mlx_array unbox_arr(b_lean_obj_arg o) { return *(mlx_array *)lean_get_external_data(o); }

static int shape_of(b_lean_obj_arg arr, int *out, int max) {
	size_t n = lean_array_size(arr);
	if ((int)n > max) return -1;
	for (size_t i = 0; i < n; i++) out[i] = (int)lean_unbox(lean_array_get_core(arr, i));
	return (int)n;
}

static mlx_vector_array vec_of(b_lean_obj_arg arr) {
	mlx_vector_array v = mlx_vector_array_new();
	for (size_t i = 0; i < lean_array_size(arr); i++)
		mlx_vector_array_append_value(v, unbox_arr(lean_array_get_core(arr, i)));
	return v;
}

static lean_object *arr_of_vec(mlx_vector_array v) {
	size_t n = mlx_vector_array_size(v);
	lean_object *r = lean_alloc_array(0, n);
	for (size_t i = 0; i < n; i++) {
		mlx_array a = mlx_array_new();
		mlx_vector_array_get(&a, v, i);
		r = lean_array_push(r, box_arr(a));
	}
	return r;
}

// ---- construction and readback ---------------------------------------------

LEAN_EXPORT lean_obj_res smlx_empty(lean_obj_arg u) {
	(void)u;
	return box_arr(mlx_array_new());
}

// ofBytes (data : @& ByteArray) (shape : @& Array Nat) (dtype : UInt8) : IO Arr
LEAN_EXPORT lean_obj_res smlx_of_bytes(b_lean_obj_arg data, b_lean_obj_arg shape, uint8_t dt, lean_obj_arg w) {
	init();
	int s[16];
	int n = shape_of(shape, s, 16);
	if (n < 0) return io_err("ofBytes: rank above 16");
	size_t count = 1;
	for (int i = 0; i < n; i++) count *= (size_t)s[i];
	if (count * mlx_dtype_size((mlx_dtype)dt) != lean_sarray_size(data)) return io_err("ofBytes: byte count does not match the shape");
	mlx_array a = mlx_array_new_data(lean_sarray_cptr(data), s, n, (mlx_dtype)dt);
	return lean_io_result_mk_ok(box_arr(a));
}

// toBytes (a : @& Arr) : IO ByteArray   (evaluates, then copies out row-major)
LEAN_EXPORT lean_obj_res smlx_to_bytes(b_lean_obj_arg o, lean_obj_arg w) {
	init();
	mlx_array a = unbox_arr(o), c = mlx_array_new();
	// A contiguous copy, so a strided view reads back in logical order.
	if (mlx_contiguous(&c, a, false, gpu) || mlx_array_eval(c)) { mlx_array_free(c); return io_err("toBytes"); }
	size_t bytes = mlx_array_size(c) * mlx_dtype_size(mlx_array_dtype(c));
	lean_object *r = lean_alloc_sarray(1, bytes, bytes);
	const void *src = NULL;
	switch (mlx_array_dtype(c)) {
	case MLX_FLOAT32: src = mlx_array_data_float32(c); break;
	case MLX_UINT32: src = mlx_array_data_uint32(c); break;
	case MLX_INT32: src = mlx_array_data_int32(c); break;
	case MLX_UINT64: src = mlx_array_data_uint64(c); break;
	case MLX_INT64: src = mlx_array_data_int64(c); break;
	case MLX_BOOL: src = mlx_array_data_bool(c); break;
	case MLX_UINT8: src = mlx_array_data_uint8(c); break;
	default: mlx_array_free(c); lean_dec(r); return io_err("toBytes: dtype not carried");
	}
	memcpy(lean_sarray_cptr(r), src, bytes);
	mlx_array_free(c);
	return lean_io_result_mk_ok(r);
}

LEAN_EXPORT lean_obj_res smlx_shape(b_lean_obj_arg o, lean_obj_arg w) {
	mlx_array a = unbox_arr(o);
	size_t n = mlx_array_ndim(a);
	const int *s = mlx_array_shape(a);
	lean_object *r = lean_alloc_array(0, n);
	for (size_t i = 0; i < n; i++) r = lean_array_push(r, lean_box((size_t)s[i]));
	return lean_io_result_mk_ok(r);
}

LEAN_EXPORT lean_obj_res smlx_dtype(b_lean_obj_arg o, lean_obj_arg w) {
	return lean_io_result_mk_ok(lean_box((size_t)mlx_array_dtype(unbox_arr(o))));
}

// ---- ops: one mlx-c call each ------------------------------------------------

#define RET(call, what) do { mlx_array r = mlx_array_new(); \
	if (call) { mlx_array_free(r); return io_err(what); } \
	return lean_io_result_mk_ok(box_arr(r)); } while (0)

// unary (op : UInt32) (a : @& Arr) : IO Arr
LEAN_EXPORT lean_obj_res smlx_unary(uint32_t op, b_lean_obj_arg x, lean_obj_arg w) {
	init();
	mlx_array a = unbox_arr(x);
	switch (op) {
	case 0: RET(mlx_negative(&r, a, gpu), "negative");
	case 1: RET(mlx_abs(&r, a, gpu), "abs");
	case 2: RET(mlx_sqrt(&r, a, gpu), "sqrt");
	case 3: RET(mlx_floor(&r, a, gpu), "floor");
	case 4: RET(mlx_exp(&r, a, gpu), "exp");
	case 5: RET(mlx_erf(&r, a, gpu), "erf");
	case 6: RET(mlx_logical_not(&r, a, gpu), "not");
	case 7: RET(mlx_bitwise_invert(&r, a, gpu), "invert");
	case 8: RET(mlx_rsqrt(&r, a, gpu), "rsqrt");
	case 9: RET(mlx_tanh(&r, a, gpu), "tanh");
	case 10: RET(mlx_sigmoid(&r, a, gpu), "sigmoid");
	default: return io_err("unary: unknown op code");
	}
}

// binary (op : UInt32) (a b : @& Arr) : IO Arr
LEAN_EXPORT lean_obj_res smlx_binary(uint32_t op, b_lean_obj_arg x, b_lean_obj_arg y, lean_obj_arg w) {
	init();
	mlx_array a = unbox_arr(x), b = unbox_arr(y);
	switch (op) {
	case 0: RET(mlx_add(&r, a, b, gpu), "add");
	case 1: RET(mlx_subtract(&r, a, b, gpu), "subtract");
	case 2: RET(mlx_multiply(&r, a, b, gpu), "multiply");
	case 3: RET(mlx_divide(&r, a, b, gpu), "divide");
	case 4: RET(mlx_maximum(&r, a, b, gpu), "maximum");
	case 5: RET(mlx_minimum(&r, a, b, gpu), "minimum");
	case 6: RET(mlx_bitwise_and(&r, a, b, gpu), "and");
	case 7: RET(mlx_bitwise_or(&r, a, b, gpu), "or");
	case 8: RET(mlx_bitwise_xor(&r, a, b, gpu), "xor");
	case 9: RET(mlx_left_shift(&r, a, b, gpu), "shift_left");
	case 10: RET(mlx_right_shift(&r, a, b, gpu), "shift_right");
	case 11: RET(mlx_equal(&r, a, b, gpu), "eq");
	case 12: RET(mlx_not_equal(&r, a, b, gpu), "ne");
	case 13: RET(mlx_less(&r, a, b, gpu), "lt");
	case 14: RET(mlx_less_equal(&r, a, b, gpu), "le");
	case 15: RET(mlx_greater(&r, a, b, gpu), "gt");
	case 16: RET(mlx_greater_equal(&r, a, b, gpu), "ge");
	case 17: RET(mlx_matmul(&r, a, b, gpu), "matmul");
	case 18: RET(mlx_remainder(&r, a, b, gpu), "remainder");
	default: return io_err("binary: unknown op code");
	}
}

LEAN_EXPORT lean_obj_res smlx_where(b_lean_obj_arg c, b_lean_obj_arg x, b_lean_obj_arg y, lean_obj_arg w) {
	init();
	RET(mlx_where(&r, unbox_arr(c), unbox_arr(x), unbox_arr(y), gpu), "where");
}

LEAN_EXPORT lean_obj_res smlx_reshape(b_lean_obj_arg x, b_lean_obj_arg shape, lean_obj_arg w) {
	init();
	int s[16];
	int n = shape_of(shape, s, 16);
	RET(n < 0 || mlx_reshape(&r, unbox_arr(x), s, (size_t)n, gpu), "reshape");
}

LEAN_EXPORT lean_obj_res smlx_transpose(b_lean_obj_arg x, b_lean_obj_arg perm, lean_obj_arg w) {
	init();
	int s[16];
	int n = shape_of(perm, s, 16);
	RET(n < 0 || mlx_transpose_axes(&r, unbox_arr(x), s, (size_t)n, gpu), "transpose");
}

LEAN_EXPORT lean_obj_res smlx_broadcast(b_lean_obj_arg x, b_lean_obj_arg shape, lean_obj_arg w) {
	init();
	int s[16];
	int n = shape_of(shape, s, 16);
	RET(n < 0 || mlx_broadcast_to(&r, unbox_arr(x), s, (size_t)n, gpu), "broadcast");
}

LEAN_EXPORT lean_obj_res smlx_slice(b_lean_obj_arg x, b_lean_obj_arg start, b_lean_obj_arg stop, b_lean_obj_arg step, lean_obj_arg w) {
	init();
	int a[16], b[16], c[16];
	int n = shape_of(start, a, 16), m = shape_of(stop, b, 16), k = shape_of(step, c, 16);
	RET(n < 0 || n != m || n != k || mlx_slice(&r, unbox_arr(x), a, n, b, m, c, k, gpu), "slice");
}

LEAN_EXPORT lean_obj_res smlx_concat(b_lean_obj_arg xs, uint32_t axis, lean_obj_arg w) {
	init();
	mlx_vector_array v = vec_of(xs);
	mlx_array r = mlx_array_new();
	int e = mlx_concatenate_axis(&r, v, (int)axis, gpu);
	mlx_vector_array_free(v);
	if (e) { mlx_array_free(r); return io_err("concatenate"); }
	return lean_io_result_mk_ok(box_arr(r));
}

LEAN_EXPORT lean_obj_res smlx_astype(b_lean_obj_arg x, uint8_t dt, lean_obj_arg w) {
	init();
	RET(mlx_astype(&r, unbox_arr(x), (mlx_dtype)dt, gpu), "astype");
}

LEAN_EXPORT lean_obj_res smlx_view(b_lean_obj_arg x, uint8_t dt, lean_obj_arg w) {
	init();
	RET(mlx_view(&r, unbox_arr(x), (mlx_dtype)dt, gpu), "view");
}

LEAN_EXPORT lean_obj_res smlx_take(b_lean_obj_arg x, b_lean_obj_arg idx, uint32_t axis, lean_obj_arg w) {
	init();
	RET(mlx_take_axis(&r, unbox_arr(x), unbox_arr(idx), (int)axis, gpu), "take");
}

LEAN_EXPORT lean_obj_res smlx_contiguous(b_lean_obj_arg x, lean_obj_arg w) {
	init();
	RET(mlx_contiguous(&r, unbox_arr(x), false, gpu), "contiguous");
}

LEAN_EXPORT lean_obj_res smlx_eval(b_lean_obj_arg xs, lean_obj_arg w) {
	init();
	mlx_vector_array v = vec_of(xs);
	int e = mlx_eval(v) || mlx_synchronize(gpu);
	mlx_vector_array_free(v);
	if (e) return io_err("eval");
	return lean_io_result_mk_ok(lean_box(0));
}

// ---- custom Metal kernels ------------------------------------------------------

static void kern_finalize(void *p) {
	mlx_fast_metal_kernel_free(*(mlx_fast_metal_kernel *)p);
	free(p);
}
static lean_external_class *kern_class;

// kernelNew (name : @& String) (inputs outputs : @& Array String) (source header : @& String) : IO Kernel
LEAN_EXPORT lean_obj_res smlx_kernel_new(b_lean_obj_arg name, b_lean_obj_arg ins, b_lean_obj_arg outs,
                                         b_lean_obj_arg src, b_lean_obj_arg hdr, lean_obj_arg w) {
	init();
	if (!kern_class) kern_class = lean_register_external_class(kern_finalize, arr_foreach);
	mlx_vector_string vi = mlx_vector_string_new(), vo = mlx_vector_string_new();
	for (size_t i = 0; i < lean_array_size(ins); i++) mlx_vector_string_append_value(vi, lean_string_cstr(lean_array_get_core(ins, i)));
	for (size_t i = 0; i < lean_array_size(outs); i++) mlx_vector_string_append_value(vo, lean_string_cstr(lean_array_get_core(outs, i)));
	mlx_fast_metal_kernel *k = malloc(sizeof *k);
	// Row-contiguous inputs: the kernels index flat buffers.
	*k = mlx_fast_metal_kernel_new(lean_string_cstr(name), vi, vo, lean_string_cstr(src), lean_string_cstr(hdr), true, false);
	mlx_vector_string_free(vi);
	mlx_vector_string_free(vo);
	return lean_io_result_mk_ok(lean_alloc_external(kern_class, k));
}

// kernelApply (k : @& Kernel) (inputs : @& Array Arr) (outShapes : @& Array (Array Nat))
//   (outDtypes : @& ByteArray) (grid tg : @& Array Nat) : IO (Array Arr)
LEAN_EXPORT lean_obj_res smlx_kernel_apply(b_lean_obj_arg ko, b_lean_obj_arg ins, b_lean_obj_arg shapes,
                                           b_lean_obj_arg dts, b_lean_obj_arg grid, b_lean_obj_arg tg, lean_obj_arg w) {
	init();
	mlx_fast_metal_kernel k = *(mlx_fast_metal_kernel *)lean_get_external_data(ko);
	mlx_fast_metal_kernel_config cfg = mlx_fast_metal_kernel_config_new();
	for (size_t i = 0; i < lean_array_size(shapes); i++) {
		int s[16];
		int n = shape_of(lean_array_get_core(shapes, i), s, 16);
		mlx_fast_metal_kernel_config_add_output_arg(cfg, s, (size_t)n, (mlx_dtype)lean_sarray_cptr(dts)[i]);
	}
	int g[3], t[3];
	if (shape_of(grid, g, 3) != 3 || shape_of(tg, t, 3) != 3) { mlx_fast_metal_kernel_config_free(cfg); return io_err("kernel: grid and threadgroup need 3 entries"); }
	mlx_fast_metal_kernel_config_set_grid(cfg, g[0], g[1], g[2]);
	mlx_fast_metal_kernel_config_set_thread_group(cfg, t[0], t[1], t[2]);
	mlx_vector_array vi = vec_of(ins), vo = mlx_vector_array_new();
	int e = mlx_fast_metal_kernel_apply(&vo, k, vi, cfg, gpu);
	mlx_fast_metal_kernel_config_free(cfg);
	mlx_vector_array_free(vi);
	if (e) { mlx_vector_array_free(vo); return io_err("kernel apply"); }
	lean_object *r = arr_of_vec(vo);
	mlx_vector_array_free(vo);
	return lean_io_result_mk_ok(r);
}

// ---- mx::compile over a Lean function -----------------------------------------

static void fn_finalize(void *p) {
	mlx_closure_free(*(mlx_closure *)p);
	free(p);
}
static lean_external_class *fn_class;

static void payload_dtor(void *p) { lean_dec((lean_object *)p); }

// The trampoline: mlx traces the closure by calling it with placeholder arrays;
// it runs the Lean function (Array Arr -> IO (Array Arr)) on them.
static int trampoline(mlx_vector_array *res, const mlx_vector_array in, void *payload) {
	lean_object *f = (lean_object *)payload;
	lean_object *args = arr_of_vec(in);
	lean_inc(f);
	lean_object *r = lean_apply_2(f, args, lean_io_mk_world());
	if (lean_io_result_is_error(r)) {
		lean_object *err = lean_io_result_get_error(r);
		lean_inc(err);  // lean_io_error_to_string consumes its argument; r still owns err
		lean_object *msg = lean_io_error_to_string(err);
		snprintf(trace_error, sizeof trace_error, "traced function: %s", lean_string_cstr(msg));
		lean_dec(msg);
		lean_dec(r);
		return 1;
	}
	lean_object *outs = lean_io_result_get_value(r);
	mlx_vector_array v = vec_of(outs);
	mlx_vector_array_set(res, v);
	mlx_vector_array_free(v);
	lean_dec(r);
	return 0;
}

// compile (f : Array Arr → IO (Array Arr)) (enable : Bool) : IO Fn
LEAN_EXPORT lean_obj_res smlx_compile(lean_obj_arg f, uint8_t enable, lean_obj_arg w) {
	init();
	if (!fn_class) fn_class = lean_register_external_class(fn_finalize, arr_foreach);
	mlx_closure raw = mlx_closure_new_func_payload(trampoline, f, payload_dtor);
	mlx_closure *c = malloc(sizeof *c);
	*c = mlx_closure_new();
	if (enable) {
		if (mlx_compile(c, raw, false)) { mlx_closure_free(raw); free(c); return io_err("compile"); }
		mlx_closure_free(raw);
	} else {
		mlx_closure_set(c, raw);
		mlx_closure_free(raw);
	}
	return lean_io_result_mk_ok(lean_alloc_external(fn_class, c));
}

LEAN_EXPORT lean_obj_res smlx_apply(b_lean_obj_arg fo, b_lean_obj_arg ins, lean_obj_arg w) {
	init();
	mlx_closure c = *(mlx_closure *)lean_get_external_data(fo);
	mlx_vector_array vi = vec_of(ins), vo = mlx_vector_array_new();
	int e = mlx_closure_apply(&vo, c, vi);
	mlx_vector_array_free(vi);
	if (e) { mlx_vector_array_free(vo); return io_err("apply"); }
	lean_object *r = arr_of_vec(vo);
	mlx_vector_array_free(vo);
	return lean_io_result_mk_ok(r);
}

// ---- test-driver helpers ---------------------------------------------------------

// The platform erff over `count` consecutive bit patterns: the CPU side of the
// exhaustive check. A loop over libm, nothing else.
LEAN_EXPORT lean_obj_res smlx_libm_erff_range(uint32_t base, uint32_t count, lean_obj_arg w) {
	lean_object *r = lean_alloc_sarray(1, (size_t)count * 4, (size_t)count * 4);
	uint32_t *o = (uint32_t *)lean_sarray_cptr(r);
	for (uint32_t i = 0; i < count; i++) {
		uint32_t b = base + i;
		float x, y;
		memcpy(&x, &b, 4);
		y = erff(x);
		memcpy(&o[i], &y, 4);
	}
	return lean_io_result_mk_ok(r);
}

LEAN_EXPORT lean_obj_res smlx_count_nonzero(b_lean_obj_arg x, lean_obj_arg w) {
	init();
	mlx_array a = unbox_arr(x), nz = mlx_array_new(), c = mlx_array_new(), s = mlx_array_new();
	mlx_array zero = mlx_array_new_int(0);
	int e = mlx_not_equal(&nz, a, zero, gpu) || mlx_astype(&c, nz, MLX_INT64, gpu) || mlx_sum(&s, c, false, gpu) || mlx_array_eval(s);
	int64_t n = e ? 0 : mlx_array_data_int64(s)[0];
	mlx_array_free(nz); mlx_array_free(c); mlx_array_free(s); mlx_array_free(zero);
	if (e) return io_err("count_nonzero");
	return lean_io_result_mk_ok(lean_box((size_t)n));
}
