# AVX2 positional popcount with 15-fold CSA reduction
# by Robert Clausecker <fuz@fuz.su>

	.intel_syntax noprefix
	.section .rodata
	.balign 32
magic:	.quad	0x0000000000000000
	.quad	0x0101010101010101
	.quad	0x0202020202020202
	.quad	0x0303030303030303
	.quad	0x0404040404040404
	.quad	0x0505050505050505
	.quad	0x0606060606060606
	.quad	0x0707070707070707
	.quad	0x8040201008040201
	.long	0x55555555
	.long	0x33333333
	.long	0x0f0f0f0f
	.long	0x00ff00ff
	.size	magic, .-magic

window:	.quad	0, 0, 0, 0, -1, -1, -1, -1
	.size	window, .-window

	.section .text
	.type   countavx2, @function
	.balign	16
countavx2:
	push    rbp
	mov     rbp, rsp
	cmp     rcx, 480
	jl      .L56

	mov     edx, esi
	and     edx, 0x1F
	mov     eax, 32
	sub     eax, edx
	sub     rsi, rdx
	vmovdqa ymm0, [rsi]
	add     rcx, rdx
	lea     rdx, [window+rip]
	vpand   ymm0, ymm0, [rdx+rax]
	vmovdqa ymm1, [rsi+0x20]
	vmovdqa ymm4, [rsi+0x40]
	vmovdqa ymm2, [rsi+0x60]
	vmovdqa ymm3, [rsi+0x80]
	vmovdqa ymm5, [rsi+0xA0]
	vmovdqa ymm6, [rsi+0xC0]
	vpand   ymm7, ymm1, ymm0
	vpxor   ymm0, ymm1, ymm0
	vpand   ymm1, ymm4, ymm0
	vpxor   ymm0, ymm4, ymm0
	vpor    ymm1, ymm7, ymm1
	vmovdqa ymm4, [rsi+0xE0]
	vpand   ymm7, ymm2, ymm3
	vpxor   ymm3, ymm2, ymm3
	vpand   ymm2, ymm5, ymm3
	vpxor   ymm3, ymm5, ymm3
	vpor    ymm2, ymm7, ymm2
	vmovdqa ymm5, [rsi+0x100]
	vpand   ymm7, ymm3, ymm0
	vpxor   ymm0, ymm3, ymm0
	vpand   ymm3, ymm6, ymm0
	vpxor   ymm0, ymm6, ymm0
	vpor    ymm3, ymm7, ymm3
	vmovdqa ymm6, [rsi+0x120]
	vpand   ymm7, ymm2, ymm1
	vpxor   ymm1, ymm2, ymm1
	vpand   ymm2, ymm3, ymm1
	vpxor   ymm1, ymm3, ymm1
	vpor    ymm2, ymm7, ymm2
	vmovdqa ymm3, [rsi+0x140]
	vpand   ymm7, ymm4, ymm0
	vpxor   ymm0, ymm4, ymm0
	vpand   ymm4, ymm5, ymm0
	vpxor   ymm0, ymm5, ymm0
	vpor    ymm4, ymm7, ymm4
	vmovdqa ymm5, [rsi+0x160]
	vpand   ymm7, ymm3, ymm0
	vpxor   ymm0, ymm3, ymm0
	vpand   ymm3, ymm6, ymm0
	vpxor   ymm0, ymm6, ymm0
	vpor    ymm3, ymm7, ymm3
	vmovdqa ymm6, [rsi+0x180]
	vpand   ymm7, ymm3, ymm1
	vpxor   ymm1, ymm3, ymm1
	vpand   ymm3, ymm4, ymm1
	vpxor   ymm1, ymm4, ymm1
	vpor    ymm3, ymm7, ymm3
	vmovdqa ymm4, [rsi+0x1A0]
	vpand   ymm7, ymm5, ymm0
	vpxor   ymm0, ymm5, ymm0
	vpand   ymm5, ymm6, ymm0
	vpxor   ymm0, ymm6, ymm0
	vpor    ymm5, ymm7, ymm5
	vmovdqa ymm6, [rsi+0x1C0]
	vpbroadcastd ymm15, [magic+72+rip]
	vpbroadcastd ymm13, [magic+76+rip]
	vpand   ymm7, ymm4, ymm0
	vpxor   ymm0, ymm4, ymm0
	vpand   ymm4, ymm6, ymm0
	vpxor   ymm0, ymm6, ymm0
	vpor    ymm4, ymm7, ymm4
	vpxor   ymm8, ymm8, ymm8
	vpxor   ymm9, ymm9, ymm9
	vpand   ymm7, ymm4, ymm1
	vpxor   ymm1, ymm4, ymm1
	vpand   ymm4, ymm5, ymm1
	vpxor   ymm1, ymm5, ymm1
	vpor    ymm4, ymm7, ymm4
	vpxor   ymm10, ymm10, ymm10
	vpxor   ymm11, ymm11, ymm11
	vpand   ymm7, ymm3, ymm2
	vpxor   ymm2, ymm3, ymm2
	vpand   ymm3, ymm4, ymm2
	vpxor   ymm2, ymm4, ymm2
	vpor    ymm3, ymm7, ymm3
	add     rsi, 480
	sub     rcx, 992
	jl      .L52

	mov     eax, 65535
