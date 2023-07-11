
// B:A = A+B+C, ZMM22 used as scratch space
	.macro csa a, b, c, d
	vmovdqa64 \a, %zmm22
	vpternlogd $0x96, \c, \b, \a
	vpternlogd $0xe8, \c, %zmm22, \b
	.endm

	.section .rodata
	.balign 64
.Lmagic:
	.quad		0x0706050403020100	# .Lmagic+ 0
	.quad		0x8040201008040201	# .Lmagic+ 8
	.int		0x55555555		# .Lmagic+16
	.int		0x33333333		# .Lmagic+20
	.int		0x0f0f0f0f		# .Lmagic+24
	.int		0x00ff00ff		# .Lmagic+28

# permutation vectors for the last permutation step of the vec loop
# permutes words
# A = 0000 1111 2222 3333 4444 5555 6666 7777
# B = 8888 9999 AAAA BBBB CCCC DDDD EEEE FFFF
# into the order used by the counters:
# Q1 = 0123 4567 0123 4567 0123 4567 0123 4567
# Q2 = 89AB CDEF 89AB CDEF 89AB CDEF 89AB CDEF
	.quad		0x1c1814100c080400	# .Lmagic+32
	.quad		0x1d1915110d090501
	.quad		0x1e1a16120e0a0602
	.quad		0x1d1b17130f0b0703

	.text

# Generic kernel.  This function expects a pointer to a width-specific
# accumulation function in RBX, a possibly unaligned input buffer in RSI,
# counters in RDI and an array length in RCX.
	.type		countavx512, @function
	.balign		16
countavx512:
	vmovq		.Lmagic(%rip), %xmm1	# 0706050403020100
	vpbroadcastq	.Lmagic+8(%rip), %zmm31	# 8040201008040201
	vpternlogd	$0xff, %zmm30, %zmm30, %zmm30	# ffffffff
	vpxord		%ymm25, %ymm25, %ymm25	# zero register

	// turn xmm15 into a set of qword masks in zmm29
	vpunpcklbw	%xmm1, %xmm1, %xmm1	# 7766:5544:3322:1100
	vpermq		$0x50, %ymm1, %ymm1	# 7766:5544:7766:5544:3322:1100:3322:1100
	vpunpcklwd	%ymm1, %ymm1, %ymm1	# 7777:6666:5555:4444:3333:2222:1111:0000
	vpmovzxdq	%ymm1, %zmm1		# -7:-6:-5:-4:-3:-2:-1:-0
	vpshufd		$0xa0, %zmm1, %zmm29	# 77:66:55:44:33:22:11:00

	cmp		$15*64, %rcx		# is the CSA kernel worth using?
	jb		.Lrunt

	# compute misalignment mask
	mov		%esi, %edx
	and		$63, %edx		# offset of buffer start from 64 byte alignment
	mov		$-1, %rax
	sub		%rdx, %rsi		# align the source to 64 byte
	add		%rdx, %rcx		# account for head length in RCX
	shlx		%rdx, %rax, %rax	# mask out the head of the load
	kmovq		%rax, %k1		# prepare mask register

	vmovdqu8	0*64(%rsi), %zmm0{%k1}{z} # load 960 bytes from buf
	vmovdqa64	1*64(%rsi), %zmm1	# and sum them into zmm3:zmm2:zmm1:zmm0
	vmovdqa64	2*64(%rsi), %zmm4
	vpxor		%ymm8, %ymm8, %ymm8	# initialise counters
	vpxor		%ymm9, %ymm9, %ymm9
	vmovdqa64	3*64(%rsi), %zmm2
	vmovdqa64	4*64(%rsi), %zmm3
	vmovdqa64	5*64(%rsi), %zmm5
	csa		%zmm0, %zmm1, %zmm4
	vmovdqa64	6*64(%rsi), %zmm6
	vmovdqa64	7*64(%rsi), %zmm7
	vmovdqa64	8*64(%rsi), %zmm10
	csa		%zmm2, %zmm3, %zmm5
	vmovdqa64	9*64(%rsi), %zmm11
	vmovdqa64	10*64(%rsi), %zmm12
	vmovdqa64	11*64(%rsi), %zmm13
	csa		%zmm6, %zmm7, %zmm10
	vmovdqa64	12*64(%rsi), %zmm4
	vmovdqa64	13*64(%rsi), %zmm5
	vmovdqa64	14*64(%rsi), %zmm10
	csa		%zmm1, %zmm12, %zmm13
	vpbroadcastd	.Lmagic+16(%rip), %zmm28 # 55555555 for transposition
	vpbroadcastd	.Lmagic+20(%rip), %zmm27 # 33333333 for transposition
	vpbroadcastd	.Lmagic+24(%rip), %zmm26 # 0f0f0f0f for transposition
	csa		%zmm4, %zmm5, %zmm10
	csa		%zmm0, %zmm2, %zmm6
	csa		%zmm1, %zmm3, %zmm7
	csa		%zmm0, %zmm1, %zmm4
	csa		%zmm2, %zmm12, %zmm5
	csa		%zmm1, %zmm2, %zmm11
	csa		%zmm2, %zmm3, %zmm12

	add		$15*64, %rsi
	sub		$(15+16)*64, %rcx	# enough data left to process?
	jb		.Lpost

	vpbroadcastd	.Lmagic+28(%rip), %zmm24 # 00ff00ff
	vpmovzxbw	.Lmagic+32(%rip), %zmm3	# transposition vector
	mov		$65535, %eax		# space left til overflow could occur in ZMM8, ZMM9

	# load 1024 bytes from buf, add them to ZMM0..ZMM3 into ZMM0..ZMM4
	.balign		16
