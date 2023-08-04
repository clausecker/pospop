	.section	.rodata

	# sliding window for head/tail loads.  Unfortunately
	# there doesn't seem to be a good way to do this
	# with less memory wasted.
	.balign		64
.Lwindow:
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff

	# magic transposition constants, comparison constants
.Lmagic:
	.quad		0x0000000000000000	# .Lmagic+0
	.quad		0x0101010101010101
	.quad		0x0202020202020202
	.quad		0x0303030303030303
	.quad		0x8040201008040201	# .Lmagic+32
	.int		0x55555555		# .Lmagic+40
	.int		0x33333333		# .Lmagic+44
	.int		0x0f0f0f0f		# .Lmagic+48
	.int		0x00ff00ff		# .Lmagic+52

	.text

	# B:A = A+B+C, YMM7 used for scratch space
	.macro		csa a, b, c
	vpand		\a, \b, %ymm7
	vpxor		\a, \b, \a
	vpand		\a, \c, \b
	vpxor		\a, \c, \a
	vpor		\b, %ymm7, \b
	.endm

	# count 4 bytes from L and 4 bytes from H into YMM0 and YMM1
	# using YMM4 and YMM5 for scratch space
	.macro		count8 l, h
	vpbroadcastd	l, %ymm4		# YMM4 = 3210:3210:3210:3210:3210:3210:3210:3210
	vpbroadcastd	h, %ymm5
	vpshufb		%ymm3, %ymm4, %ymm4	# YMM4 = 3333:3333:2222:2222:1111:1111:0000:0000
	vpshufb		%ymm3, %ymm5, %ymm5
	vpand		%ymm2, %ymm4, %ymm4	# mask out one bit in each copy of the bytes
	vpand		%ymm2, %ymm5, %ymm5
	vpcmpeqb	%ymm2, %ymm4, %ymm4	# set bytes to -1 if the bits were set
	vpcmpeqb	%ymm2, %ymm5, %ymm5	# or to 0 otherwise
	vpsubb		%ymm4, %ymm0, %ymm0	# add 1/0 (subtract -1/0) to counters
	vpsubb		%ymm5, %ymm1, %ymm1
	.endm

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in RBX, a possibly unaligned input buffer in RSI,
// counters in DI and a remaining length in RCX.
	.type		countavx2, @function
	.balign		16