.L50:	vmovdqa ymm4, [rsi]
	vmovdqa ymm5, [rsi+0x20]
	vmovdqa ymm6, [rsi+0x40]
	vmovdqa ymm12, [rsi+0x60]
	vmovdqa ymm14, [rsi+0x80]
	vpand   ymm7, ymm4, ymm0
	vpxor   ymm0, ymm4, ymm0
	vpand   ymm4, ymm5, ymm0
	vpxor   ymm0, ymm5, ymm0
	vpor    ymm4, ymm7, ymm4
	vmovdqa ymm5, [rsi+0xA0]
	vpand   ymm7, ymm12, ymm6
	vpxor   ymm6, ymm12, ymm6
	vpand   ymm12, ymm14, ymm6
	vpxor   ymm6, ymm14, ymm6
	vpor    ymm12, ymm7, ymm12
	vmovdqa ymm14, [rsi+0xC0]
	vpand   ymm7, ymm4, ymm1
	vpxor   ymm1, ymm4, ymm1
	vpand   ymm4, ymm12, ymm1
	vpxor   ymm1, ymm12, ymm1
	vpor    ymm4, ymm7, ymm4
	vmovdqa ymm12, [rsi+0xE0]
	vpand   ymm7, ymm5, ymm0
	vpxor   ymm0, ymm5, ymm0
	vpand   ymm5, ymm6, ymm0
	vpxor   ymm0, ymm6, ymm0
	vpor    ymm5, ymm7, ymm5
	vmovdqa ymm6, [rsi+0x100]
	vpand   ymm7, ymm12, ymm6
	vpxor   ymm6, ymm12, ymm6
	vpand   ymm12, ymm14, ymm6
	vpxor   ymm6, ymm14, ymm6
	vpor    ymm12, ymm7, ymm12
	vmovdqa ymm14, [rsi+0x120]
	vpand   ymm7, ymm5, ymm1
	vpxor   ymm1, ymm5, ymm1
	vpand   ymm5, ymm12, ymm1
	vpxor   ymm1, ymm12, ymm1
	vpor    ymm5, ymm7, ymm5
	vmovdqa ymm12, [rsi+0x140]
	vpand   ymm7, ymm12, ymm0
	vpxor   ymm0, ymm12, ymm0
	vpand   ymm12, ymm14, ymm0
	vpxor   ymm0, ymm14, ymm0
	vpor    ymm12, ymm7, ymm12
	vmovdqa ymm14, [rsi+0x160]
	vpand   ymm7, ymm4, ymm2
	vpxor   ymm2, ymm4, ymm2
	vpand   ymm4, ymm5, ymm2
	vpxor   ymm2, ymm5, ymm2
	vpor    ymm4, ymm7, ymm4
	vmovdqa ymm5, [rsi+0x180]
	vpand   ymm7, ymm6, ymm0
	vpxor   ymm0, ymm6, ymm0
	vpand   ymm6, ymm14, ymm0
	vpxor   ymm0, ymm14, ymm0
	vpor    ymm6, ymm7, ymm6
	vmovdqa ymm14, [rsi+0x1A0]
	vpand   ymm7, ymm6, ymm1
	vpxor   ymm1, ymm6, ymm1
	vpand   ymm6, ymm12, ymm1
	vpxor   ymm1, ymm12, ymm1
	vpor    ymm6, ymm7, ymm6
	vmovdqa ymm12, [rsi+0x1C0]
	vpand   ymm7, ymm12, ymm5
	vpxor   ymm5, ymm12, ymm5
	vpand   ymm12, ymm14, ymm5
	vpxor   ymm5, ymm14, ymm5
	vpor    ymm12, ymm7, ymm12
	vmovdqa ymm14, [rsi+0x1E0]
	vpand   ymm7, ymm5, ymm0
	vpxor   ymm0, ymm5, ymm0
	vpand   ymm5, ymm14, ymm0
	vpxor   ymm0, ymm14, ymm0
	vpor    ymm5, ymm7, ymm5
	add     rsi, 512
	prefetcht0 [rsi]
	prefetcht0 [rsi+0x20]
	vpand   ymm7, ymm5, ymm1
	vpxor   ymm1, ymm5, ymm1
	vpand   ymm5, ymm12, ymm1
	vpxor   ymm1, ymm12, ymm1
	vpor    ymm5, ymm7, ymm5
	vpand   ymm7, ymm5, ymm2
	vpxor   ymm2, ymm5, ymm2
	vpand   ymm5, ymm6, ymm2
	vpxor   ymm2, ymm6, ymm2
	vpor    ymm5, ymm7, ymm5
	vpand   ymm7, ymm4, ymm3
	vpxor   ymm3, ymm4, ymm3
	vpand   ymm4, ymm5, ymm3
	vpxor   ymm3, ymm5, ymm3
	vpor    ymm4, ymm7, ymm4
	vpbroadcastd ymm12, [magic+84+rip]
	vpbroadcastd ymm14, [magic+80+rip]
	vpand   ymm5, ymm15, ymm4
	vpandn  ymm6, ymm15, ymm4
	vpsrld  ymm6, ymm6, 1
	vperm2i128 ymm4, ymm5, ymm6, 0x20
	vperm2i128 ymm5, ymm5, ymm6, 0x31
	vpaddd  ymm4, ymm4, ymm5
	vpand   ymm5, ymm13, ymm4
	vpandn  ymm6, ymm13, ymm4
	vpsrld  ymm6, ymm6, 2
	vpunpcklqdq ymm4, ymm5, ymm6
	vpunpckhqdq ymm5, ymm5, ymm6
	vpaddd  ymm4, ymm4, ymm5
	vpand   ymm5, ymm14, ymm4
	vpandn  ymm6, ymm14, ymm4
	vpslld  ymm5, ymm5, 4
	vperm2i128 ymm4, ymm5, ymm6, 0x20
	vperm2i128 ymm5, ymm5, ymm6, 0x31
	vpunpcklwd ymm6, ymm4, ymm5
	vpunpckhwd ymm7, ymm4, ymm5
	vpunpckldq ymm4, ymm6, ymm7
	vpunpckhdq ymm5, ymm6, ymm7
	vpermq  ymm4, ymm4, 0xD8
	vpermq  ymm5, ymm5, 0xD8
	vpand   ymm6, ymm12, ymm4
	vpand   ymm7, ymm12, ymm5
	vpaddw  ymm8, ymm8, ymm6
	vpaddw  ymm10, ymm10, ymm7
	vpsrlw  ymm4, ymm4, 8
	vpsrlw  ymm5, ymm5, 8
	vpaddw  ymm9, ymm9, ymm4
	vpaddw  ymm11, ymm11, ymm5
	sub     eax, 64
	cmp     eax, 120
	jge     .L51

	vpxor   ymm7, ymm7, ymm7
	call    rbx
	vpxor   ymm8, ymm8, ymm8
	vpxor   ymm9, ymm9, ymm9
	vpxor   ymm10, ymm10, ymm10
	vpxor   ymm11, ymm11, ymm11
	mov     eax, 65535