.Lvec:	vmovdqa64	0*64(%rsi), %zmm4
	vmovdqa64	1*64(%rsi), %zmm5
	vmovdqa64	2*64(%rsi), %zmm6
	vmovdqa64	3*64(%rsi), %zmm7
	vmovdqa64	4*64(%rsi), %zmm10
	csa		%zmm0, %zmm4, %zmm5
	vmovdqa64	5*64(%rsi), %zmm5
	vmovdqa64	6*64(%rsi), %zmm11
	vmovdqa64	7*64(%rsi), %zmm12
	csa		%zmm6, %zmm7, %zmm10
	vmovdqa64	8*64(%rsi), %zmm10
	vmovdqa64	9*64(%rsi), %zmm13
	vmovdqa64	10*64(%rsi), %zmm14
	csa		%zmm5, %zmm1, %zmm12
	vmovdqa64	11*64(%rsi), %zmm12
	vmovdqa64	12*64(%rsi), %zmm15
	vmovdqa64	13*64(%rsi), %zmm16
	csa		%zmm10, %zmm13, %zmm14
	vmovdqa64	14*64(%rsi), %zmm14
	vmovdqa64	15*64(%rsi), %zmm17
	csa		%zmm12, %zmm15, %zmm16
	add		$16*64, %rsi
	csa		%zmm0, %zmm5, %zmm6
	csa		%zmm1, %zmm4, %zmm7
	csa		%zmm10, %zmm12, %zmm14
	csa		%zmm11, %zmm13, %zmm15
	csa		%zmm0, %zmm10, %zmm17
	csa		%zmm1, %zmm5, %zmm11
	csa		%zmm2, %zmm4, %zmm13
	csa		%zmm1, %zmm10, %zmm12
	csa		%zmm2, %zmm5, %zmm10
	csa		%zmm3, %zmm4, %zmm5

	# now ZMM0..ZMM4 hold counters; preserve ZMM0..ZMM3 for
	# for the next round and add ZMM4 to counters.
	vpandd		%zmm4, %zmm28, %zmm5	# ZMM5 = bits 02468ace x32
	vpandnd		%zmm4, %zmm28, %zmm6	# ZMM6 = bits 13579bdf x32
	vpsrld		$1, %zmm6, %zmm6
	vshufi64x2	$0x44, %zmm6, %zmm5, %zmm10
	vshufi64x2	$0xee, %zmm6, %zmm5, %zmm11
	vpaddd		%zmm10, %zmm11, %zmm4	# ZMM4 = 02468ace x16 ... 13579bdf x16

	# split again and reduce into nibbles
	vpandd		%zmm4, %zmm27, %zmm5	# ZMM5 = 048c x16 ... 159d x16
	vpandnd		%zmm4, %zmm27, %zmm6	# ZMM6 = 26ae x16 ... 37bf x16
	vpsrld		$2, %zmm6, %zmm6
	vshufi64x2	$0x88, %zmm6, %zmm5, %zmm10
	vshufi64x2	$0xdd, %zmm6, %zmm5, %zmm11
	vpaddd		%zmm10, %Zmm11, %zmm4	# ZMM4 = 048c x8  159d x8  26ae x8  37bf x8

	# split again and reduce into bytes (shifted left by 4)
	vpandd		%zmm4, %zmm26, %zmm5	# ZMM5 = 08 x8  19 x8  2a x8  3b x8
	vpandnd		%zmm4, %zmm26, %zmm6	# ZMM6 = 4c x8  5d x8  6e x8  7f x8
	vpslld		$4, %zmm5, %zmm5
	vpermq		$0xd8, %zmm5, %zmm5	# ZMM5 = 08x4 19x4 08x4 19x4  2ax4 3bx4 2ax4 3bx4
	vpermq		$0xd8, %zmm6, %zmm6	# ZMM6 = 4cx4 5dx4 4cx4 5dx4  6ex4 7fx4 6ex4 7fx4
	vshufi64x2	$0x88, %zmm6, %zmm5, %zmm10
	vshufi64x2	$0xdd, %zmm6, %zmm5, %zmm11
	vpaddd		%zmm10, %zmm11, %zmm4	# ZMM4 = 08x4 19x4 2ax4 3bx4 4cx4 5dx4 6ex4 7fx4

	# split again into 16 bit counters
	vpsrlw		$8, %zmm4, %zmm6	# ZMM6 = 8888 9999 aaaa bbbb cccc dddd eeee ffff
	vpandd		%zmm4, %zmm24, %zmm5	# ZMM5 = 0000 1111 2222 3333 4444 5555 6666 7777

	# accumulate in permuted order
	vpaddw		%zmm5, %zmm8, %zmm8
	vpaddw		%zmm6, %zmm9, %zmm9

	sub		$16*8, %eax		# account for possible overflow
	cmp		$(15+15+16)*8, %eax	# enough space left in the counters?
	jge		.Lhave_space

	# fix permutation and flush into counters
	vpermw		%zmm8, %zmm23, %zmm9	# ZMM5 = 0123 4567 0123 4567 0123 4567 0123 4567
	vpermw		%zmm9, %zmm23, %zmm9	# ZMM6 = 89ab cdef 89ab cdef 89ab cdef 89ab cdef
	call		*%rbx			# call accumulation function
	vpxor		%ymm8, %ymm8, %ymm8
	vpxor		%ymm9, %ymm9, %ymm9	# clear accumulators for next round
	mov		$65535, %eax		# space left til overflow could occur