countavx2:
	# contants for processing the head and tail
	vpbroadcastq	.Lmagic+32(%rip), %ymm2	# bit position mask
	vmovdqa		.Lmagic(%rip), %ymm3	# permutation mask
	vpxor		%ymm7, %ymm7, %ymm7	# zero register

	cmp		$15*32, %rcx		# is the CSA kernel worth using?
	jb		.Lrunt

	# load head until alignment/end reached
	mov		%esi, %edx
	and		$31, %edx		# offset of buffer start from 32 byte alignment
	mov		$32, %eax
	sub		%edx, %eax		# number of bytes til alignment is reached (head length)
	sub		%rdx, %rsi		# align source to 32 bytes
	vmovdqa		(%rsi), %ymm0		# load head
	add		%rdx, %rcx		# and account for head length
	lea		.Lwindow(%rip), %rdx	# load window mask base pointer
	vpand		(%rdx, %rax, 1), %ymm0, %ymm0 # mask out bytes not in head

	# load 480 (-32) bytes from buf and sum them into YMM3..YMM0
	vmovdqa		1*32(%rsi), %ymm1
	vmovdqa		2*32(%rsi), %ymm4
	vmovdqa		3*32(%rsi), %ymm2
	vmovdqa		4*32(%rsi), %ymm3
	vmovdqa		5*32(%rsi), %ymm5
	vmovdqa		6*32(%rsi), %ymm6
	csa		%ymm0, %ymm1, %ymm4
	vmovdqa		7*32(%rsi), %ymm4
	csa		%ymm3, %ymm2, %ymm5
	vmovdqa		8*32(%rsi), %ymm5
	csa		%ymm0, %ymm3, %ymm6
	vmovdqa		9*32(%rsi), %ymm6
	csa		%ymm1, %ymm2, %ymm3
	vmovdqa		10*32(%rsi), %ymm3
	csa		%ymm0, %ymm4, %ymm5
	vmovdqa		11*32(%rsi), %ymm5
	csa		%ymm0, %ymm3, %ymm6
	vmovdqa		12*32(%rsi), %ymm6
	csa		%ymm1, %ymm3, %ymm4
	vmovdqa		13*32(%rsi), %ymm4
	csa		%ymm0, %ymm5, %ymm6
	vmovdqa		14*32(%rsi), %ymm6
	vpbroadcastd	.Lmagic+40(%rip), %ymm15 # 0x55555555
	vpbroadcastd	.Lmagic+44(%rip), %ymm13 # 0x33333333
	csa		%ymm0, %ymm4, %ymm6
	vpxor		%ymm8, %ymm8, %ymm8	# initialise counters
	vpxor		%ymm9, %ymm9, %ymm9
	csa		%ymm1, %ymm4, %ymm5
	vpxor		%ymm10, %ymm10, %ymm10
	vpxor		%ymm11, %ymm11, %ymm11
	csa		%ymm2, %ymm3, %ymm4

	add		$15*32, %rsi
	sub		$(15+16)*32, %rcx	# enough data left to process
	jb		.Lpost

	mov		$65535, %eax		# space left til overflow in YMM8..YMM11

	# load 512 bytes from buf and
	# add them to YMM0..YMM3 into YMM0..YMM4
	.balign		16
