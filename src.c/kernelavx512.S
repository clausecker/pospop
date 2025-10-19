# AVX-512 positional popcount with 15-fold CSA reduction
# by Robert Clausecker <fuz@fuz.su>

	.intel_syntax noprefix
	.section .rodata
	.balign	32
magic:	.long 0x55555555
	.long 0x33333333
	.long 0x0f0f0f0f
	.long 0x00ff00ff
	.quad 0x1c1814100c080400
	.quad 0x1d1915110d090501
	.quad 0x1e1a16120e0a0602
	.quad 0x1f1b17130f0b0703
	.size magic, .-magic

	.section .text
	.type countavx512, @function
	.balign	16
countavx512:
	push    rbp
	mov     rbp, rsp
	vpternlogd zmm30, zmm30, zmm30, 0xFF
	vpxord  ymm25, ymm25, ymm25
	cmp     rcx, 960
	jl      .L72

	mov     rax, -1
	shlx    rax, rax, rsi
	kmovq   k1, rax
	add     rcx, rsi
	and     rsi, 0xFFFFFFFFFFFFFFC0
	sub     rcx, rsi
	vmovdqu8 zmm0 {k1}{z}, [rsi]
	vmovdqa64 zmm1, [rsi+0x1*0x40]
	vmovdqa64 zmm4, [rsi+0x2*0x40]
	vpxor   ymm8, ymm8, ymm8
	vpxor   ymm9, ymm9, ymm9
	vmovdqa64 zmm2, [rsi+0x3*0x40]
	vmovdqa64 zmm3, [rsi+0x4*0x40]
	vmovdqa64 zmm5, [rsi+0x5*0x40]
	vmovdqa64 zmm22, zmm0
	vpternlogd zmm0, zmm1, zmm4, 0x96
	vpternlogd zmm1, zmm22, zmm4, 0xE8
	vmovdqa64 zmm6, [rsi+0x6*0x40]
	vmovdqa64 zmm7, [rsi+0x7*0x40]
	vmovdqa64 zmm10, [rsi+0x8*0x40]
	vmovdqa64 zmm22, zmm2
	vpternlogd zmm2, zmm3, zmm5, 0x96
	vpternlogd zmm3, zmm22, zmm5, 0xE8
	vmovdqa64 zmm11, [rsi+0x9*0x40]
	vmovdqa64 zmm12, [rsi+0xA*0x40]
	vmovdqa64 zmm13, [rsi+0xB*0x40]
	vmovdqa64 zmm22, zmm6
	vpternlogd zmm6, zmm7, zmm10, 0x96
	vpternlogd zmm7, zmm22, zmm10, 0xE8
	vmovdqa64 zmm4, [rsi+0xC*0x40]
	vmovdqa64 zmm5, [rsi+0xD*0x40]
	vmovdqa64 zmm10, [rsi+0xE*0x40]
	vmovdqa64 zmm22, zmm11
	vpternlogd zmm11, zmm12, zmm13, 0x96
	vpternlogd zmm12, zmm22, zmm13, 0xE8
	vpbroadcastd zmm28, [magic+rip]
	vpbroadcastd zmm27, [magic+4+rip]
	vpbroadcastd zmm26, [magic+8+rip]
	vmovdqa64 zmm22, zmm4
	vpternlogd zmm4, zmm5, zmm10, 0x96
	vpternlogd zmm5, zmm22, zmm10, 0xE8
	vmovdqa64 zmm22, zmm0
	vpternlogd zmm0, zmm2, zmm6, 0x96
	vpternlogd zmm2, zmm22, zmm6, 0xE8
	vmovdqa64 zmm22, zmm1
	vpternlogd zmm1, zmm3, zmm7, 0x96
	vpternlogd zmm3, zmm22, zmm7, 0xE8
	vmovdqa64 zmm22, zmm0
	vpternlogd zmm0, zmm11, zmm4, 0x96
	vpternlogd zmm11, zmm22, zmm4, 0xE8
	vmovdqa64 zmm22, zmm2
	vpternlogd zmm2, zmm12, zmm5, 0x96
	vpternlogd zmm12, zmm22, zmm5, 0xE8
	vmovdqa64 zmm22, zmm1
	vpternlogd zmm1, zmm2, zmm11, 0x96
	vpternlogd zmm2, zmm22, zmm11, 0xE8
	vmovdqa64 zmm22, zmm2
	vpternlogd zmm2, zmm3, zmm12, 0x96
	vpternlogd zmm3, zmm22, zmm12, 0xE8
	add     rsi, 960
	sub     rcx, 1984
	jl      .L68

	vpbroadcastd zmm24, [magic+12+rip]
	vpmovzxbw zmm23, [magic+16+rip]
	mov     eax, 65535