.Lhave_space:
	sub		$16*64, %rcx		# account for bytes consumed
	jae		.Lvec

	# fix permutations for final step
	vpermw		%zmm8, %zmm23, %zmm8	# ZMM5 = 0123 4567 0123 4567 0123 4567 0123 4567
	vpermw		%zmm9, %zmm23, %zmm9	# ZMM6 = 89ab cdef 89ab cdef 89ab cdef 89ab cdef

	# sub up ZMM0..ZMM3 into the counter registers
.Lpost:	vpsrld		$1, %zmm0, %zmm4	# group nibbled in ZMM0..ZMM3 into ZMM4..ZMM7
	vpaddd		%zmm1, %zmm1, %zmm5
	vpsrld		$1, %zmm2, %zmm6
	vpaddd		%zmm3, %zmm3, %zmm7
	vpternlogd	$0xe4, %zmm28, %zmm5, %zmm0 # ZMM0 = eca86420 (low crumbs)
	vpternlogd	$0xd8, %zmm28, %zmm4, %zmm1 # ZMM1 = fdb97531 (low crumbs)
	vpternlogd	$0xe4, %zmm28, %zmm7, %Zmm2 # ZMM2 = eca86420 (high crumbs)
	vpternlogd	$0xd8, %zmm28, %zmm6, %zmm3 # ZMM3 = fdb97531 (high crumbs)

	vpsrld		$2, %zmm0, %zmm4
	vpsrld		$2, %zmm1, %zmm6
	vpslld		$2, %zmm2, %zmm5
	vpslld		$2, %zmm3, %zmm7
	vpternlogd	$0xd8, %zmm27, %zmm4, %zmm2 # ZMM2 = ea63
	vpternlogd	$0xd8, %zmm27, %zmm6, %zmm3 # ZMM3 = fb73
	vpternlogd	$0xe4, %zmm27, %zmm5, %zmm0 # ZMM0 = c840
	vpternlogd	$0xe4, %zmm27, %zmm7, %zmm1 # ZMM1 = d951

	# pre-shuffle nibbles within 128 bit lanes
	vpunpcklbw	%zmm3, %zmm2, %zmm6	# ZMM6 = fbea7362 (3:2:1:0)
	vpunpckhbw	%zmm3, %zmm2, %zmm3	# ZMM3 = fbea7362 (7:6:4:4)
	vpunpcklbw	%zmm1, %zmm0, %zmm5	# ZMM5 = d9c85140 (3:2:1:0)
	vpunpckhbw	%zmm1, %zmm0, %zmm2	# ZMM2 = d9c85140 (7:6:5:4)
	vpunpcklwd	%zmm6, %zmm5, %zmm4	# ZMM4 = fbead9c873625140 (1:0)
	vpunpckhwd	%zmm6, %zmm5, %zmm5	# ZMM5 = fbead9c873625140 (3:2)
	vpunpcklwd	%zmm3, %zmm2, %zmm6	# ZMM6 = fbead9c873625140 (5:4)
	vpunpckhwd	%zmm3, %zmm2, %zmm7	# ZMM7 = fbead9c873625140 (7:6)

	# pull out high and low nibbles
	vpandd		%zmm26, %zmm4, %zmm0
	vpsrld		$4, %zmm4, %zmm4
	vpandd		%zmm26, %zmm4, %zmm4

	vpandd		%zmm26, %zmm5, %zmm1
	vpsrld		$4, %zmm5, %zmm5
	vpandd		%zmm26, %zmm5, %zmm5

	vpandd		%zmm26, %zmm6, %zmm2
	vpsrld		$4, %zmm6, %zmm6
	vpandd		%zmm26, %zmm6, %zmm6

	vpandd		%zmm26, %zmm7, %zmm3
	vpsrld		$4, %zmm7, %zmm7
	vpandd		%zmm26, %zmm7, %zmm7

	# reduce once
	vpaddb		%zmm2, %zmm0, %zmm0	# ZMM0 = ba983210 (1:0)
	vpaddb		%zmm3, %zmm1, %zmm1	# ZMM1 = ba983210 (3:2)
	vpaddb		%zmm6, %zmm4, %zmm2	# ZMM2 = fedc7654 (1:0)
	vpaddb		%zmm7, %zmm5, %zmm3	# ZMM3 = fedc7654 (3:2)

	# shuffle again to form ordered groups of 16 counters in each lane
	vpunpckldq	%zmm2, %zmm0, %zmm4	# ZMM4 = fedcba9876543210 (0)
	vpunpckhdq	%zmm2, %zmm0, %zmm5	# ZMM5 = fedcba9876543210 (1)
	vpunpckldq	%zmm3, %zmm1, %zmm6	# ZMM6 = fedcba9876543210 (2)
	vpunpckhdq	%zmm3, %zmm1, %zmm7	# ZMM7 = fedcba9876543210 (3)

	# reduce lanes once (4x1 lane -> 2x2 lanes)
	vshufi64x2	$0x44, %zmm5, %zmm4, %zmm0 # ZMM0 = fedcba9876543210 (1:1:0:0)
	vshufi64x2	$0xee, %zmm5, %zmm4, %zmm1 # ZMM1 = fedcba9876543210 (1:1:0:0)
	vshufi64x2	$0x44, %zmm7, %zmm6, %zmm2 # ZMM2 = fedcba9876543210 (3:3:2:2)
	vshufi64x2	$0xee, %zmm7, %zmm6, %zmm3 # ZMM3 = fedcba9876543210 (3:3:2:2)
	vpaddb		%zmm1, %zmm0, %zmm0
	vpaddb		%zmm3, %zmm2, %zmm2

	# reduce lanes again (2x2 lanes -> 1x4 lanes)
	vshufi64x2	$0x88, %zmm2, %zmm0, %zmm1 # ZMM1 = fedcba9876543210 (3:2:1:0)
	vshufi64x2	$0xdd, %zmm2, %zmm0, %zmm0 # ZMM0 = fedcba9876543210 (3:2:1:0)
	vpaddb		%zmm1, %zmm0, %zmm0

	# zero extend and add to z8, z9
	vpunpcklbw	%zmm25, %zmm0, %zmm1	# Z1 = 76543210 (3:2:1:0)
	vpunpckhbw	%zmm25, %zmm0, %zmm2	# Z2 = fedcba98 (3:2:1:0)
	vpaddw		%zmm1, %zmm8, %zmm9
	vpaddw		%zmm2, %zmm9, %zmm9