.L51:	sub     rcx, 512
	jge     .L50

.L52:	vpbroadcastd ymm14, [magic+80+rip]
	vpand   ymm5, ymm15, ymm1
	vpaddd  ymm5, ymm5, ymm5
	vpand   ymm7, ymm15, ymm3
	vpaddd  ymm7, ymm7, ymm7
	vpand   ymm4, ymm15, ymm0
	vpand   ymm6, ymm15, ymm2
	vpor    ymm4, ymm5, ymm4
	vpor    ymm5, ymm7, ymm6
	vpandn  ymm0, ymm15, ymm0
	vpsrld  ymm0, ymm0, 1
	vpandn  ymm2, ymm15, ymm2
	vpsrld  ymm2, ymm2, 1
	vpandn  ymm1, ymm15, ymm1
	vpandn  ymm3, ymm15, ymm3
	vpor    ymm6, ymm1, ymm0
	vpor    ymm7, ymm3, ymm2
	vpand   ymm1, ymm13, ymm5
	vpslld  ymm1, ymm1, 2
	vpand   ymm3, ymm13, ymm7
	vpslld  ymm3, ymm3, 2
	vpand   ymm0, ymm13, ymm4
	vpand   ymm2, ymm13, ymm6
	vpor    ymm0, ymm1, ymm0
	vpor    ymm1, ymm3, ymm2
	vpandn  ymm4, ymm13, ymm4
	vpsrld  ymm4, ymm4, 2
	vpandn  ymm6, ymm13, ymm6
	vpsrld  ymm6, ymm6, 2
	vpandn  ymm5, ymm13, ymm5
	vpandn  ymm7, ymm13, ymm7
	vpor    ymm2, ymm5, ymm4
	vpor    ymm3, ymm7, ymm6
	vpunpcklbw ymm5, ymm0, ymm1
	vpunpckhbw ymm0, ymm0, ymm1
	vpunpcklbw ymm6, ymm2, ymm3
	vpunpckhbw ymm1, ymm2, ymm3
	vpunpcklwd ymm4, ymm5, ymm6
	vpunpckhwd ymm5, ymm5, ymm6
	vpunpcklwd ymm6, ymm0, ymm1
	vpunpckhwd ymm7, ymm0, ymm1
	vpand   ymm0, ymm14, ymm4
	vpsrld  ymm4, ymm4, 4
	vpand   ymm4, ymm14, ymm4
	vpand   ymm1, ymm14, ymm5
	vpsrld  ymm5, ymm5, 4
	vpand   ymm5, ymm14, ymm5
	vpand   ymm2, ymm14, ymm6
	vpsrld  ymm6, ymm6, 4
	vpand   ymm6, ymm14, ymm6
	vpand   ymm3, ymm14, ymm7
	vpsrld  ymm7, ymm7, 4
	vpand   ymm7, ymm14, ymm7
	vpaddb  ymm0, ymm0, ymm2
	vpaddb  ymm1, ymm1, ymm3
	vpaddb  ymm2, ymm4, ymm6
	vpaddb  ymm3, ymm5, ymm7
	vpunpckldq ymm4, ymm0, ymm2
	vpunpckhdq ymm5, ymm0, ymm2
	vpunpckldq ymm6, ymm1, ymm3
	vpunpckhdq ymm7, ymm1, ymm3
	vperm2i128 ymm0, ymm4, ymm5, 0x20
	vperm2i128 ymm2, ymm4, ymm5, 0x31
	vperm2i128 ymm1, ymm6, ymm7, 0x20
	vperm2i128 ymm3, ymm6, ymm7, 0x31
	vpaddb  ymm0, ymm0, ymm2
	vpaddb  ymm1, ymm1, ymm3
	vpxor   ymm7, ymm7, ymm7
	vpunpcklbw ymm4, ymm0, ymm7
	vpunpckhbw ymm5, ymm0, ymm7
	vpunpcklbw ymm6, ymm1, ymm7
	vpunpckhbw ymm1, ymm1, ymm7
	vpaddw  ymm8, ymm8, ymm4
	vpaddw  ymm9, ymm9, ymm5
	vpaddw  ymm10, ymm10, ymm6
	vpaddw  ymm11, ymm11, ymm1
	cmp     ecx, -512
	je      .L55

	vpbroadcastq ymm2, [magic+64+rip]
	vmovdqu ymm3, [magic+rip]
	vmovdqu ymm7, [magic+32+rip]
	vpxor   ymm0, ymm0, ymm0
	vpxor   ymm1, ymm1, ymm1
	sub     ecx, -504
	jle     .L54