.Lvec:	vmovdqa		0*32(%rsi), %ymm4
	vmovdqa		1*32(%rsi), %ymm5
	vmovdqa		2*32(%rsi), %ymm6
	vmovdqa		3*32(%rsi), %ymm12
	vmovdqa		4*32(%rsi), %ymm14
	csa		%ymm0, %ymm4, %ymm5
	vmovdqa		5*32(%rsi), %ymm5
	csa		%ymm6, %ymm12, %ymm14
	vmovdqa		6*32(%rsi), %ymm14
	csa		%ymm1, %ymm4, %ymm12
	vmovdqa		7*32(%rsi), %ymm12
	csa		%ymm0, %ymm5, %ymm6
	vmovdqa		8*32(%rsi), %ymm6
	csa		%ymm6, %ymm12, %ymm14
	vmovdqa		9*32(%rsi), %ymm14
	csa		%ymm1, %ymm5, %ymm12
	vmovdqa		10*32(%rsi), %ymm12
	csa		%ymm0, %ymm12, %ymm14
	vmovdqa		11*32(%rsi), %ymm14
	csa		%ymm2, %ymm4, %ymm5
	vmovdqa		12*32(%rsi), %ymm5
	csa		%ymm0, %ymm6, %ymm14
	vmovdqa		13*32(%rsi), %ymm14
	csa		%ymm1, %ymm6, %ymm12
	vmovdqa		14*32(%rsi), %ymm12
	csa		%ymm5, %ymm12, %ymm14
	vmovdqa		15*32(%rsi), %ymm14
	csa		%ymm0, %ymm5, %ymm14
	add		$16*32, %rsi
	csa		%ymm1, %ymm5, %ymm12
	csa		%ymm2, %ymm5, %ymm6
	csa		%ymm3, %ymm4, %ymm5

	vpbroadcastd	.Lmagic+52(%rip), %ymm12 # 0x00ff00ff
	vpbroadcastd	.Lmagic+48(%rip), %ymm14 # 0x0f0f0f0f

	# now YMM0..YMM4 hold place values 1, 2, 4, 8, and 16.
	# Preserve YMM0..YMM3 for the next round and add YMM4
	# to the counters.

	# split into even/odd and reduce into crumbs
	vpand		%ymm4, %ymm15, %ymm5	# YMM5 = 02468ace x16
	vpandn		%ymm4, %ymm15, %ymm6	# YMM6 = 13579bdf x16
	vpsrld		$1, %ymm6, %ymm6
	vperm2i128	$0x20, %ymm6, %ymm5, %ymm4
	vperm2i128	$0x31, %ymm6, %ymm5, %ymm5
	vpaddd		%ymm5, %ymm4, %ymm4	# YMM4 = 02468ace x8 13579bdf x8

	# split again and reduce into nibbles
	vpand		%ymm4, %ymm13, %ymm5	# YMM5 = 048c x8 159d x8
	vpandn		%ymm4, %ymm13, %ymm6	# YMM6 = 26ae x8 37bf x8
	vpsrld		$2, %ymm6, %ymm6
	vpunpcklqdq	%ymm6, %ymm5, %ymm4
	vpunpckhqdq	%ymm6, %ymm5, %ymm5
	vpaddd		%ymm5, %ymm4, %ymm4	# YMM4 = 048c x4 26ae x4 159d x4 37bf x4

	# split again into bytes and shuffle into order
	vpand		%ymm4, %ymm14, %ymm5	# YMM5 = 08 x4 2a x4 19 x4 3b x4
	vpandn		%ymm4, %ymm14, %ymm6	# YMM6 = 19 x4 3b x4 5d x4 7f x4
	vpslld		$4, %ymm5, %ymm5
	vperm2i128	$0x20, %ymm6, %ymm5, %ymm4 # YMM4 = 08 x4 2a x4 4c x4 6e x4
	vperm2i128	$0x31, %ymm6, %ymm5, %ymm5 # YMM5 = 19 x4 3b x4 5d x4 7f x4
	vpunpcklwd	%ymm5, %ymm4, %ymm6	# YMM6 = 0819 x4 4c5d x4
	vpunpckhwd	%ymm5, %ymm4, %ymm7	# YMM7 = 2a3b x4 6e7f x4
	vpunpckldq	%ymm7, %ymm6, %ymm4	# YMM4 = 08192a3b[0:1] 4c5d6e7f[0:1]
	vpunpckhdq	%ymm7, %ymm6, %ymm5	# YMM5 = 08192a3b[2:3] 4c5d6e7f[2:3]
	vpermq		$0xd8, %ymm4, %ymm4	# YMM4 = 08192a3b4c5d6e7f[0:1]
	vpermq		$0xd8, %ymm5, %ymm5	# YMM5 = 08192a3b4c5d6e7f[2:3]

	# split again into words and add to counters
	vpand		%ymm4, %ymm12, %ymm6	# YMM6 = 01234567[0:1]
	vpand		%ymm5, %ymm12, %ymm7	# YMM7 = 01234567[2:3]
	vpaddw		%ymm6, %ymm8, %ymm8
	vpaddw		%ymm7, %ymm10, %ymm10
	vpsrlw		$8, %ymm4, %ymm4	# YMM4 = 89abcdef[0:1]
	vpsrlw		$8, %ymm5, %ymm5	# YMM5 = 89abcdef[2:3]
	vpaddw		%ymm4, %ymm9, %ymm9
	vpaddw		%ymm5, %ymm11, %ymm11

	sub		$16*4, %eax		# account for possible overflow
	cmp		$(15+15+16)*4, %eax	# enough space left int he counters?
	jge		.Lhave_space

	# flush accumulators into counters
	vpxor		%ymm7, %ymm7, %ymm7
	call		*%rbx			# call accumulation function
	vpxor		%ymm8, %ymm8, %ymm8	# clear accumulators for next round
	vpxor		%ymm9, %ymm9, %ymm9
	vpxor		%ymm10, %ymm10, %ymm10
	vpxor		%ymm11, %ymm11, %ymm11

	mov		$65535, %eax

.Lhave_space:
	sub		$16*32, %rcx		# account for bytes consumed
	jae		.Lvec

	# group nibbles in YMM0..YMM4 into YMM4..YMM7