.Lendvec:
	vpxor		%ymm0, %ymm0, %ymm0	# counter register

	# process tail, 8 bytes at a time
	sub		$8-16*64, %ecx		# 8 bytes left to process?
	jb		.Ltail1

.Ltail8:
	vpbroadcastq	(%rsi), %zmm4
	add		$8, %rsi
	vpshufb		%zmm29, %zmm4, %zmm4
	sub		$8, %ecx
	vptestmb	%zmm31, %zmm4, %k1
	vpsubb		%zmm30, %zmm0, %zmm0{%k1}
	jae		.Ltail8

	# process remaining 0--7 bytes
.Ltail1:
	sub		$-8, %ecx
	jle		.Lend			# anything left to process?

	vpbroadcastq	(%rsi), %zmm4
	vpshufb		%zmm29, %zmm4, %zmm4
	xor		%eax, %eax
	bts		%ecx, %eax		# 1 << CX
	dec		%eax			# bit mask of CX ones
	kmovb		%eax, %k1
	vmovdqa64	%zmm4, %zmm4{%k1}{z}	# mask out bytes that are not in the tail
	vptestmb	%zmm31, %zmm4, %k1
	vpsubb		%zmm30, %zmm0, %zmm0{%k1}

	# add tail to counters
.Lend:	vpunpcklbw	%zmm25, %zmm0, %zmm1
	vpunpckhbw	%zmm25, %zmm0, %zmm2
	vpaddw		%zmm1, %zmm8, %zmm8
	vpaddw		%zmm2, %zmm9, %zmm9

	# and perform a final accoumulation
	call		*%rbx
	vzeroupper
	ret

	# special processing for when the data is less than
	# one iteration of the kernel
