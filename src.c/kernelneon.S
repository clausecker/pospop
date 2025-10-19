	.section .rodata
	.balign	16
magic:	.quad	0x8040201008040201
	.quad	0, 0, -1, -1
	.size	magic, .-magic

	.section .text
	// X0: accumulation function
	// X1: input buffer
	// X2: counters
	// X3: remaining length
countneon:
	str	x30, [sp, #-16]!
	adrp	x4, magic
	add	x4, x4, #:lo12:magic
	ld1r	{v28.2d}, [x4], #8
	movi	v30.8b, #0x1
	movi	v29.16b, #0x2
	add	v29.16b, v29.16b, v30.16b
	movi	v8.16b, #0x0
	movi	v10.16b, #0x0
	movi	v12.16b, #0x0
	movi	v14.16b, #0x0
	cmp	x3, #0xf0
	blt	.Lrunt

	and	x6, x1, #0xf
	and	x1, x1, #0xfffffffffffffff0
	sub	x5, x6, #0x10
	add	x3, x3, x6
	neg	x5, x5
	ld1	{v3.16b}, [x1], #16
	ldr	q5, [x4, x5]
	and	v0.16b, v3.16b, v5.16b
	ld1	{v1.16b, v2.16b}, [x1], #32
	ld1	{v3.16b-v6.16b}, [x1], #64
	ld1	{v16.16b-v19.16b}, [x1], #64
	eor	v31.16b, v0.16b, v1.16b
	eor	v0.16b, v31.16b, v2.16b
	bit	v1.16b, v2.16b, v31.16b
	movi	v27.16b, #0x55
	eor	v2.16b, v3.16b, v0.16b
	eor	v0.16b, v4.16b, v2.16b
	bsl	v2.16b, v4.16b, v3.16b
	movi	v26.16b, #0x33
	eor	v3.16b, v5.16b, v0.16b
	eor	v0.16b, v6.16b, v3.16b
	bsl	v3.16b, v6.16b, v5.16b
	ld1	{v4.16b-v7.16b}, [x1], #64
	eor	v31.16b, v1.16b, v2.16b
	eor	v1.16b, v31.16b, v3.16b
	bit	v2.16b, v3.16b, v31.16b
	eor	v31.16b, v0.16b, v16.16b
	eor	v0.16b, v31.16b, v17.16b
	bit	v16.16b, v17.16b, v31.16b
	movi	v25.16b, #0xf
	eor	v31.16b, v0.16b, v18.16b
	eor	v0.16b, v31.16b, v19.16b
	bit	v18.16b, v19.16b, v31.16b
	mov	x6, #65535
	eor	v3.16b, v16.16b, v1.16b
	eor	v1.16b, v18.16b, v3.16b
	bsl	v3.16b, v18.16b, v16.16b
	movi	v9.16b, #0x0
	eor	v31.16b, v0.16b, v4.16b
	eor	v0.16b, v31.16b, v5.16b
	bit	v4.16b, v5.16b, v31.16b
	movi	v11.16b, #0x0
	eor	v31.16b, v0.16b, v6.16b
	eor	v0.16b, v31.16b, v7.16b
	bit	v6.16b, v7.16b, v31.16b
	movi	v13.16b, #0x0
	eor	v31.16b, v1.16b, v4.16b
	eor	v1.16b, v31.16b, v6.16b
	bit	v4.16b, v6.16b, v31.16b
	movi	v15.16b, #0x0
	eor	v31.16b, v2.16b, v3.16b
	eor	v2.16b, v31.16b, v4.16b
	bit	v3.16b, v4.16b, v31.16b
	subs	x3, x3, #0x1f0
	blt	.Lpost

.Lvec:	ld1	{v4.16b-v7.16b}, [x1], #64
	ld1	{v16.16b-v19.16b}, [x1], #64
	ld1	{v20.16b-v23.16b}, [x1], #64
	eor	v31.16b, v4.16b, v5.16b
	eor	v4.16b, v31.16b, v6.16b
	bit	v5.16b, v6.16b, v31.16b
	eor	v31.16b, v0.16b, v17.16b
	eor	v0.16b, v31.16b, v19.16b
	bit	v17.16b, v19.16b, v31.16b
	eor	v31.16b, v7.16b, v16.16b
	eor	v7.16b, v31.16b, v18.16b
	bit	v16.16b, v18.16b, v31.16b
	eor	v31.16b, v21.16b, v22.16b
	eor	v21.16b, v31.16b, v20.16b
	bit	v22.16b, v20.16b, v31.16b
	eor	v31.16b, v1.16b, v5.16b
	eor	v1.16b, v31.16b, v17.16b
	bit	v5.16b, v17.16b, v31.16b
	ld1	{v17.16b-v20.16b}, [x1], #64
	eor	v31.16b, v0.16b, v4.16b
	eor	v0.16b, v31.16b, v7.16b
	bit	v4.16b, v7.16b, v31.16b
	eor	v31.16b, v17.16b, v18.16b
	eor	v17.16b, v31.16b, v23.16b
	bit	v18.16b, v23.16b, v31.16b
	eor	v31.16b, v19.16b, v20.16b
	eor	v19.16b, v31.16b, v21.16b
	bit	v20.16b, v21.16b, v31.16b
	eor	v31.16b, v16.16b, v18.16b
	eor	v16.16b, v31.16b, v22.16b
	bit	v18.16b, v22.16b, v31.16b
	eor	v31.16b, v1.16b, v4.16b
	eor	v1.16b, v31.16b, v20.16b
	bit	v4.16b, v20.16b, v31.16b
	eor	v31.16b, v0.16b, v17.16b
	eor	v0.16b, v31.16b, v19.16b
	bit	v17.16b, v19.16b, v31.16b
	eor	v31.16b, v2.16b, v5.16b
	eor	v2.16b, v31.16b, v18.16b
	bit	v5.16b, v18.16b, v31.16b
	eor	v31.16b, v1.16b, v16.16b
	eor	v1.16b, v31.16b, v17.16b
	bit	v16.16b, v17.16b, v31.16b
	eor	v31.16b, v2.16b, v4.16b
	eor	v2.16b, v31.16b, v16.16b
	bit	v4.16b, v16.16b, v31.16b
	eor	v31.16b, v3.16b, v4.16b
	eor	v3.16b, v31.16b, v5.16b
	bit	v4.16b, v5.16b, v31.16b
	and	v5.16b, v4.16b, v27.16b
	bic	v6.16b, v4.16b, v27.16b
	ushr	v6.16b, v6.16b, #1
	zip1	v4.2d, v5.2d, v6.2d
	zip2	v5.2d, v5.2d, v6.2d
	add	v4.16b, v4.16b, v5.16b
	and	v5.16b, v4.16b, v26.16b
	bic	v6.16b, v4.16b, v26.16b
	ushr	v6.16b, v6.16b, #2
	and	v4.16b, v5.16b, v25.16b
	bic	v5.16b, v5.16b, v25.16b
	bic	v7.16b, v6.16b, v25.16b
	and	v6.16b, v6.16b, v25.16b
	shl	v4.16b, v4.16b, #4
	shl	v6.16b, v6.16b, #4
	zip1	v16.16b, v4.16b, v6.16b
	zip2	v17.16b, v4.16b, v6.16b
	zip1	v18.16b, v5.16b, v7.16b
	zip2	v19.16b, v5.16b, v7.16b
	zip1	v4.16b, v16.16b, v17.16b
	zip2	v5.16b, v16.16b, v17.16b
	zip1	v6.16b, v18.16b, v19.16b
	zip2	v7.16b, v18.16b, v19.16b
	zip1	v16.4s, v4.4s, v6.4s
	zip2	v17.4s, v4.4s, v6.4s
	zip1	v18.4s, v5.4s, v7.4s
	zip2	v19.4s, v5.4s, v7.4s
	uaddw	v8.8h, v8.8h, v16.8b
	uaddw2	v9.8h, v9.8h, v16.16b
	uaddw	v10.8h, v10.8h, v17.8b
	uaddw2	v11.8h, v11.8h, v17.16b
	uaddw	v12.8h, v12.8h, v18.8b
	uaddw2	v13.8h, v13.8h, v18.16b
	uaddw	v14.8h, v14.8h, v19.8b
	uaddw2	v15.8h, v15.8h, v19.16b
	sub	x6, x6, #0x20
	cmp	x6, #0x3c
	bge	.Lhave_space

	blr	x0
	movi	v8.16b, #0x0
	movi	v9.16b, #0x0
	movi	v10.16b, #0x0
	movi	v11.16b, #0x0
	movi	v12.16b, #0x0
	movi	v13.16b, #0x0
	movi	v14.16b, #0x0
	movi	v15.16b, #0x0
	mov	x6, #65535

.Lhave_space:
	subs	x3, x3, #0x100
	bge	.Lvec

.Lpost:	ushr	v4.16b, v0.16b, #1
	add	v5.16b, v1.16b, v1.16b
	ushr	v6.16b, v2.16b, #1
	add	v7.16b, v3.16b, v3.16b
	bif	v0.16b, v5.16b, v27.16b
	bit	v1.16b, v4.16b, v27.16b
	bif	v2.16b, v7.16b, v27.16b
	bit	v3.16b, v6.16b, v27.16b
	ushr	v4.16b, v0.16b, #2
	ushr	v6.16b, v1.16b, #2
	shl	v5.16b, v2.16b, #2
	shl	v7.16b, v3.16b, #2
	bit	v2.16b, v4.16b, v26.16b
	bit	v3.16b, v6.16b, v26.16b
	bif	v0.16b, v5.16b, v26.16b
	bif	v1.16b, v7.16b, v26.16b
	zip1	v6.16b, v2.16b, v3.16b
	zip2	v3.16b, v2.16b, v3.16b
	zip1	v5.16b, v0.16b, v1.16b
	zip2	v2.16b, v0.16b, v1.16b
	zip1	v4.8h, v5.8h, v6.8h
	zip2	v5.8h, v5.8h, v6.8h
	zip1	v6.8h, v2.8h, v3.8h
	zip2	v7.8h, v2.8h, v3.8h
	and	v0.16b, v25.16b, v4.16b
	ushr	v4.16b, v4.16b, #4
	and	v1.16b, v25.16b, v5.16b
	ushr	v5.16b, v5.16b, #4
	and	v2.16b, v25.16b, v6.16b
	add	v0.16b, v2.16b, v0.16b
	usra	v4.16b, v6.16b, #4
	and	v3.16b, v25.16b, v7.16b
	add	v1.16b, v3.16b, v1.16b
	usra	v5.16b, v7.16b, #4
	zip1	v2.4s, v0.4s, v4.4s
	zip2	v3.4s, v0.4s, v4.4s
	zip1	v6.4s, v1.4s, v5.4s
	zip2	v7.4s, v1.4s, v5.4s
	uaddw	v8.8h, v8.8h, v2.8b
	uaddw2	v9.8h, v9.8h, v2.16b
	uaddw	v10.8h, v10.8h, v3.8b
	uaddw2	v11.8h, v11.8h, v3.16b
	uaddw	v12.8h, v12.8h, v6.8b
	uaddw2	v13.8h, v13.8h, v6.16b
	uaddw	v14.8h, v14.8h, v7.8b
	uaddw2	v15.8h, v15.8h, v7.16b

.Lendvec:
	movi	v0.16b, #0x0
	movi	v1.16b, #0x0
	movi	v2.16b, #0x0
	movi	v3.16b, #0x0
	adds	x3, x3, #0xf8
	blt	.Ltail1

.Ltail8:
	subs	x3, x3, #0x8
	ldr	s6, [x1], #4
	ldr	s7, [x1], #4
	tbl	v4.16b, {v6.16b}, v30.16b
	tbl	v5.16b, {v6.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v0.16b, v0.16b, v4.16b
	sub	v1.16b, v1.16b, v5.16b
	tbl	v4.16b, {v7.16b}, v30.16b
	tbl	v5.16b, {v7.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v2.16b, v2.16b, v4.16b
	sub	v3.16b, v3.16b, v5.16b
	bge	.Ltail8

.Ltail1:
	adds	x3, x3, #0x8
	ble	.Lend

	ldr	d6, [x1]
	sub	x6, x4, x3
	ldr	q5, [x6, #16]
	bic	v6.16b, v6.16b, v5.16b
	ext	v7.16b, v6.16b, v6.16b, #4
	tbl	v4.16b, {v6.16b}, v30.16b
	tbl	v5.16b, {v6.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v0.16b, v0.16b, v4.16b
	sub	v1.16b, v1.16b, v5.16b
	tbl	v4.16b, {v7.16b}, v30.16b
	tbl	v5.16b, {v7.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v2.16b, v2.16b, v4.16b
	sub	v3.16b, v3.16b, v5.16b

.Lend:	uaddw	v9.8h, v9.8h, v0.8b
	uaddw2	v8.8h, v8.8h, v0.16b
	uaddw	v11.8h, v11.8h, v1.8b
	uaddw2	v10.8h, v10.8h, v1.16b
	uaddw	v13.8h, v13.8h, v2.8b
	uaddw2	v12.8h, v12.8h, v2.16b
	uaddw	v15.8h, v15.8h, v3.8b
	uaddw2	v14.8h, v14.8h, v3.16b
	blr	x0
	ldr	x30, [sp], #16
	ret

.Lrunt:	subs	x3, x3, #0x8
	blt	.Lrunt1

.Lrunt8:
	subs	x3, x3, #0x8
	ldr	s6, [x1], #4
	ldr	s7, [x1], #4
	tbl	v4.16b, {v6.16b}, v30.16b
	tbl	v5.16b, {v6.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v8.16b, v8.16b, v4.16b
	sub	v10.16b, v10.16b, v5.16b
	tbl	v4.16b, {v7.16b}, v30.16b
	tbl	v5.16b, {v7.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v12.16b, v12.16b, v4.16b
	sub	v14.16b, v14.16b, v5.16b
	bge	.Lrunt8

.Lrunt1:
	adds	x3, x3, #0x8
	ble	.Lrunt_accum

	and	x5, x1, #0x7
	add	x8, x3, x5
	lsl	x3, x3, #3
	mov	x7, #0xffffffffffffffff    	// #-1
	lsl	x7, x7, x3
	cmp	x8, #0x8
	bgt	.Lcrossrunt1

	and	x1, x1, #0xfffffffffffffff8
	ldr	x6, [x1]
	lsl	x5, x5, #3
	lsr	x6, x6, x5
	b	.Ldorunt1

.Lcrossrunt1:
	ldr	x6, [x1]

.Ldorunt1:
	bic	x6, x6, x7
	fmov	d6, x6
	ext	v7.16b, v6.16b, v6.16b, #4
	tbl	v4.16b, {v6.16b}, v30.16b
	tbl	v5.16b, {v6.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v8.16b, v8.16b, v4.16b
	sub	v10.16b, v10.16b, v5.16b
	tbl	v4.16b, {v7.16b}, v30.16b
	tbl	v5.16b, {v7.16b}, v29.16b
	cmtst	v4.16b, v4.16b, v28.16b
	cmtst	v5.16b, v5.16b, v28.16b
	sub	v12.16b, v12.16b, v4.16b
	sub	v14.16b, v14.16b, v5.16b

.Lrunt_accum:
	uxtl	v9.8h, v8.8b
	uxtl2	v8.8h, v8.16b
	uxtl	v11.8h, v10.8b
	uxtl2	v10.8h, v10.16b
	uxtl	v13.8h, v12.8b
	uxtl2	v12.8h, v12.16b
	uxtl	v15.8h, v14.8b
	uxtl2	v14.8h, v14.16b
	blr	x0
	ldr	x30, [sp], #16
	ret
	.size	countneon, .-countneon

	.globl	count8neon
	.type	count8neon, %function
	// extern void count8neon(flags_type *flags, const uint16_t *data, uint32_t len);
count8neon:
	sub	x3, sp, #4*16
	str	x30, [sp, #-5*16]!
	st1	{v8.1d-v11.1d}, [x3], #32
	st1	{v12.1d-v15.1d}, [x3], #32
	mov	w3, w2
	mov	x2, x0
	adr	x0, accum8
	bl	countneon
	ldr	x30, [sp], #16
	ld1	{v8.1d-v11.1d}, [sp], #32
	ld1	{v12.1d-v15.1d}, [sp], #32
	ret
	.size	count8neon, .-count8neon

	.globl	count16neon
	.type	count16neon, %function
	// extern void count16neon(flags_type *flags, const uint16_t *data, uint32_t len);
count16neon:
	sub	x3, sp, #4*16
	str	x30, [sp, #-5*16]!
	st1	{v8.1d-v11.1d}, [x3], #32
	st1	{v12.1d-v15.1d}, [x3], #32
	ubfiz	x3, x2, #1, #32
	mov	x2, x0
	adr	x0, accum16
	bl	countneon
	ldr	x30, [sp], #16
	ld1	{v8.1d-v11.1d}, [sp], #32
	ld1	{v12.1d-v15.1d}, [sp], #32
	ret
	.size	count16neon, .-count16neon

	.globl	count32neon
	.type	count32neon, %function
	// extern void count32neon(flags_type *flags, const uint16_t *data, uint32_t len);
count32neon:
	sub	x3, sp, #4*16
	str	x30, [sp, #-5*16]!
	st1	{v8.1d-v11.1d}, [x3], #32
	st1	{v12.1d-v15.1d}, [x3], #32
	ubfiz	x3, x2, #2, #32
	mov	x2, x0
	adr	x0, accum32
	bl	countneon
	ldr	x30, [sp], #16
	ld1	{v8.1d-v11.1d}, [sp], #32
	ld1	{v12.1d-v15.1d}, [sp], #32
	ret
	.size	count32neon, .-count32neon

	.globl	count64neon
	.type	count64neon, %function
	// extern void count64neon(flags_type *flags, const uint16_t *data, uint32_t len);
count64neon:
	sub	x3, sp, #4*16
	str	x30, [sp, #-5*16]!
	st1	{v8.1d-v11.1d}, [x3], #32
	st1	{v12.1d-v15.1d}, [x3], #32
	ubfiz	x3, x2, #3, #32
	mov	x2, x0
	adr	x0, accum64
	bl	countneon
	ldr	x30, [sp], #16
	ld1	{v8.1d-v11.1d}, [sp], #32
	ld1	{v12.1d-v15.1d}, [sp], #32
	ret
	.size	count64neon, .-count64neon
