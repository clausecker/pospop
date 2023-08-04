	.section	.rodata

	# sliding window for head/tail loads
	.balign		64
.Lwindow:
	.quad		0x0000000000000000
	.quad		0x0000000000000000
	.quad		0xffffffffffffffff
	.quad		0xffffffffffffffff

	# magic transposition constants
.Lmagic:
	.quad		0x8040201008040201
	.quad		0x00ff00ff0f0f0f0f
	.quad		0xaaaaaaaa55555555
	.quad		0xcccccccc33333333

	# B:A = A+B+C
	.macro		csa a, b, c
	pxor		\c, \b
	pxor		\a, \c
	pxor		\b, \a
	por		\c, \b
	pxor		\a, \b
	.endm

	# Process 4 bytes from xmm4.  Add low word counts to l, high to h.
	# Assumes mask loaded into XMM2.  Trashes XMM4, XMM5
	.macro		count4 l, h
	punpcklbw	%xmm4, %xmm4
	punpcklwd	%xmm4, %xmm4
	pshufd		$0xfa, %xmm4, %xmm5
	punpckldq	%xmm4, %xmm4
	pand		%xmm6, %xmm4
	pand		%xmm6, %xmm5
	pcmpeqb		%xmm6, %xmm4
	pcmpeqb		%xmm6, %xmm5
	psubb		%xmm4, \l
	psubb		%xmm5, \h
	.endm

	# Zero extend x from bytes into words and add to the counter vectors
	# in s1 and s2.  X7 is expected to be a zero register, X6 and X are
	# trashed.
	.macro		accum s1, s2, x
	movdqa		\x, %xmm6
	punpcklbw	%xmm7, \x
	punpckhbw	%xmm7, %xmm6
	paddw		\x, \s1
	paddw		%xmm6, \s2
	.endm

	.text

	# Generic kernel.  This function expects a pointer to a
	# width-specific accumulation function in RBX, a possibly
	# unaligned input buffer in RSI, counters in RDI, and a
	# remaining length in RCX.
	.type		countsse, @function
	.balign		16
countsse2:
	# constants for processing the head
	movq		.Lmagic(%rip), %xmm6	# bit position mask
	pshufd		$0x44, %xmm6, %xmm6	# broadcast into both qwords
	pxor		%xmm7, %xmm7		# zero register
	pxor		%xmm8, %xmm8		# counter registers
	pxor		%xmm10, %xmm10
	pxor		%xmm12, %xmm12
	pxor		%xmm14, %xmm14

	cmp		$15*16, %rcx		# is the CSA kernel worth using?
	jb		.Lrunt

	# load head until alignment/end is reached
	mov		%esi, %edx
	and		$15, %edx
	mov		$16, %eax
	sub		%edx, %eax
	sub		%rdx, %rsi
	add		%rdx, %rcx
	lea		.Lwindow(%rip), %rdx
	movdqu		(%rdx, %rax, 1), %xmm2
	pand		(%rsi), %xmm2

	# load 240 - 16 bytes from buf and sum them into XMM3--XMM0
	movdqa		1*16(%rsi), %xmm1
	movdqa		2*16(%rsi), %xmm0
	movdqa		3*16(%rsi), %xmm5
	movdqa		4*16(%rsi), %xmm4
	movdqa		5*16(%rsi), %xmm3
	csa		%xmm0, %xmm1, %xmm2
	movdqa		6*16(%rsi), %xmm7
	movdqa		7*16(%rsi), %xmm6
	movdqa		8*16(%rsi), %xmm2
	csa		%xmm3, %xmm4, %xmm5
	movdqa		9*16(%rsi), %xmm5
	csa		%xmm2, %xmm6, %xmm7
	movdqa		10*16(%rsi), %xmm7
	csa		%xmm0, %xmm5, %xmm3
	movdqa		11*16(%rsi), %xmm3
	csa		%xmm1, %xmm4, %xmm6
	movdqa		12*16(%rsi), %xmm6
	csa		%xmm0, %xmm2, %xmm7
	movdqa		13*16(%rsi), %xmm7
	pxor		%xmm9, %xmm9		# initialise remaining counters
	pxor		%xmm11, %xmm11
	csa		%xmm3, %xmm7, %xmm6
	movdqa		14*16(%rsi), %xmm6
	csa		%xmm1, %xmm2, %xmm5
	add		$15*16, %rsi
	csa		%xmm0, %xmm3, %xmm6
	mov		$65535, %eax		# space left til overflow in YMM8--YMM11
	csa		%xmm1, %xmm3, %xmm7
	pxor		%xmm13, %xmm15
	csa		%xmm2, %xmm3, %xmm4

	sub		$(15+16)*16, %rcx	# enough data left to process?
	jl		.Lpost

	# load 256 bytes from buf, add them to XMM0--XMM3 into XMM0--XMM4