.L66:	vmovdqa64	zmm4, [rsi]
	vmovdqa64 zmm5, [rsi+0x1*0x40]
	vmovdqa64 zmm6, [rsi+0x2*0x40]
	vmovdqa64 zmm7, [rsi+0x3*0x40]
	vmovdqa64 zmm10, [rsi+0x4*0x40]
	vmovdqa64 zmm22, zmm0
	vpternlogd zmm0, zmm4, zmm5, 0x96
	vpternlogd zmm4, zmm22, zmm5, 0xE8
	vmovdqa64 zmm5, [rsi+0x5*0x40]
	vmovdqa64 zmm11, [rsi+0x6*0x40]
	vmovdqa64 zmm12, [rsi+0x7*0x40]
	vmovdqa64 zmm22, zmm6
	vpternlogd zmm6, zmm7, zmm10, 0x96
	vpternlogd zmm7, zmm22, zmm10, 0xE8
	vmovdqa64 zmm10, [rsi+0x8*0x40]
	vmovdqa64 zmm13, [rsi+0x9*0x40]
	vmovdqa64 zmm14, [rsi+0xA*0x40]
	vmovdqa64 zmm22, zmm5
	vpternlogd zmm5, zmm11, zmm12, 0x96
	vpternlogd zmm11, zmm22, zmm12, 0xE8
	vmovdqa64 zmm12, [rsi+0xB*0x40]
	vmovdqa64 zmm15, [rsi+0xC*0x40]
	vmovdqa64 zmm16, [rsi+0xD*0x40]
	vmovdqa64 zmm22, zmm10
	vpternlogd zmm10, zmm13, zmm14, 0x96
	vpternlogd zmm13, zmm22, zmm14, 0xE8
	vmovdqa64 zmm14, [rsi+0xE*0x40]
	vmovdqa64 zmm17, [rsi+0xF*0x40]
	vmovdqa64 zmm22, zmm12
	vpternlogd zmm12, zmm15, zmm16, 0x96
	vpternlogd zmm15, zmm22, zmm16, 0xE8
	add     rsi, 1024
	prefetcht0 [rsi]
	vmovdqa64 zmm22, zmm0
	vpternlogd zmm0, zmm5, zmm6, 0x96
	vpternlogd zmm5, zmm22, zmm6, 0xE8
	prefetcht0 [rsi+0x40]
	vmovdqa64 zmm22, zmm1
	vpternlogd zmm1, zmm4, zmm7, 0x96
	vpternlogd zmm4, zmm22, zmm7, 0xE8
	vmovdqa64 zmm22, zmm10
	vpternlogd zmm10, zmm12, zmm14, 0x96
	vpternlogd zmm12, zmm22, zmm14, 0xE8
	vmovdqa64 zmm22, zmm11
	vpternlogd zmm11, zmm13, zmm15, 0x96
	vpternlogd zmm13, zmm22, zmm15, 0xE8
	vmovdqa64 zmm22, zmm0
	vpternlogd zmm0, zmm10, zmm17, 0x96
	vpternlogd zmm10, zmm22, zmm17, 0xE8
	vmovdqa64 zmm22, zmm1
	vpternlogd zmm1, zmm5, zmm11, 0x96
	vpternlogd zmm5, zmm22, zmm11, 0xE8
	vmovdqa64 zmm22, zmm2
	vpternlogd zmm2, zmm4, zmm13, 0x96
	vpternlogd zmm4, zmm22, zmm13, 0xE8
	vmovdqa64 zmm22, zmm1
	vpternlogd zmm1, zmm10, zmm12, 0x96
	vpternlogd zmm10, zmm22, zmm12, 0xE8
	vmovdqa64 zmm22, zmm2
	vpternlogd zmm2, zmm5, zmm10, 0x96
	vpternlogd zmm5, zmm22, zmm10, 0xE8
	vmovdqa64 zmm22, zmm3
	vpternlogd zmm3, zmm4, zmm5, 0x96
	vpternlogd zmm4, zmm22, zmm5, 0xE8
	vpandd  zmm5, zmm28, zmm4
	vpandnd zmm6, zmm28, zmm4
	vpsrld  zmm6, zmm6, 1
	vshufi64x2 zmm10, zmm5, zmm6, 0x44
	vshufi64x2 zmm11, zmm5, zmm6, 0xEE
	vpaddd  zmm4, zmm11, zmm10
	vpandd  zmm5, zmm27, zmm4
	vpandnd zmm6, zmm27, zmm4
	vpsrld  zmm6, zmm6, 2
	vshufi64x2 zmm10, zmm5, zmm6, 0x88
	vshufi64x2 zmm11, zmm5, zmm6, 0xDD
	vpaddd  zmm4, zmm11, zmm10
	vpandd  zmm5, zmm26, zmm4
	vpandnd zmm6, zmm26, zmm4
	vpslld  zmm5, zmm5, 4
	vpermq  zmm5, zmm5, 0xD8
	vpermq  zmm6, zmm6, 0xD8
	vshufi64x2 zmm10, zmm5, zmm6, 0x88
	vshufi64x2 zmm11, zmm5, zmm6, 0xDD
	vpaddd  zmm4, zmm11, zmm10
	vpsrlw  zmm6, zmm4, 8
	vpandd  zmm5, zmm24, zmm4
	vpaddw  zmm8, zmm8, zmm5
	vpaddw  zmm9, zmm9, zmm6
	sub     eax, 128
	cmp     eax, 240
	jge     .L67

	vpermw  zmm8, zmm23, zmm8
	vpermw  zmm9, zmm23, zmm9
	call    rbx
	vpxor   ymm8, ymm8, ymm8
	vpxor   ymm9, ymm9, ymm9
	mov     eax, 65535