.Lpost:	vpbroadcastd	.Lmagic+48(%rip), %ymm14 # 0x0f0f0f0f

	vpand		%ymm1, %ymm15, %ymm5
	vpaddd		%ymm5, %ymm5, %ymm5
	vpand		%ymm3, %ymm15, %ymm7
	vpaddd		%ymm7, %ymm7, %ymm7
	vpand		%ymm0, %ymm15, %ymm4
	vpand		%ymm2, %ymm15, %ymm6
	vpor		%ymm4, %ymm5, %ymm4	# YMM4 = eca86420 (low crumbs)
	vpor		%ymm6, %ymm7, %ymm5	# YMM5 = eca86420 (high crumbs)

	vpandn		%ymm0, %ymm15, %ymm0
	vpsrld		$1, %ymm0, %ymm0
	vpandn		%ymm2, %ymm15, %ymm2
	vpsrld		$1, %ymm2, %ymm2
	vpandn		%ymm1, %ymm15, %ymm1
	vpandn		%ymm3, %ymm15, %ymm3
	vpor		%ymm0, %ymm1, %ymm6	# YMM6 = fdb97531 (low crumbs)
	vpor		%ymm2, %ymm3, %ymm7	# YMM8 = fdb97531 (high crumbs)

	vpand		%ymm5, %ymm13, %ymm1
	vpslld		$2, %ymm1, %ymm1
	vpand		%ymm7, %ymm13, %ymm3
	vpslld		$2, %ymm3, %ymm3
	vpand		%ymm4, %ymm13, %ymm0
	vpand		%ymm6, %ymm13, %ymm2
	vpor		%ymm0, %ymm1, %ymm0	# YMM0 = c840
	vpor		%ymm2, %ymm3, %ymm1	# YMM1 = d951

	vpandn		%ymm4, %ymm13, %ymm4
	vpsrld		$2, %ymm4, %ymm4
	vpandn		%ymm6, %ymm13, %ymm6
	vpsrld		$2, %ymm6, %ymm6
	vpandn		%ymm5, %ymm13, %ymm5
	vpandn		%ymm7, %ymm13, %ymm7
	vpor		%ymm4, %ymm5, %ymm2	# YMM2 = ea63
	vpor		%ymm6, %ymm7, %ymm3	# YMM3 = fb73

	# pre-shuffle nibbles
	vpunpcklbw	%ymm1, %ymm0, %ymm5	# YMM5 = d9c85140         (3:2:1:0)
	vpunpckhbw	%ymm1, %ymm0, %ymm0	# YMM0 = d9c85140         (7:6:5:4)
	vpunpcklbw	%ymm3, %ymm2, %ymm6	# YMM6 = fbea7362         (3:2:1:0)
	vpunpckhbw	%ymm3, %ymm2, %ymm1	# YMM1 = fbea7362         (7:6:5:4)
	vpunpcklwd	%ymm6, %ymm5, %ymm4	# YMM4 = fbead9c873625140 (1:0)
	vpunpckhwd	%ymm6, %ymm5, %ymm5	# YMM5 = fbead9c873625140 (3:2)
	vpunpcklwd	%ymm1, %ymm0, %ymm6	# YMM6 = fbead9c873625140 (5:4)
	vpunpckhwd	%ymm1, %ymm0, %ymm7	# YMM7 = fbead9c873625140 (7:6)

	# pull out high and low nibbles
	vpand		%ymm4, %ymm14, %ymm0
	vpsrld		$4, %ymm4, %ymm4
	vpand		%ymm4, %ymm14, %ymm4
	vpand		%ymm5, %ymm14, %ymm1
	vpsrld		$4, %ymm5, %ymm5
	vpand		%ymm5, %ymm14, %ymm5
	vpand		%ymm6, %ymm14, %ymm2
	vpsrld		$4, %ymm6, %ymm6
	vpand		%ymm6, %ymm14, %ymm6
	vpand		%ymm7, %ymm14, %ymm3
	vpsrld		$4, %ymm7, %ymm7
	vpand		%ymm7, %ymm14, %ymm7

	# reduce common values
	vpaddb		%ymm2, %ymm0, %ymm0	# YMM0 = ba98:3210:ba98:3210 (1:0)
	vpaddb		%ymm3, %ymm1, %ymm1	# YMM1 = ba98:3210:ba98:3210 (3:2)
	vpaddb		%ymm6, %ymm4, %ymm2	# YMM2 = fedc:7654:fedc:7654 (1:0)
	vpaddb		%ymm7, %ymm5, %ymm3	# YMM3 = fedc:7654:fedc:7654 (3:2)

	# shuffle dwords and group them
	vpunpckldq	%ymm2, %ymm0, %ymm4
	vpunpckhdq	%ymm2, %ymm0, %ymm5
	vpunpckldq	%ymm3, %ymm1, %ymm6
	vpunpckhdq	%ymm3, %ymm1, %ymm7
	vperm2i128	$0x20, %ymm5, %ymm4, %ymm0
	vperm2i128	$0x31, %ymm5, %ymm4, %ymm2
	vperm2i128	$0x20, %ymm7, %ymm6, %ymm1
	vperm2i128	$0x31, %ymm7, %ymm6, %ymm3
	vpaddb		%ymm2, %ymm0, %ymm0	# YMM0 = fedc:ba98:7654:3210 (1:0)
	vpaddb		%ymm3, %ymm1, %ymm1

	# zero-extend and add to YMM8..YMM11
	vpxor		%ymm7, %ymm7, %ymm7
	vpunpcklbw	%ymm7, %ymm0, %ymm4
	vpunpckhbw	%ymm7, %ymm0, %ymm5
	vpunpcklbw	%ymm7, %ymm1, %ymm6
	vpunpckhbw	%ymm7, %ymm1, %ymm1

	vpaddw		%ymm4, %ymm8, %ymm8
	vpaddw		%ymm5, %ymm9, %ymm9
	vpaddw		%ymm6, %ymm10, %ymm10
	vpaddw		%ymm1, %ymm11, %ymm11