.L53:	vpbroadcastq ymm4, [rsi]
	vpshufb ymm5, ymm4, ymm7
	vpshufb ymm4, ymm4, ymm3
	vpand   ymm5, ymm5, ymm2
	vpand   ymm4, ymm4, ymm2
	vpcmpeqb ymm5, ymm5, ymm2
	vpcmpeqb ymm4, ymm4, ymm2
	vpsubb  ymm1, ymm1, ymm5
	vpsubb  ymm0, ymm0, ymm4
	add     rsi, 8
	sub     ecx, 8
	jg      .L53

.L54:	lea     ecx, [rcx*8+0x40]
	bzhi    rax, [rsi], rcx
	vmovq   xmm6, rax
	vpbroadcastq ymm4, xmm6
	vpshufb ymm5, ymm4, ymm7
	vpshufb ymm4, ymm4, ymm3
	vpand   ymm5, ymm5, ymm2
	vpand   ymm4, ymm4, ymm2
	vpcmpeqb ymm5, ymm5, ymm2
	vpcmpeqb ymm4, ymm4, ymm2
	vpsubb  ymm1, ymm1, ymm5
	vpsubb  ymm0, ymm0, ymm4
	vpxor   ymm7, ymm7, ymm7
	vpunpcklbw ymm4, ymm0, ymm7
	vpunpckhbw ymm5, ymm0, ymm7
	vpunpcklbw ymm6, ymm1, ymm7
	vpunpckhbw ymm7, ymm1, ymm7
	vpaddw  ymm8, ymm8, ymm4
	vpaddw  ymm9, ymm9, ymm5
	vpaddw  ymm10, ymm10, ymm6
	vpaddw  ymm11, ymm11, ymm7