.L67:	sub	rcx, 1024
	jge     .L66

	vpermw  zmm8, zmm23, zmm8
	vpermw  zmm9, zmm23, zmm9

.L68:	vpsrld	zmm4, zmm0, 1
	vpaddd  zmm5, zmm1, zmm1
	vpsrld  zmm6, zmm2, 1
	vpaddd  zmm7, zmm3, zmm3
	vpternlogd zmm0, zmm5, zmm28, 0xE4
	vpternlogd zmm1, zmm4, zmm28, 0xD8
	vpternlogd zmm2, zmm7, zmm28, 0xE4
	vpternlogd zmm3, zmm6, zmm28, 0xD8
	vpsrld  zmm4, zmm0, 2
	vpsrld  zmm6, zmm1, 2
	vpslld  zmm5, zmm2, 2
	vpslld  zmm7, zmm3, 2
	vpternlogd zmm2, zmm4, zmm27, 0xD8
	vpternlogd zmm3, zmm6, zmm27, 0xD8
	vpternlogd zmm0, zmm5, zmm27, 0xE4
	vpternlogd zmm1, zmm7, zmm27, 0xE4
	vpunpcklbw zmm6, zmm2, zmm3
	vpunpckhbw zmm3, zmm2, zmm3
	vpunpcklbw zmm5, zmm0, zmm1
	vpunpckhbw zmm2, zmm0, zmm1
	vpunpcklwd zmm4, zmm5, zmm6
	vpunpckhwd zmm5, zmm5, zmm6
	vpunpcklwd zmm6, zmm2, zmm3
	vpunpckhwd zmm7, zmm2, zmm3
	vpandd  zmm0, zmm4, zmm26
	vpsrld  zmm4, zmm4, 4
	vpandd  zmm4, zmm4, zmm26
	vpandd  zmm1, zmm5, zmm26
	vpsrld  zmm5, zmm5, 4
	vpandd  zmm5, zmm5, zmm26
	vpandd  zmm2, zmm6, zmm26
	vpsrld  zmm6, zmm6, 4
	vpandd  zmm6, zmm6, zmm26
	vpandd  zmm3, zmm7, zmm26
	vpsrld  zmm7, zmm7, 4
	vpandd  zmm7, zmm7, zmm26
	vpaddb  zmm0, zmm0, zmm2
	vpaddb  zmm1, zmm1, zmm3
	vpaddb  zmm2, zmm4, zmm6
	vpaddb  zmm3, zmm5, zmm7
	vpunpckldq zmm4, zmm0, zmm2
	vpunpckhdq zmm5, zmm0, zmm2
	vpunpckldq zmm6, zmm1, zmm3
	vpunpckhdq zmm7, zmm1, zmm3
	vshufi64x2 zmm0, zmm4, zmm5, 0x44
	vshufi64x2 zmm1, zmm4, zmm5, 0xEE
	vshufi64x2 zmm2, zmm6, zmm7, 0x44
	vshufi64x2 zmm3, zmm6, zmm7, 0xEE
	vpaddb  zmm0, zmm0, zmm1
	vpaddb  zmm2, zmm2, zmm3
	vshufi64x2 zmm1, zmm0, zmm2, 0x88
	vshufi64x2 zmm0, zmm0, zmm2, 0xDD
	vpaddb  zmm0, zmm0, zmm1
	vpunpcklbw zmm1, zmm0, zmm25
	vpunpckhbw zmm2, zmm0, zmm25
	vpaddw  zmm8, zmm8, zmm1
	vpaddw  zmm9, zmm9, zmm2
	vpxor   ymm0, ymm0, ymm0
	cmp     ecx, -1024
	jz      .L71

	sub     ecx, -1016
	jle     .L70

