	// b:a = a+b+c, v31.16b used for scratch space
	.macro csa, a, b, c
	eor v31.16b, \a\().16b, \b\().16b
	eor \a\().16b, v31.16b, \c\().16b
	bit \b\().16b, \c\().16b, v31.16b
	.endm

	// d:a = a+b+c
	.macro csac a, b, c, d
	eor \d\().16b, \a\().16b, \b\().16b
	eor \a\().16b, \d\().16b, \c\().16b
	bsl \d\().16b, \c\().16b, \b\().16b
	.endm

	.type count8asm15, @function
	.globl count8asm15
	// X0: counts
	// X1: buf
	// X2: len
count8asm15:
	ld1 {V16.2D-V19.2D}, [X0]	// load counts into V16-19

	ldr d29, .Lmask			// bit mask into v29.8b
	movi v30.8b, #0			// scalar counter vector v30.8b

	cmp x2, #16			// enough data for at least one vector iteration?
	blt 2f				// if not, go straight to scalar tail

	// scalar head to reach 16 byte alignment
	and x3, x2, #15			// how far we are off the alignment
	cbz x3, 3f			// skip scalar head if already aligned	
	sub x2, x2, x3			// apply alignment to x2
	tst x3, #1			// unroll loop once (duff style)
	bne 1f

	// scalar loop: process one byte at a time
0:	ld1r {v2.8b}, [x1], #1		// load same byte to each elem of v2
	cmtst v2.8b, v29.8b, v2.8b	// set counter bytes to 0 or -1 according to [x0] bits
	sub v30.8b, v30.8b, v2.8b	// and increment counters

1:	ld1r {v2.8b}, [x1], #1		// load same byte to each elem of v2
	cmtst v2.8b, v29.8b, v2.8b	// set counter bytes to 0 or -1 according to [x0] bits
	sub v30.8b, v30.8b, v2.8b	// and increment counters

	subs x3, x3, #2
	bgt 0b

3:	movi v20.16b, #0x11		// bit masks for getting out the values
	movi v21.16b, #0x22
	movi v22.16b, #0x44
	movi v23.16b, #0x88
	movi v24.16b, #0x0f

	cmp x2, #15*16			// enough data to process 240 bytes?
	blt 1f

	// 15-fold CSA reduction
0:	ld1 {v0.16b-v2.16b}, [x1], #3*16
	ld1 {v3.16b-v6.16b}, [x1], #4*16
	ld1 {v25.16b-v28.16b}, [x1], #4*16
	csa v0, v1, v2
	csac v0, v3, v4, v2
	csac v0, v5, v6, v3
	ld1 {v4.16b-v7.16b}, [x1], #4*16
	csa v1, v2, v3
	csa v0, v25, v26
	csa v0, v27, v28
	csac v1, v25, v27, v3
	csa v0, v4, v5
	csa v0, v6, v7
	csa v1, v4, v6
	csa v2, v3, v4

	// V3:V2:V1:V0 = SUM([x1,#0*16]...[x1,#14*16])
	// approach: first fold V3...V0 into four registers, each
	// acumulating two pairs of V3:V2:V1:V0 (one per nibble)
	// then, unravel the pairs and sum up

	// partial counts register: V4--V7
	// group counts into nibbles
	and v4.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	shl v25.16b, v1.16b, #1
	bit v4.16b, v25.16b, v21.16b
	shl v25.16b, v2.16b, #2
	bit v4.16b, v25.16b, v22.16b
	shl v25.16b, v3.16b, #3
	bit v4.16b, v25.16b, v23.16b

	and v5.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	bit v5.16b, v1.16b, v21.16b
	ushr v1.16b, v1.16b, #1
	shl v25.16b, v2.16b, #1
	bit v5.16b, v25.16b, v22.16b
	shl v25.16b, v3.16b, #2
	bit v5.16b, v25.16b, v23.16b

	and v6.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	bit v6.16b, v1.16b, v21.16b
	ushr v1.16b, v1.16b, #1
	bit v6.16b, v2.16b, v22.16b
	ushr v2.16b, v2.16b, #1
	shl v25.16b, v3.16b, #1
	bit v6.16b, v25.16b, v23.16b

	and v7.16b, v0.16b, v20.16b
	bit v7.16b, v1.16b, v21.16b
	bit v7.16b, v2.16b, v22.16b
	bit v7.16b, v3.16b, v23.16b

	// extra nibbles and add horizontally
	and v0.16b, v4.16b, v24.16b
	ushr v4.16b, v4.16b, #4
	uaddlv h0, v0.16b
	uaddlv h4, v4.16b

	and v1.16b, v5.16b, v24.16b
	ushr v5.16b, v5.16b, #4
	uaddlv h1, v1.16b
	uaddlv h5, v5.16b

	and v2.16b, v6.16b, v24.16b
	ushr v6.16b, v6.16b, #4
	uaddlv h2, v2.16b
	uaddlv h6, v6.16b

	and v3.16b, v7.16b, v24.16b
	ushr v7.16b, v7.16b, #4
	uaddlv h3, v3.16b
	uaddlv h7, v7.16b

	// add sums to counters
	ins v0.d[1], v1.d[0]
	ins v2.d[1], v3.d[0]
	ins v4.d[1], v5.d[0]
	ins v6.d[1], v7.d[0]

	add v16.2d, v16.2d, v0.2d
	add v17.2d, v17.2d, v2.2d
	add v18.2d, v18.2d, v4.2d
	add v19.2d, v19.2d, v6.2d

	subs x2, x2, #15*16
	bgt 0b