.L55:	vpxor   ymm7, ymm7, ymm7
	call    rbx
	vzeroupper
	pop     rbp
	ret

.L56:	vpbroadcastq ymm2, [magic+64+rip]
	vmovdqu ymm3, [magic+rip]
	vmovdqu ymm7, [magic+32+rip]
	vpxor   ymm0, ymm0, ymm0
	vpxor   ymm1, ymm1, ymm1
	sub     ecx, 8
	jl      .L58

.L57:	vpbroadcastq ymm4, [rsi]
	vpshufb ymm5, ymm4, ymm7
	vpshufb ymm4, ymm4, ymm3
	vpand   ymm5, ymm5, ymm2
	vpand   ymm4, ymm4, ymm2
	vpcmpeqb ymm5, ymm5, ymm2
	vpcmpeqb ymm4, ymm4, ymm2
	vpsubb  ymm1, ymm1, ymm5
	vpsubb  ymm0, ymm0, ymm4
	add     rsi, 8
	sub     ecx, 8
	jge     .L57

.L58:	cmp     ecx, -8
	jle     .L61

	lea     edx, [rsi+rcx+0x7]
	xor     edx, esi
	lea     ecx, [rcx*8+0x40]
	test    edx, 0x8
	jnz     .L59

	lea     eax, [rsi*8]
	and     rsi, 0xFFFFFFFFFFFFFFF8
	mov     r8, [rsi]
	shrx    r8, r8, rax
	bzhi    r8, r8, rcx
	jmp     .L60

.L59:	bzhi    r8, [rsi], rcx

.L60:	vmovq   xmm6, r8
	vpbroadcastq ymm4, xmm6
	vpshufb ymm5, ymm4, ymm7
	vpshufb ymm4, ymm4, ymm3
	vpand   ymm5, ymm5, ymm2
	vpand   ymm4, ymm4, ymm2
	vpcmpeqb ymm5, ymm5, ymm2
	vpcmpeqb ymm4, ymm4, ymm2
	vpsubb  ymm1, ymm1, ymm5
	vpsubb  ymm0, ymm0, ymm4

.L61:	vpxor   ymm7, ymm7, ymm7
	vpunpcklbw ymm8, ymm0, ymm7
	vpunpckhbw ymm9, ymm0, ymm7
	vpunpcklbw ymm10, ymm1, ymm7
	vpunpckhbw ymm11, ymm1, ymm7
	call    rbx
	vzeroupper
	pop     rbp
	ret
	.size	countavx2, .-countavx2

	.balign 16
	.globl count8avx2
	.type   count8avx2, @function
count8avx2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum8+rip]
	call    countavx2
	pop	rbx
	pop	rbp
	ret
	.size   count8avx2, .-count8avx2

	.balign 16
	.globl count16avx2
	.type   count16avx2, @function
count16avx2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum16+rip]
	shl     rcx, 1
	call    countavx2
	pop	rbx
	pop	rbp
	ret
	.size   count16avx2, .-count16avx2

	.balign 16
	.globl count32avx2
	.type   count32avx2, @function
count32avx2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum32+rip]
	shl	rcx, 2
	call    countavx2
	pop	rbx
	pop	rbp
	ret
	.size   count32avx2, .-count32avx2

	.balign 16
	.globl count64avx2
	.type   count64avx2, @function
count64avx2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea     rbx, [accum64+rip]
	shl	rcx, 3
	call    countavx2
	pop	rbx
	pop	rbp
	ret
	.size   count64avx2, .-count64avx2

	.section .note.GNU-stack,"",%progbits