.Lendvec:
	vpbroadcastq	.Lmagic+32(%rip), %ymm2	# byte mask
	vmovdqa		.Lmagic(%rip), %ymm3	# permutation mask
	vpxor		%ymm0, %ymm0, %ymm0	# lower counter register
	vpxor		%ymm1, %ymm1, %ymm1	# upper counter register

	# process tail, 8 bytes at a time
	sub		$8-16*32, %ecx		# 8 bytes left to process?
	jl		.Ltail1

.Ltail8:
	count8		0(%rsi), 4(%rsi)
	add		$8, %rsi
	sub		$8, %ecx
	jge		.Ltail8

	# process remaining 0--7 bytes
.Ltail1:
	sub		$-8, %ecx		# anything left to process?
	jle		.Lend

	vmovq		(%rsi), %xmm6		# load 8 bytes from buffer.  This is
						# ok as buf is aligned to 8 bytes here.
	lea		.Lwindow+32(%rip), %rax	# load window address
	sub		%rcx, %rax		# adjust window mask pointer
	vmovq		(%rax), %xmm5		# load window mask
	vpandn		%xmm6, %xmm5, %xmm6	# and mask out the desired bytes
	vpsrldq		$4, %xmm6, %xmm5	# obtain second dword in XMM5
	count8		%xmm6, %xmm5

	# add tail to counters