.Lrunt:	vpxor		%ymm0, %ymm0, %ymm0	# counter register
	sub		$8, %ecx
	jb		.Lrunt1


.Lrunt8:
	vpbroadcastq	(%rsi), %zmm4
	add		$8, %rsi
	vpshufb		%zmm29, %zmm4, %zmm4
	sub		$8, %ecx
	vptestmb	%zmm31, %zmm4, %k1
	vpsubb		%zmm30, %zmm0, %zmm0{%k1}
	jge		.Lrunt8

	# process remaining 0--8 bytes
.Lrunt1:
	add		$8, %ecx
	xor		%eax, %eax
	bts		%ecx, %eax		# 1 << CX
	dec		%eax			# mask of CX ones
	kmovd		%eax, %k1
	vmovdqu8	(%rsi), %xmm4{%k1}{z}
	vpbroadcastq	%xmm4, %zmm4
	vpshufb		%zmm29, %zmm4, %zmm4
	vptestmb	%zmm31, %zmm4, %k1
	vpsubb		%zmm30, %zmm0, %zmm0{%k1}

	# populate counters and accumulate
.Lrunt0:
	vpunpcklbw	%zmm25, %zmm0, %zmm8
	vpunpckhbw	%zmm25, %zmm0, %Zmm9
	call		*%rbx
	vzeroupper
	ret
	.size		countavx512, .-countavx512

	.type		accum8, @function
	.balign		16