.Lvec:	movdqa		0*16(%rsi), %xmm4
	movdqa		1*16(%rsi), %xmm5
	movdqa		%xmm8, -40(%rsp)	# stash some counters to give us
	movdqa		%xmm9, -24(%rsp)	# more registers to play with
	movdqa		2*16(%rsi), %xmm6
	movdqa		3*16(%rsi), %xmm7
	movdqa		4*16(%rsi), %xmm8
	movdqa		5*16(%rsi), %xmm9
	csa		%xmm0, %xmm5, %xmm4
	movdqa		6*16(%rsi), %xmm4
	csa		%xmm6, %xmm8, %xmm7
	movdqa		7*16(%rsi), %xmm7
	csa		%xmm1, %xmm8, %xmm5
	movdqa		8*16(%rsi), %xmm5
	csa		%xmm0, %xmm6, %xmm9
	movdqa		9*16(%rsi), %xmm9
	csa		%xmm4, %xmm5, %xmm7
	movdqa		10*16(%rsi), %xmm7
	csa		%xmm1, %xmm5, %xmm6
	movdqa		11*16(%rsi), %xmm6
	csa		%xmm0, %xmm4, %xmm9
	movdqa		12*16(%rsi), %xmm9
	csa		%xmm2, %xmm5, %xmm8
	movdqa		13*16(%rsi), %xmm8
	csa		%xmm0, %xmm6, %xmm7
	movdqa		14*16(%rsi), %xmm7
	csa		%xmm1, %xmm4, %xmm6
	movdqa		15*16(%rsi), %xmm6
	csa		%xmm7, %xmm8, %xmm9
	movdqa		.Lmagic+16(%rip), %xmm9	# 55555555aaaaaaaa33333333cccccccc
	csa		%xmm0, %xmm6, %xmm7
	add		$16*16, %rsi
	csa		%xmm1, %xmm6, %xmm8
	csa		%xmm2, %xmm4, %xmm6
	csa		%xmm3, %xmm4, %xmm5
	movq		.Lmagic+8(%rip), %xmm8	# 0f0f0f00ff00ff

	# now XMM0--XMM4 hold place values; preserve XMM0..XMM4 for the
	# next round and add XMM4 to the counters

	# split into even/odd and reduce into crumbs
	pshufd		$0x00, %xmm9, %xmm7
	movdqa		%xmm4, %xmm5
	pand		%xmm7, %xmm5
	pandn		%xmm4, %xmm7
	psrld		$1, %xmm7
	movdqa		%xmm5, %xmm4
	punpcklqdq	%xmm7, %xmm4
	punpckhqdq	%xmm7, %xmm5
	paddd		%xmm5, %xmm4

	# split again into nibbles
	pshufd		$x0aa, %xmm9, %xmm5
	movdqa		%xmm5, %xmm7
	pandn		%xmm4, %xmm5
	pand		%xmm7, %xmm4
	psrld		$2, %xmm5

	# split into bytes and shuffle into order
	pshufd		$0x00, %xmm8, %xmm6
	movdqa		%xmm6, %xmm7
	pandn		%xmm4, %xmm6
	pand		%xmm7, %xmm4
	movdqa		%xmm7, %xmm9
	pandn		%xmm5, %xmm7
	pslld		$4, %xmm4
	pslld		$4, %xmm5

	movdqa		%xmm4, %xmm9
	punpcklwd	%xmm5, %xmm4
	punpckhwd	%xmm5, %xmm9
	movdqa		%xmm6, %xmm5
	punpcklwd	%xmm7, %xmm5
	punpckhwd	%xmm7, %xmm6
	movdqa		%xmm4, %xmm7
	punpcklwd	%xmm9, %xmm4
	punpckhwd	%xmm9, %xmm7
	movdqa		%xmm5, %xmm9
	punpcklwd	%xmm6, %xmm5
	punpckhwd	%xmm6, %xmm9
	movdqa		%xmm4, %xmm6
	punpcklqdq	%xmm5, %xmm4
	punpckhqdq	%xmm5, %xmm6
	movdqa		%xmm7, %xmm5
	punpcklqdq	%xmm9, %xmm5
	punpckhqdq	%xmm9, %xmm7

	# split into words and add to counters
	pshufd		$0x55, %xmm8, %xmm8
	movdqa		%xmm6, %xmm9
	pand		%xmm8, %xmm6
	psrlw		$8, %xmm9
	paddw		%xmm6, %xmm10
	paddw		%xmm9, %xmm11

	movdqa		%xmm7, %xmm6
	movdqa		-40(%rsp), %xmm8
	movdqa		%xmm5, %xmm9
	pand		%xmm6, %xmm5
	psrlw		$8, %xmm9
	paddw		%xmm5, %xmm12
	paddw		%xmm9, %xmm13

	movdqa		-24(%rsp), %xmm9
	movdqa		%xmm7, %xmm5
	pand		%xmm6, %xmm7
	psrlw		$8, %xmm5
	paddw		%xmm7, %xmm14
	paddw		%xmm5, %xmm15

	movdqa		%xmm4, %xmm5
	pand		%xmm6, %xmm4
	psrlw		$8, %xmm5
	paddw		%xmm4, %xmm8
	paddw		%xmm5, %xmm9

	sub		$16*2, %eax
	cmp		$(15+15+16)*2, %eax
	jge		.Lhave_space

	pxor		%xmm7, %xmm7
	call		*%rbx
	pxor		%xmm8, %xmm8
	pxor		%xmm9, %xmm9
	pxor		%xmm10, %xmm10
	pxor		%xmm11, %xmm11
	pxor		%xmm12, %xmm12
	pxor		%xmm13, %xmm13
	pxor		%xmm14, %xmm14
	pxor		%xmm15, %xmm15

	mov		$65535, %eax