.Lend:	vpxor		%ymm7, %ymm7, %ymm7
	vpunpcklbw	%ymm7, %ymm0, %ymm4
	vpunpckhbw	%ymm7, %ymm0, %ymm5
	vpunpcklbw	%ymm7, %ymm1, %ymm6
	vpunpckhbw	%ymm7, %ymm1, %ymm1

	vpaddw		%ymm4, %ymm8, %ymm8
	vpaddw		%ymm5, %ymm9, %ymm9
	vpaddw		%ymm6, %ymm10, %ymm10
	vpaddw		%ymm1, %ymm11, %ymm11

	call		*%rbx			# perform final accumulation
	vzeroupper
	ret

	# buffer is short, do just head/tail processing
.Lrunt:	vpxor		%ymm0, %ymm0, %ymm0	# lower counter register
	vpxor		%ymm1, %ymm1, %ymm1	# upper counter register
	sub		$8, %ecx		# 8 bytes left to process?
	jl		.Lrunt1

	# process runt, 8 bytes at a time
.Lrunt8:
	count8		0(%rsi), 4(%rsi)
	add		$8, %rsi
	sub		$4, %ecx
	jge		.Lrunt8

	# process remaining 0--7 bytes
	# while making sure we don't get a page fault
.Lrunt1:
	add		$8, %ecx		# anything left to process
	jle		.Lrunt_accum

	mov		%esi, %eax
	and		$8, %eax		# offset form 8 byte alignment
	lea		(%rax, %rcx, 1), %edx	# length of buffer plus alignment
	shl		$3, %ecx		# remaining length in bits
	movq		$-1, %r9
	shl		%cl, %r9		# mask of bits where R8 is out of range
	cmp		$8, %edx		# if this exceeds the alignment boundary
	jge		.Lcrossrunt1		# we can safely load directly

	and		$~7, %rsi		# align buffer to 8 bytes
	mov		(%rsi), %r8		# and load 8 bytes from buffer
	shl		$3, %eax		# offset form 8 byte alignment in bits
	shrx		%rax, %r8, %r8		# buffer starting at the beginning
	andn		%r8, %r9, %r8
	jmp		.Ldorunt1

.Lcrossrunt1:
	andn		(%rsi), %r9, %r8	# load 8 bytes from unaligned buffer

.Ldorunt1:
	vmovq		%r8, %xmm6
	vpsrldq		$4, %xmm6, %xmm5
	count8		%xmm6, %xmm5

	# move tail to counters and perform final accumulation
.Lrunt_accum:
	vpxor		%ymm7, %ymm7, %ymm7
	vpunpcklbw	%ymm7, %ymm0, %ymm4
	vpunpckhbw	%ymm7, %ymm0, %ymm5
	vpunpcklbw	%ymm7, %ymm1, %ymm6
	vpunpckhbw	%ymm7, %ymm1, %ymm1

	call		*%rbx
	vzeroupper
	ret
	.size		countavx2, .-countavx2

	# zero extend YMM8--YMM11 into dwords and fold the upper
	# 32 counters over the lower 32 counters, leaving the
	# registers with
	# YMM12 contains  0- 3, 16-19
	# YMM8  contains  4- 7, 20-23
	# YMM14 contains  8-11, 24-27
	# YMM9  contains 12-15, 28-31
	# assumes YMM7 == 0
	.macro		fold32
	vpunpcklwd	%ymm7, %ymm8, %ymm12
	vpunpckhwd	%ymm7, %ymm8, %ymm8
	vpunpcklwd	%ymm7, %ymm9, %ymm14
	vpunpckhwd	%ymm7, %ymm9, %ymm9
	vpunpcklwd	%ymm7, %ymm10, %ymm4
	vpunpckhwd	%ymm7, %ymm10, %ymm10
	vpunpcklwd	%ymm7, %ymm11, %ymm5
	vpunpckhwd	%ymm7, %ymm11, %ymm11
	vpaddd		%ymm12, %ymm4, %ymm12
	vpaddd		%ymm8, %ymm10, %ymm8
	vpaddd		%ymm14, %ymm5, %ymm14
	vpaddd		%ymm9, %ymm11, %ymm9
	.endm

	# zero-extend dwords in Y trashing y and z.  Add the low
	# half dwords to a*8(%rdi) and the high half to b*8(%rdi).
	# assumes YMM7 == 0
	.macro		accum a, b, y, z
	vpermq		$0xd8, \y, \z
	vpunpckhdq	%ymm7, \y, \z
	vpunpckldq	%ymm7, \y, \y
	vpaddq		\a*8(%rdi), \y, \y
	vpaddq		\b*8(%rdi), \z, \z
	vmovdqu		\y, \a*8(%rdi)
	vmovdqu		\z, \b*8(%rdi)
	.endm

	.type		accum8, @function
	.balign		16