accum8:	# unpack and zero-extend
	vpmovzxwq	%xmm8, %zmm10
	vextracti128	$1, %ymm8, %xmm11
	vpmovzxwq	%xmm11, %zmm11
	vextracti64x2	$2, %zmm8, %xmm12
	vpmovzxwq	%xmm12, %zmm12
	vextracti64x2	$3, %zmm8, %xmm13
	vpmovzxwq	%xmm13, %zmm13
	vpmovzxwq	%xmm9, %zmm14
	vextracti128	$1, %ymm9, %xmm15
	vpmovzxwq	%xmm15, %zmm15
	vextracti64x2	$2, %zmm9, %xmm16
	vpmovzxwq	%xmm16, %zmm16
	vextracti64x2	$3, %zmm9, %xmm17
	vpmovzxwq	%xmm17, %zmm17

	# fold over thrice
	vpaddq		%zmm12, %zmm10, %zmm10
	vpaddq		%zmm13, %zmm11, %zmm11
	vpaddq		%zmm16, %zmm14, %zmm14
	vpaddq		%zmm17, %zmm15, %zmm15
	vpaddq		%zmm11, %zmm10, %zmm10
	vpaddq		%zmm15, %zmm14, %zmm14
	vpaddq		%zmm14, %zmm10, %zmm10

	# add to counters
	vpaddq		(%rdi), %zmm10, %zmm10
	vmovdqu64	%zmm10, (%rdi)

	ret
	.size		accum8, .-accum8

	.type		accum16, @function
	.balign		16
accum16:
	# unpack and zero-extend
	vpmovzxwq	%xmm8, %zmm10
	vextracti128	$1, %ymm8, %xmm11
	vpmovzxwq	%xmm11, %zmm11
	vextracti64x2	$2, %zmm8, %xmm12
	vpmovzxwq	%xmm12, %zmm12
	vextracti64x2	$3, %zmm8, %xmm13
	vpmovzxwq	%xmm13, %zmm13
	vpmovzxwq	%xmm9, %zmm14
	vextracti128	$1, %ymm9, %xmm15
	vpmovzxwq	%xmm15, %zmm15
	vextracti64x2	$2, %zmm9, %xmm16
	vpmovzxwq	%xmm16, %zmm16
	vextracti64x2	$3, %zmm9, %xmm17
	vpmovzxwq	%xmm17, %zmm17

	# fold over thrice
	vpaddq		%zmm12, %zmm10, %zmm10
	vpaddq		%zmm13, %zmm11, %zmm11
	vpaddq		%zmm16, %zmm14, %zmm14
	vpaddq		%zmm17, %zmm15, %zmm15
	vpaddq		%zmm11, %zmm10, %zmm10
	vpaddq		%zmm15, %zmm14, %zmm14

	# add to counters
	vpaddq		(%rdi), %zmm10, %zmm10
	vpaddq		64(%rdi), %zmm14, %zmm14
	vmovdqu64	%zmm10, (%rdi)
	vmovdqu64	%zmm14, 64(%rdi)

	ret
	.size		accum16, .-accum16

	.type		accum32, @function
	.balign		16