.Lhave_space:
	sub		$16*16, %rcx
	jae		.Lvec

.Lpost:	movq		.Lmagic+16(%rip), %xmm5
	pshufd		$0x55, %xmm5, %xmm6		# aaaaaaaa
	pshufd		$0x00, %xmm5, %xmm7		# 55555555

	# group XMM0--XMM3 into nibbles in the same register
	movdqa		%xmm0, %xmm5
	pand		%xmm6, %xmm5
	psrld		$1, %xmm5
	movdqa		%xmm1, %xmm4
	pand		%xmm7, %xmm4
	paddd		%xmm4, %xmm4
	pand		%xmm7, %xmm0
	pand		%xmm6, %xmm1
	por		%xmm4, %xmm0
	por		%xmm5, %xmm1

	movdqa		%xmm2, %xmm5
	pand		%xmm6, %xmm5
	psrld		$1, %xmm5
	movdqa		%xmm3, %xmm4
	pand		%xmm7, %xmm4
	paddd		%xmm4, %xmm4
	pand		%xmm7, %xmm2
	pand		%xmm6, %xmm3
	por		%xmm4, %xmm2
	por		%xmm5, %xmm3

	movq		.Lmagic+24(%rip), %xmm7
	pshufd		$0x55, %xmm7, %xmm6
	pshufd		$0x00, %xmm7, %xmm7

	movdqa		%xmm0, %xmm5
	pand		%xmm6, %xmm5
	psrld		$2, %xmm5
	movdqa		%xmm2, %xmm4
	pand		%xmm7, %xmm4
	pslld		$2, %xmm4
	pand		%xmm7, %xmm0
	pand		%xmm6, %xmm2
	por		%xmm4, %xmm0
	por		%xmm5, %xmm2

	movdqa		%xmm1, %xmm5
	pand		%xmm6, %xmm5
	psrld		$2, %xmm5
	movdqa		%xmm3, %xmm4
	pand		%xmm7, %xmm4
	pslld		$2, %xmm4
	pand		%xmm7, %xmm1
	pand		%xmm6, %xmm3
	por		%xmm4, %xmm1
	por		%xmm5, %xmm3

	movd		magic+8(%rip), %xmm7
	pshufd		$0x00, %xmm7, %xmm7	# 0x0f0f0f0f

	# pre-shuffle nibbles
	movdqa		%xmm2, %xmm5
	punpcklbw	%xmm3, %xmm2
	punpckhbw	%xmm3, %xmm5
	movdqa		%xmm0, %xmm3
	punpcklbw	%xmm1, %xmm0
	punpckhbw	%xmm1, %xmm3
	movdqa		%xmm0, %xmm1
	punpcklwd	%xmm2, %xmm0
	punpckhwd	%xmm2, %xmm1
	movdqa		%xmm3, %xmm2
	punpcklwd	%xmm5, %xmm2
	punpckhwd	%xmm5, %xmm3

	# pull out high and low nibbles and reduce once
	movdqa		%xmm0, %xmm4
	psrld		$4, %xmm4
	pand		%xmm7, %xmm0
	pand		%xmm7, %xmm4

	movdqa		%xmm2, %xmm6
	psrld		$4, %xmm2
	pand		%xmm7, %xmm6
	pand		%xmm7, %xmm2

	paddb		%xmm6, %xmm0
	paddb		%xmm4, %xmm2

	movdqa		%xmm1, %xmm4
	psrld		$4, %xmm4
	pand		%xmm7, %xmm1
	pand		%xmm7, %xmm4

	movdqa		%xmm3, %xmm6
	psrld		$4, %xmm2
	pand		%xmm7, %xmm6
	pand		%xmm7, %xmm3

	paddb		%xmm6, %xmm1
	paddb		%xmm4, %xmm3

	# unpack one last time
	movdqa		%xmm0, %xmm4
	punpckldq	%xmm2, %xmm0
	punpckhdq	%xmm2, %xmm4
	movdqa		%xmm1, %xmm5
	punpckldq	%xmm3, %xmm1
	punpckhdq	%xmm3, %xmm5

	# add to counters
	pxor		%xmm7, %xmm7
	accum		%xmm8, %xmm9, %xmm0
	accum		%xmm10, %xmm11, %xmm4
	accum		%xmm12, %xmm13, %xmm1
	accum		%xmm14, %xmm15, %xmm5

	# constants for processing the tail
