/-!
# `StablehloMlx.Mlx` — the MLX arrays, ops and kernels, through the C shim

Every declaration is one `@[extern]` into `c/smlx_shim.c`, which makes one
mlx-c call. Arrays live on the default GPU stream and stay there between calls;
nothing is copied to the host until `toBytes`.
-/

namespace StablehloMlx.Mlx

/-- An MLX array (lazily evaluated, on the GPU stream). -/
opaque ArrP : NonemptyType
def Arr := ArrP.type
instance : Nonempty Arr := ArrP.property
/-- An empty array: the default an out-of-range `xs[i]!` returns after its panic. -/
@[extern "smlx_empty"] opaque emptyArr (u : Unit) : Arr
instance : Inhabited Arr := ⟨emptyArr ()⟩

opaque KernelP : NonemptyType
/-- A compiled-on-first-use Metal kernel (mx::fast::metal_kernel). -/
def Kernel := KernelP.type
instance : Nonempty Kernel := KernelP.property

opaque FnP : NonemptyType
/-- A traced function, compiled with mx::compile when asked. -/
def Fn := FnP.type
instance : Nonempty Fn := FnP.property

/-- mlx_dtype codes (mlx/c/array.h, in enum order). -/
def dtBool : UInt8 := 0
def dtU8 : UInt8 := 1
def dtU32 : UInt8 := 3
def dtU64 : UInt8 := 4
def dtI32 : UInt8 := 7
def dtI64 : UInt8 := 8
def dtF16 : UInt8 := 9
def dtF32 : UInt8 := 10

@[extern "smlx_of_bytes"] opaque ofBytes (data : @& ByteArray) (shape : @& Array Nat) (dtype : UInt8) : IO Arr
@[extern "smlx_to_bytes"] opaque toBytes (a : @& Arr) : IO ByteArray
@[extern "smlx_shape"] opaque shape (a : @& Arr) : IO (Array Nat)
@[extern "smlx_dtype"] opaque dtype (a : @& Arr) : IO Nat

@[extern "smlx_unary"] opaque unary (op : UInt32) (a : @& Arr) : IO Arr
@[extern "smlx_binary"] opaque binary (op : UInt32) (a b : @& Arr) : IO Arr
@[extern "smlx_where"] opaque where_ (c a b : @& Arr) : IO Arr
@[extern "smlx_reshape"] opaque reshape (a : @& Arr) (shape : @& Array Nat) : IO Arr
@[extern "smlx_transpose"] opaque transpose (a : @& Arr) (perm : @& Array Nat) : IO Arr
@[extern "smlx_broadcast"] opaque broadcast (a : @& Arr) (shape : @& Array Nat) : IO Arr
@[extern "smlx_slice"] opaque slice (a : @& Arr) (start stop step : @& Array Nat) : IO Arr
@[extern "smlx_concat"] opaque concat (xs : @& Array Arr) (axis : UInt32) : IO Arr
@[extern "smlx_astype"] opaque astype (a : @& Arr) (dtype : UInt8) : IO Arr
@[extern "smlx_view"] opaque view (a : @& Arr) (dtype : UInt8) : IO Arr
@[extern "smlx_take"] opaque take (a idx : @& Arr) (axis : UInt32) : IO Arr
/-- The largest element along `axis` (the axis is removed). -/
@[extern "smlx_max_axis"] opaque maxAxis (a : @& Arr) (axis : UInt32) : IO Arr
@[extern "smlx_contiguous"] opaque contiguous (a : @& Arr) : IO Arr
@[extern "smlx_eval"] opaque eval (xs : @& Array Arr) : IO Unit

@[extern "smlx_kernel_new"]
opaque kernelNew (name : @& String) (inputs outputs : @& Array String) (source header : @& String) : IO Kernel
@[extern "smlx_kernel_apply"]
opaque kernelApply (k : @& Kernel) (inputs : @& Array Arr) (outShapes : @& Array (Array Nat))
  (outDtypes : @& ByteArray) (grid threadgroup : @& Array Nat) : IO (Array Arr)

@[extern "smlx_compile"] opaque compile (f : Array Arr → IO (Array Arr)) (enable : Bool) : IO Fn
@[extern "smlx_apply"] opaque apply (f : @& Fn) (inputs : @& Array Arr) : IO (Array Arr)

/-- The platform `erff` over `count` consecutive bit patterns from `base`, on the
    CPU: the reference side of the exhaustive erf check. -/
@[extern "smlx_libm_erff_range"] opaque libmErffRange (base count : UInt32) : IO ByteArray
/-- Number of nonzero elements (an exact count, as int64, evaluated). -/
@[extern "smlx_count_nonzero"] opaque countNonzero (a : @& Arr) : IO Nat

-- unary op codes (smlx_unary)
def opNeg : UInt32 := 0
def opAbs : UInt32 := 1
def opSqrt : UInt32 := 2
def opFloor : UInt32 := 3
def opExp : UInt32 := 4
def opErf : UInt32 := 5
def opNot : UInt32 := 6
def opInvert : UInt32 := 7
def opRsqrt : UInt32 := 8
def opTanh : UInt32 := 9
def opSigmoid : UInt32 := 10
-- binary op codes (smlx_binary)
def opAdd : UInt32 := 0
def opSub : UInt32 := 1
def opMul : UInt32 := 2
def opDiv : UInt32 := 3
def opMax : UInt32 := 4
def opMin : UInt32 := 5
def opAnd : UInt32 := 6
def opOr : UInt32 := 7
def opXor : UInt32 := 8
def opShl : UInt32 := 9
def opShr : UInt32 := 10
def opEq : UInt32 := 11
def opNe : UInt32 := 12
def opLt : UInt32 := 13
def opLe : UInt32 := 14
def opGt : UInt32 := 15
def opGe : UInt32 := 16
def opMatmul : UInt32 := 17
def opRem : UInt32 := 18
def opLAnd : UInt32 := 19
def opLOr : UInt32 := 20

/-- Little-endian bytes of a list of 32-bit words. -/
def wordsToBytes (ws : Array UInt32) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (4 * ws.size)
  for w in ws do
    b := b.push (w &&& 0xFF).toUInt8
    b := b.push ((w >>> 8) &&& 0xFF).toUInt8
    b := b.push ((w >>> 16) &&& 0xFF).toUInt8
    b := b.push ((w >>> 24) &&& 0xFF).toUInt8
  return b

def u32Arr (ws : Array UInt32) : IO Arr := ofBytes (wordsToBytes ws) #[ws.size] dtU32

/-- Little-endian bytes of 64-bit words. -/
def words64ToBytes (ws : Array UInt64) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (8 * ws.size)
  for w in ws do
    for k in List.range 8 do b := b.push ((w >>> (8 * k).toUInt64) &&& 0xFF).toUInt8
  return b

/-- A uint64 scalar array (also the carrier of a binary64 bit pattern). -/
def u64Scalar (w : UInt64) : IO Arr := ofBytes (words64ToBytes #[w]) #[] dtU64

/-- A float32 scalar array from its bit pattern. -/
def f32Scalar (bits : UInt32) : IO Arr := ofBytes (wordsToBytes #[bits]) #[] dtF32

end StablehloMlx.Mlx