accum8:	vpaddd		%ymm14, %ymm12, %ymm12
	vpaddd		%ymm9, %ymm8, %ymm8
	vperm2i128	$0x20, %ymm8, %ymm12, %ymm14
	vperm2i128	$0x31, %ymm8, %ymm12, %ymm4
	vpaddd		%ymm4, %ymm14, %ymm12
	accum		0, 4, %ymm12, %ymm14
	ret
	.size		accum8, .-accum8

	.type		accum16, @function
	.balign		16
accum16:
	fold32
	vperm2i128	$0x20, %ymm8, %ymm12, %ymm4
	vperm2i128	$0x31, %ymm8, %ymm12, %ymm10
	vpaddd		%ymm4, %ymm10, %ymm12
	vperm2i128	$0x20, %ymm9, %ymm14, %ymm5
	vperm2i128	$0x31, %ymm9, %ymm14, %ymm11
	accum		0, 4, %ymm12, %ymm14
	accum		8, 12, %ymm4, %ymm5
	ret
	.size		accum16, .-accum16

	.type		accum32, @function
	.balign		16
accum32:
	fold32
	accum		0, 16, %ymm12, %ymm4
	accum		4, 20, %ymm8, %ymm4
	accum		8, 24, %ymm14, %ymm4
	accum		12, 28, %ymm9, %ymm4
	ret
	.size		accum32, .-accum32

	# accumulate the 16 counters in Y into k*8(%rdi) to
	# (k+15)*8(%rdi).  Trashes YMM0--YMM3.  Assumes YMM7 == 0.
	.macro		accum64 k, y
	vpunpcklwd	%ymm7, \y, %ymm12
	vpunpckhwd	%ymm7, \y, %ymm14
	accum		\k, \k+16, %ymm12, %ymm4
	accum		\k+4, \k+20, %ymm14, %ymm4
	.endm

	.type		accum64, @function
	.balign		16
accum64:
	accum64		0, %ymm8
	accum64		8, %ymm9
	accum64		32, %ymm10
	accum64		40, %ymm11
	ret
	.size		accum64, .-accum64

	.globl		count8avx2, count16avx2, count32avx2, count64avx2

	.type		count8avx2, @function
	.balign		16
count8avx2:
	push		%rbx
	lea		accum8(%rip), %rbx
	mov		%rdx, %rcx
	call		countavx2
	pop		%rbx
	ret
	.size		count8avx2, .-count8avx2

	.type		count16avx2, @function
	.balign		16
count16avx2:
	push		%rbx
	lea		accum16(%rip), %rbx
	lea		(%rdx, %rdx, 1), %rcx
	call		countavx2
	pop		%rbx
	ret
	.size		count16avx2, .-count16avx2

	.type		count32avx2, @function
	.balign		16
count32avx2:
	push		%rbx
	lea		accum32(%rip), %rbx
	mov		%rdx, %rcx
	shl		$2, %rcx
	call		countavx2
	pop		%rbx
	ret
	.size		count32avx2, .-count32avx2

	.type		count64avx2, @function
	.balign		16
count64avx2:
	push		%rbx
	lea		accum64(%rip), %rbx
	mov		%rdx, %rcx
	shl		$3, %rcx
	call		countavx2
	pop		%rbx
	ret
	.size		count64avx2, .-count64avx2

	.section	.note.GNU-stack,"",%progbits