.Lendvec:
	movq		.Lmagic(%rip), %xmm6
	pshufd		$0x44, %xmm6, %xmm6
	pxor		%xmm0, %xmm0
	pxor		%xmm1, %xmm1
	pxor		%xmm2, %xmm2
	pxor		%xmm3, %xmm3

	# process tail, 4 bytes at a time
	sub		$8-16*16, %ecx
	jl		.Ltail1

.Ltail8:
	movd		0(%rsi), %xmm4
	count4		%xmm0, %xmm1
	movd		4(%rsi), %xmm4
	count4		%xmm2, %xmm3
	add		$8, %rsi
	sub		$8, %ecx
	jge		.Ltail8

	# process remaining 0--7 bytes
.Ltail1:
	subl		$-8, %ecx
	jle		.Lend

	movq		(%rsi), %xmm5
	lea		window+16(%rip), %rax
	sub		%ecx, %eax
	movq		(%rax), %xmm7
	pandn		%xmm5, %xmm7

	# process rest
	movdqa		%xmm7, %xmm4
	count4		%xmm0, %xmm1
	pshufd		$0x55, %xmm7, %xmm4
	count4		%xmm2, %xmm3

	# add tail to counters
.Lend:	pxor		%xmm7, %xmm7
	movdqa		%xmm0, %xmm4
	punpcklbw	%xmm7, %xmm0
	punpckhbw	%xmm7, %xmm4
	paddw		%xmm0, %xmm8
	paddw		%xmm4, %xmm9
	movdqa		%xmm1, %xmm4
	punpcklbw	%xmm7, %xmm1
	punpckhbw	%xmm7, %xmm4
	paddw		%xmm1, %xmm10
	paddw		%xmm4, %xmm11
	movdqa		%xmm2, %xmm4
	punpcklbw	%xmm7, %xmm2
	punpckhbw	%xmm7, %xmm4
	paddw		%xmm2, %xmm12
	paddw		%xmm4, %xmm13
	movdqa		%xmm3, %xmm4
	punpcklbw	%xmm7, %xmm3
	punpckhbw	%xmm7, %xmm4
	paddw		%xmm3, %xmm14
	paddw		%xmm4, %xmm15
	jmp		*%rbx

	# buffer is short, do just head/tail processing