1:	cmp x2, #16			// enough data to process 16 bytes?
	blt 2f

	// single vector
0:	ld1 {v0.16b}, [x1], #16		// load 16 byte

	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h2, v1.16b
	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h1, v1.16b
	ins v2.d[1], v1.d[0]
	add v16.2d, v16.2d, v2.2d

	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h2, v1.16b
	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h1, v1.16b
	ins v2.d[1], v1.d[0]
	add v17.2d, v17.2d, v2.2d

	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h2, v1.16b
	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h1, v1.16b
	ins v2.d[1], v1.d[0]
	add v18.2d, v18.2d, v2.2d

	and v1.16b, v0.16b, v20.16b
	ushr v0.16b, v0.16b, #1
	uaddlv h2, v1.16b
	and v1.16b, v0.16b, v20.16b
	uaddlv h1, v1.16b
	ins v2.d[1], v1.d[0]
	add v19.2d, v19.2d, v2.2d

	subs x2, x2, #16
	bgt 0b

	// scalar tail
2:	cbz x2, 1f			// any bytes left to process?
	tst x2, #1			// unroll loop once (duff style)
	bne 2f

	// scalar loop: process one byte at a time
0:	ld1r {v2.8b}, [x1], #1		// load same byte to each elem of v2
	cmtst v2.8b, v29.8b, v2.8b	// set counter bytes to 0 or -1 according to [x0] bits
	sub v30.8b, v30.8b, v2.8b	// and increment counters

2:	ld1r {v2.8b}, [x1], #1		// load same byte to each elem of v2
	cmtst v2.8b, v29.8b, v2.8b	// set counter bytes to 0 or -1 according to [x0] bits
	sub v30.8b, v30.8b, v2.8b	// and increment counters

	subs x2, x2, #2
	bgt 0b

	// unpack temp vector and add to counters
	uxtl v30.8h, v30.8b
	uxtl v29.4s, v30.4h
	uxtl2 v30.4s, v30.8h		// v29:v30 holds 4 S counters

	uxtl v2.2d, v29.2s
	add v16.2d, v16.2d, v2.2d
	uxtl2 v2.2d, v29.4s
	add v17.2d, v17.2d, v2.2d

	uxtl v2.2d, v30.2s
	add v18.2d, v18.2d, v2.2d
	uxtl2 v2.2d, v30.4s
	add v19.2d, v19.2d, v2.2d

1:	st1 {v16.2D-v19.2D}, [x0]	// write counters back
	ret

	.balign 8
.Lmask:	.8byte 0x8040201008040201