accum32:
	# fold high half over low half and reduce
	vextracti64x2	$2, %zmm8, %xmm12
	vextracti64x2	$2, %zmm9, %xmm13
	vpmovzxwq	%xmm8, %zmm10
	vpmovzxwq	%xmm9, %zmm11
	vpmovzxwq	%xmm12, %zmm12
	vpmovzxwq	%xmm13, %zmm13
	vpaddq		0*64(%rdi), %zmm10, %zmm10
	vpaddq		1*64(%rdi), %zmm11, %zmm11
	vmovdqu64	%zmm10, 0*64(%rdi)
	vmovdqu64	%zmm11, 1*64(%rdi)

	vextracti128	$1, %ymm8, %xmm10
	vextracti128	$1, %ymm9, %xmm11
	vextracti64x2	$3, %zmm8, %xmm12
	vextracti64x2	$3, %zmm9, %xmm13
	vpmovzxwq	%xmm10, %zmm10
	vpmovzxwq	%xmm11, %zmm11
	vpmovzxwq	%xmm12, %zmm12
	vpmovzxwq	%xmm13, %zmm13
	vpaddq		2*64(%rdi), %zmm10, %zmm10
	vpaddq		3*64(%rdi), %zmm11, %zmm11
	vmovdqu64	%zmm10, 2*64(%rdi)
	vmovdqu64	%zmm11, 3*64(%rdi)

	ret
	.size		accum32, .-accum32

	.type		accum64, @function
	.balign		16
accum64:
	vpmovzxwq	%xmm8, %zmm13
	vpmovzxwq	%xmm9, %zmm14
	vpaddq		0*64(%rdi), %zmm13, %zmm13
	vpaddq		1*64(%rdi), %zmm14, %zmm14
	vmovdqu64	%zmm13, 0*64(%rdi)
	vmovdqu64	%zmm14, 1*64(%rdi)

	vextracti128	$1, %ymm8, %xmm13
	vextracti128	$1, %ymm9, %xmm14
	vpmovzxwq	%xmm13, %zmm13
	vpmovzxwq	%xmm14, %zmm14
	vpaddq		2*64(%rdi), %zmm13, %zmm13
	vpaddq		3*64(%rdi), %zmm14, %zmm14
	vmovdqu64	%zmm13, 2*64(%rdi)
	vmovdqu64	%zmm14, 3*64(%rdi)

	vextracti64x2	$2, %zmm8, %xmm13
	vextracti64x2	$2, %zmm9, %xmm14
	vpmovzxwq	%xmm13, %zmm13
	vpmovzxwq	%xmm14, %zmm14
	vpaddq		4*64(%rdi), %zmm13, %zmm13
	vpaddq		5*64(%rdi), %zmm14, %zmm14
	vmovdqu64	%zmm13, 4*64(%rdi)
	vmovdqu64	%zmm14, 5*64(%rdi)

	vextracti64x2	$3, %zmm8, %xmm13
	vextracti64x2	$3, %zmm9, %xmm14
	vpmovzxwq	%xmm13, %zmm13
	vpmovzxwq	%xmm14, %zmm14
	vpaddq		6*64(%rdi), %zmm13, %zmm13
	vpaddq		7*64(%rdi), %zmm14, %zmm14
	vmovdqu64	%zmm13, 6*64(%rdi)
	vmovdqu64	%zmm14, 7*64(%rdi)

	ret
	.size		accum64, .-accum64

	.globl		count8avx512, count16avx512, count32avx512, count64avx512

	.type		count8avx512, @function
	.balign		16
count8avx512:
	push		%rbx
	lea		accum8(%rip), %rbx
	mov		%rdx, %rcx
	call		countavx512
	pop		%rbx
	ret
	.size		count8avx512, .-count8avx512

	.type		count16avx512, @function
	.balign		16
count16avx512:
	push		%rbx
	lea		accum16(%rip), %rbx
	lea		(%rdx, %rdx, 1), %rcx
	call		countavx512
	ret
	.size		count16avx512, .-count16avx512

	.type		count32avx512, @function
	.balign		16
count32avx512:
	push		%rbx
	lea		accum32(%rip), %rbx
	mov		%rdx, %rcx
	shl		$2, %rcx
	call		countavx512
	pop		%rbx
	ret
	.size		count32avx512, .-count32avx512

	.type		count64avx512, @function
	.balign		16
count64avx512:
	push		%rbx
	lea		accum64(%rip), %rbx
	mov		%rdx, %rcx
	shl		$3, %rcx
	call		countavx512
	pop		%rbx
	ret
	.size		count64avx512, .-count64avx512

	.section .note.GNU-stack,"",%progbits