.Lrunt:	sub		$8, %ecx
	jl		.Lrunt1

	# process runt 8 bytes at a time
.Lrunt8:
	movd		0(%rsi), %xmm4
	count4		%xmm8, %xmm10
	movd		4(%rsi), %xmm4
	count4		%xmm12, %xmm14
	add		$8, %rsi
	sub		$8, %ecx
	jge		.LRunt8

	# process remaining 0--7 bytes
	# while making sure we don't get a page fault
.Lrunt1:
	add		$8, %ecx
	jle		.Lrunt_accum

	mov		%esi, %eax
	and		$7, %eax
	lea		(%eax, %ecx, 1), %edx
	shl		$3, %ecx
	xor		%r9, %r9
	bts		%rcx, %r9
	dec		%r9
	cmp		$8, %edx
	jge		.Lcrossrunt1

	and		$~7, %rsi
	mov		(%rsi), %r8
	lea		(, %rax, 8), %ecx
	shr		%cl, %r8
	jmp		.Ldorunt1

.Lcrossrunt1:
	movq		(%rsi), %r8

.Ldorunt1:
	andq		%r9, %r8
	movd		%r8d, %xmm4
	shr		$4, %r8
	count4		%xmm8, %xmm10
	movd		%r8d, %xmm4
	count4		%xmm12, %xmm14

	# move tail to counters and perform final accumulation
.Lrunt_accum:
	movdqa		%xmm8, %xmm9
	punpcklbw	%xmm7, %xmm8
	punpckhbw	%xmm7, %xmm9
	movdqa		%xmm10, %xmm11
	punpcklbw	%xmm7, %xmm10
	punpckhbw	%xmm7, %xmm11
	movdqa		%xmm12, %xmm13
	punpcklbw	%xmm7, %xmm12
	punpckhbw	%xmm7, %xmm13
	movdqa		%xmm14, %xmm15
	punpcklbw	%xmm7, %xmm14
	punpckhbw	%xmm7, %xmm15
	jmp		*%rbx
	.size		countsse2, .-countsse2


	# zero-extend dwords in x trashing x, XMM4, and XMM5.  Add the
	# low half dwords to a*8(%rdi) and the high half to
	# (a+2)*8(%rdi).  Assumes XMM7 == 0.
	.macro		accumq a, x
	movdqa		\x, %xmm4
	punpckldq	%xmm7, \x
	punpckhdq	%xmm7, %xmm4
	movdqu		(\a)*8(%rdi), %xmm5
	paddq		\x, %xmm5
	movdqu		%xmm5, (\a)*8(%rdi)
	movdqu		(\a+2)*8(%rdi), %xmm5
	paddq		%xmm4, %xmm5
	movdqu		%xmm5, (\a+2)*8(%rdi)
	.endm

	# zero-extend words in x to qwords and add to a*8(%rdi).
	# Trashes XMM4, XMM5, and XMM6.  Assumes X7 == 0 and
	# %xmm8 <= x <= %xmm15.
	.macro		accumdq a, x
	movdqa		\x, %xmm6
	punpcklwd	%xmm7, %xmm6
	punpckhwd	%xmm7, \x
	accumq		\a, %xmm6
	accumq		\a+4, \x
	.endm

	# zero-extend words in x and y to dwords, sum them, and move the
	# halves back into x and y.  Assumes XMM7 == 0.  Trashes X4, X5.
	.macro		foldw x, y
	movdqa		\x, %xmm4
	punpcklwd	%xmm7, \x
	punpckhwd	%xmm7, %xmm4
	movdqa		\y, %xmm5
	punpcklwd	%xmm7, %xmm5
	punpckhwd	%xmm7, \y
	paddd		%xmm5, \x
	paddd		%xmm4, \y
	.endm

	.type		accum8, @function
	.balign		16