.L69:	kmovq	k1, [rsi]
	add     rsi, 8
	vpsubb  zmm0 {k1}, zmm0, zmm30
	sub     ecx, 8
	jg      .L69

.L70:	lea	ecx, [rcx*8+0x40]
	bzhi    rax, [rsi], rcx
	kmovq   k1, rax
	vpsubb  zmm0 {k1}, zmm0, zmm30
	vpunpcklbw zmm1, zmm0, zmm25
	vpunpckhbw zmm2, zmm0, zmm25
	vpaddw  zmm8, zmm8, zmm1
	vpaddw  zmm9, zmm9, zmm2

.L71:	call	rbx
	vzeroupper
	pop     rbp
	ret

.L72:	vpxor   ymm0, ymm0, ymm0
	sub     ecx, 8
	jle     .L74

.L73:	kmovq   k1, [rsi]
	add     rsi, 8
	vpsubb  zmm0 {k1}, zmm0, zmm30
	sub     rcx, 8
	jg      .L73

	lea     edx, [rcx*8]
	neg     edx
	shrx    rax, [rsi+rcx], rdx
	kmovq   k1, rax
	vpsubb  zmm0 {k1}, zmm0, zmm30
	vpunpcklbw zmm8, zmm0, zmm25
	vpunpckhbw zmm9, zmm0, zmm25
	call    rbx
	vzeroupper
	pop     rbp
	ret

.L74:	add     ecx, 8
	xor     eax, eax
	bts     eax, ecx
	dec     eax
	kmovd   k1, eax
	vmovdqu8 xmm4 {k1}{z}, [rsi]
	vmovq   rax, xmm4
	kmovq   k1, rax
	vpsubb  zmm0 {k1}, zmm0, zmm30
	vpunpcklbw zmm8, zmm0, zmm25
	vpunpckhbw zmm9, zmm0, zmm25
	call    rbx
	vzeroupper
	pop     rbp
	ret
	.size	countavx512, .-countavx512

	.balign 16
	.globl count8avx512
	.type   count8avx512, @function
count8avx512:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum8+rip]
	call    countavx512
	pop	rbx
	pop	rbp
	ret
	.size   count8avx512, .-count8avx512

	.balign 16
	.globl count16avx512
	.type   count16avx512, @function
count16avx512:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum16+rip]
	shl     rcx, 1
	call    countavx512
	pop	rbx
	pop	rbp
	ret
	.size   count16avx512, .-count16avx512

	.balign 16
	.globl count32avx512
	.type   count32avx512, @function
count32avx512:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum32+rip]
	shl	rcx, 2
	call    countavx512
	pop	rbx
	pop	rbp
	ret
	.size   count32avx512, .-count32avx512

	.balign 16
	.globl count64avx512
	.type   count64avx512, @function
count64avx512:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum64+rip]
	shl	rcx, 3
	call    countavx512
	pop	rbx
	pop	rbp
	ret
	.size   count64avx512, .-count64avx512