accum8:	foldw		%xmm8, %xmm12
	foldw		%xmm9, %xmm13
	foldw		%xmm10, %xmm14
	foldw		%xmm11, %xmm15
	paddd		%xmm10, %xmm8
	paddd		%xmm11, %xmm9
	paddd		%xmm14, %xmm12
	paddd		%xmm15, %xmm13
	paddd		%xmm9, %xmm8
	accumq		0, %xmm8
	paddd		%xmm13, %xmm12
	accumq		4, %xmm12
	ret
	.size		accum8, .-accum8

	.type		accum16, @function
	.balign		16
accum16:
	foldw		%xmm8, %xmm12
	foldw		%xmm9, %xmm13
	foldw		%xmm10, %xmm14
	foldw		%xmm11, %xmm15
	paddd		%xmm10, %xmm8
	accumq		0, %xmm8
	paddd		%xmm14, %xmm12
	accumq		4, %xmm12
	paddd		%xmm11, %xmm9
	accumq		8, %xmm9
	paddd		%xmm15, %xmm13
	accumq		12, %xmm13
	ret
	.size		accum16, .-accum16

	.type		accum32, @function
	.balign		16
accum32:
	foldw		%xmm8, %xmm12
	accumq		0, %xmm8
	accumq		4, %xmm12
	foldw		%xmm9, %xmm13
	accumq		8, %xmm9
	accumq		12, %xmm13
	foldw		%xmm10, %xmm14
	accumq		16, %xmm10
	accumq		20, %xmm14
	foldw		%xmm11, %xmm15
	accumq		24, %xmm11
	accumq		28, %xmm15
	ret
	.size		accum32, .-accum32

	.type		accum64, @function
	.balign		16
accum64:
	accumdq		0, %xmm8
	accumdq		8, %xmm9
	accumdq		16, %xmm10
	accumdq		24, %xmm11
	accumdq		32, %xmm12
	accumdq		40, %xmm13
	accumdq		48, %xmm14
	accumdq		56, %xmm15
	ret
	.size		accum64, .-accum64


	.globl count8sse2, count16sse2, count32sse2, count64sse2

	.type		count8sse2, @function
	.balign		16
count8sse2:
	push		%rbx
	lea		accum8(%rip), %rbx
	mov		%rdx, %rcx
	call		countsse2
	pop		%rbx
	ret
	.size		count8sse2, .-count8sse2

	.type		count16sse2, @function
	.balign		16
count16sse2:
	push		%rbx
	lea		accum16(%rip), %rbx
	lea		(%rdx, %rdx, 1), %rcx
	call		countsse2
	ret
	.size		count16sse2, .-count16sse2

	.type		count32sse2, @function
	.balign		16
count32sse2:
	push		%rbx
	lea		accum32(%rip), %rbx
	mov		%rdx, %rcx
	shl		$2, %rcx
	call		countsse2
	pop		%rbx
	ret
	.size		count32sse2, .-count32sse2

	.type		count64sse2, @function
	.balign		16
count64sse2:
	push		%rbx
	lea		accum64(%rip), %rbx
	mov		%rdx, %rcx
	shl		$3, %rcx
	call		countsse2
	pop		%rbx
	ret
	.size		count64sse2, .-count64sse2

	.section .note.GNU-stack,"",%progbits
