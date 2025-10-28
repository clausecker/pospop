	.intel_syntax noprefix

	.section .rodata
	.balign	16
magic:	.quad	0x8040201008040201
	.int	0x55555555
	.int	0xaaaaaaaa
	.int	0x33333333
	.int	0xcccccccc
	.int	0x0f0f0f0f
	.int	0x00ff00ff
	.size	magic, .-magic

window:	.quad	0, 0, -1, -1
	.size	window, .-window

	.section .text
	.type   countsse2, @function
	.balign 16
countsse2:
	push    rbp
	mov     rbp, rsp
	sub     rsp, 32
	movq    xmm6, [magic+rip]
	pshufd  xmm6, xmm6, 0x44
	pxor    xmm7, xmm7
	pxor    xmm8, xmm8
	pxor    xmm10, xmm10
	pxor    xmm12, xmm12
	pxor    xmm14, xmm14
	cmp     rcx, 240
	jl      .L62

	mov     edx, esi
	and     edx, 0x0F
	mov     eax, 16
	sub     eax, edx
	sub     rsi, rdx
	add     rcx, rdx
	lea     rdx, [window+rip]
	movdqu  xmm2, [rdx+rax]
	pand    xmm2, [rsi]
	movdqa  xmm1, [rsi+0x10]
	movdqa  xmm0, [rsi+0x20]
	movdqa  xmm5, [rsi+0x30]
	movdqa  xmm4, [rsi+0x40]
	movdqa  xmm3, [rsi+0x50]
	pxor    xmm1, xmm2
	pxor    xmm2, xmm0
	pxor    xmm0, xmm1
	por     xmm1, xmm2
	pxor    xmm1, xmm0
	movdqa  xmm7, [rsi+0x60]
	movdqa  xmm6, [rsi+0x70]
	movdqa  xmm2, [rsi+0x80]
	pxor    xmm4, xmm5
	pxor    xmm5, xmm3
	pxor    xmm3, xmm4
	por     xmm4, xmm5
	pxor    xmm4, xmm3
	movdqa  xmm5, [rsi+0x90]
	pxor    xmm6, xmm7
	pxor    xmm7, xmm2
	pxor    xmm2, xmm6
	por     xmm6, xmm7
	pxor    xmm6, xmm2
	movdqa  xmm7, [rsi+0xA0]
	pxor    xmm5, xmm3
	pxor    xmm3, xmm0
	pxor    xmm0, xmm5
	por     xmm5, xmm3
	pxor    xmm5, xmm0
	movdqa  xmm3, [rsi+0xB0]
	pxor    xmm4, xmm6
	pxor    xmm6, xmm1
	pxor    xmm1, xmm4
	por     xmm4, xmm6
	pxor    xmm4, xmm1
	movdqa  xmm6, [rsi+0xC0]
	pxor    xmm2, xmm7
	pxor    xmm7, xmm0
	pxor    xmm0, xmm2
	por     xmm2, xmm7
	pxor    xmm2, xmm0
	movdqa  xmm7, [rsi+0xD0]
	pxor    xmm9, xmm9
	pxor    xmm11, xmm11
	pxor    xmm7, xmm6
	pxor    xmm6, xmm3
	pxor    xmm3, xmm7
	por     xmm7, xmm6
	pxor    xmm7, xmm3
	movdqa  xmm6, [rsi+0xE0]
	pxor    xmm2, xmm5
	pxor    xmm5, xmm1
	pxor    xmm1, xmm2
	por     xmm2, xmm5
	pxor    xmm2, xmm1
	add     rsi, 240
	pxor    xmm3, xmm6
	pxor    xmm6, xmm0
	pxor    xmm0, xmm3
	por     xmm3, xmm6
	pxor    xmm3, xmm0
	mov     eax, 65535
	pxor    xmm3, xmm7
	pxor    xmm7, xmm1
	pxor    xmm1, xmm3
	por     xmm3, xmm7
	pxor    xmm3, xmm1
	pxor    xmm13, xmm13
	pxor    xmm15, xmm15
	pxor    xmm3, xmm4
	pxor    xmm4, xmm2
	pxor    xmm2, xmm3
	por     xmm3, xmm4
	pxor    xmm3, xmm2
	sub     rcx, 496
	jl      .L58

.L56:	movdqa  xmm4, [rsi]
	movdqa  xmm5, [rsi+0x10]
	movdqu  [rsp], xmm8
	movdqu  [rsp+0x10], xmm9
	movdqa  xmm6, [rsi+0x20]
	movdqa  xmm7, [rsi+0x30]
	movdqa  xmm8, [rsi+0x40]
	movdqa  xmm9, [rsi+0x50]
	pxor    xmm5, xmm4
	pxor    xmm4, xmm0
	pxor    xmm0, xmm5
	por     xmm5, xmm4
	pxor    xmm5, xmm0
	movdqa  xmm4, [rsi+0x60]
	pxor    xmm8, xmm7
	pxor    xmm7, xmm6
	pxor    xmm6, xmm8
	por     xmm8, xmm7
	pxor    xmm8, xmm6
	movdqa  xmm7, [rsi+0x70]
	pxor    xmm8, xmm5
	pxor    xmm5, xmm1
	pxor    xmm1, xmm8
	por     xmm8, xmm5
	pxor    xmm8, xmm1
	movdqa  xmm5, [rsi+0x80]
	pxor    xmm6, xmm9
	pxor    xmm9, xmm0
	pxor    xmm0, xmm6
	por     xmm6, xmm9
	pxor    xmm6, xmm0
	movdqa  xmm9, [rsi+0x90]
	pxor    xmm5, xmm7
	pxor    xmm7, xmm4
	pxor    xmm4, xmm5
	por     xmm5, xmm7
	pxor    xmm5, xmm4
	movdqa  xmm7, [rsi+0xA0]
	pxor    xmm5, xmm6
	pxor    xmm6, xmm1
	pxor    xmm1, xmm5
	por     xmm5, xmm6
	pxor    xmm5, xmm1
	movdqa  xmm6, [rsi+0xB0]
	pxor    xmm4, xmm9
	pxor    xmm9, xmm0
	pxor    xmm0, xmm4
	por     xmm4, xmm9
	pxor    xmm4, xmm0
	movdqa  xmm9, [rsi+0xC0]
	pxor    xmm5, xmm8
	pxor    xmm8, xmm2
	pxor    xmm2, xmm5
	por     xmm5, xmm8
	pxor    xmm5, xmm2
	movdqa  xmm8, [rsi+0xD0]
	pxor    xmm6, xmm7
	pxor    xmm7, xmm0
	pxor    xmm0, xmm6
	por     xmm6, xmm7
	pxor    xmm6, xmm0
	movdqa  xmm7, [rsi+0xE0]
	pxor    xmm4, xmm6
	pxor    xmm6, xmm1
	pxor    xmm1, xmm4
	por     xmm4, xmm6
	pxor    xmm4, xmm1
	movdqa  xmm6, [rsi+0xF0]
	pxor    xmm8, xmm9
	pxor    xmm9, xmm7
	pxor    xmm7, xmm8
	por     xmm8, xmm9
	pxor    xmm8, xmm7
	movdqu  xmm9, [magic+8+rip]
	pxor    xmm6, xmm7
	pxor    xmm7, xmm0
	pxor    xmm0, xmm6
	por     xmm6, xmm7
	pxor    xmm6, xmm0
	add     rsi, 256
	prefetcht0 [rsi+0x5A0]
	pxor    xmm6, xmm8
	pxor    xmm8, xmm1
	pxor    xmm1, xmm6
	por     xmm6, xmm8
	pxor    xmm6, xmm1
	prefetcht0 [rsi+0x5E0]
	pxor    xmm4, xmm6
	pxor    xmm6, xmm2
	pxor    xmm2, xmm4
	por     xmm4, xmm6
	pxor    xmm4, xmm2
	prefetcht0 [rsi+0x620]
	pxor    xmm4, xmm5
	pxor    xmm5, xmm3
	pxor    xmm3, xmm4
	por     xmm4, xmm5
	pxor    xmm4, xmm3
	prefetcht0 [rsi+0x660]
	movq    xmm8, [magic+24+rip]
	pshufd  xmm7, xmm9, 0x00
	movdqa  xmm5, xmm4
	pand    xmm5, xmm7
	pandn   xmm7, xmm4
	psrld   xmm7, 1
	movdqa  xmm4, xmm5
	punpcklqdq xmm4, xmm7
	punpckhqdq xmm5, xmm7
	paddd   xmm4, xmm5
	pshufd  xmm5, xmm9, 0xAA
	movdqa  xmm7, xmm5
	pandn   xmm5, xmm4
	pand    xmm4, xmm7
	psrld   xmm5, 2
	pshufd  xmm6, xmm8, 0x00
	movdqa  xmm7, xmm6
	pandn   xmm6, xmm4
	pand    xmm4, xmm7
	movdqa  xmm9, xmm7
	pandn   xmm7, xmm5
	pand    xmm5, xmm9
	pslld   xmm4, 4
	pslld   xmm5, 4
	movdqa  xmm9, xmm4
	punpcklwd xmm4, xmm5
	punpckhwd xmm9, xmm5
	movdqa  xmm5, xmm6
	punpcklwd xmm5, xmm7
	punpckhwd xmm6, xmm7
	movdqa  xmm7, xmm4
	punpcklwd xmm4, xmm9
	punpckhwd xmm7, xmm9
	movdqa  xmm9, xmm5
	punpcklwd xmm5, xmm6
	punpckhwd xmm9, xmm6
	movdqa  xmm6, xmm4
	punpcklqdq xmm4, xmm5
	punpckhqdq xmm6, xmm5
	movdqa  xmm5, xmm7
	punpcklqdq xmm5, xmm9
	punpckhqdq xmm7, xmm9
	pshufd  xmm8, xmm8, 0x55
	movdqa  xmm9, xmm6
	pand    xmm6, xmm8
	psrlw   xmm9, 8
	paddw   xmm10, xmm6
	paddw   xmm11, xmm9
	movdqa  xmm6, xmm8
	movdqu  xmm8, [rsp]
	movdqa  xmm9, xmm5
	pand    xmm5, xmm6
	psrlw   xmm9, 8
	paddw   xmm12, xmm5
	paddw   xmm13, xmm9
	movdqu  xmm9, [rsp+0x10]
	movdqa  xmm5, xmm7
	pand    xmm7, xmm6
	psrlw   xmm5, 8
	paddw   xmm14, xmm7
	paddw   xmm15, xmm5
	movdqa  xmm5, xmm4
	pand    xmm4, xmm6
	psrlw   xmm5, 8
	paddw   xmm8, xmm4
	paddw   xmm9, xmm5
	sub     eax, 32
	cmp     eax, 60
	jge     .L57

	pxor    xmm7, xmm7
	call    rbx
	pxor    xmm8, xmm8
	pxor    xmm9, xmm9
	pxor    xmm10, xmm10
	pxor    xmm11, xmm11
	pxor    xmm12, xmm12
	pxor    xmm13, xmm13
	pxor    xmm14, xmm14
	pxor    xmm15, xmm15
	mov     eax, 65535

.L57:	sub     rcx, 256
	jge     .L56

.L58:	movq    xmm5, [magic+8+rip]
	pshufd  xmm6, xmm5, 0x55
	pshufd  xmm7, xmm5, 0x00
	movdqa  xmm5, xmm0
	pand    xmm5, xmm6
	psrld   xmm5, 1
	movdqa  xmm4, xmm1
	pand    xmm4, xmm7
	paddd   xmm4, xmm4
	pand    xmm0, xmm7
	pand    xmm1, xmm6
	por     xmm0, xmm4
	por     xmm1, xmm5
	movdqa  xmm5, xmm2
	pand    xmm5, xmm6
	psrld   xmm5, 1
	movdqa  xmm4, xmm3
	pand    xmm4, xmm7
	paddd   xmm4, xmm4
	pand    xmm2, xmm7
	pand    xmm3, xmm6
	por     xmm2, xmm4
	por     xmm3, xmm5
	movq    xmm7, [magic+16+rip]
	pshufd  xmm6, xmm7, 0x55
	pshufd  xmm7, xmm7, 0x00
	movdqa  xmm5, xmm0
	pand    xmm5, xmm6
	psrld   xmm5, 2
	movdqa  xmm4, xmm2
	pand    xmm4, xmm7
	pslld   xmm4, 2
	pand    xmm0, xmm7
	pand    xmm2, xmm6
	por     xmm0, xmm4
	por     xmm2, xmm5
	movdqa  xmm5, xmm1
	pand    xmm5, xmm6
	psrld   xmm5, 2
	movdqa  xmm4, xmm3
	pand    xmm4, xmm7
	pslld   xmm4, 2
	pand    xmm1, xmm7
	pand    xmm3, xmm6
	por     xmm1, xmm4
	por     xmm3, xmm5
	movq    xmm7, [magic+24+rip]
	pshufd  xmm7, xmm7, 0x00
	movdqa  xmm5, xmm2
	punpcklbw xmm2, xmm3
	punpckhbw xmm5, xmm3
	movdqa  xmm3, xmm0
	punpcklbw xmm0, xmm1
	punpckhbw xmm3, xmm1
	movdqa  xmm1, xmm0
	punpcklwd xmm0, xmm2
	punpckhwd xmm1, xmm2
	movdqa  xmm2, xmm3
	punpcklwd xmm2, xmm5
	punpckhwd xmm3, xmm5
	movdqa  xmm4, xmm0
	psrld   xmm4, 4
	pand    xmm0, xmm7
	pand    xmm4, xmm7
	movdqa  xmm6, xmm2
	psrld   xmm2, 4
	pand    xmm6, xmm7
	pand    xmm2, xmm7
	paddb   xmm0, xmm6
	paddb   xmm2, xmm4
	movdqa  xmm4, xmm1
	psrld   xmm4, 4
	pand    xmm1, xmm7
	pand    xmm4, xmm7
	movdqa  xmm6, xmm3
	psrld   xmm3, 4
	pand    xmm6, xmm7
	pand    xmm3, xmm7
	paddb   xmm1, xmm6
	paddb   xmm3, xmm4
	movdqa  xmm4, xmm0
	punpckldq xmm0, xmm2
	punpckhdq xmm4, xmm2
	movdqa  xmm5, xmm1
	punpckldq xmm1, xmm3
	punpckhdq xmm5, xmm3
	pxor    xmm7, xmm7
	movdqa  xmm6, xmm0
	punpcklbw xmm0, xmm7
	punpckhbw xmm6, xmm7
	paddw   xmm8, xmm0
	paddw   xmm9, xmm6
	movdqa  xmm6, xmm4
	punpcklbw xmm4, xmm7
	punpckhbw xmm6, xmm7
	paddw   xmm10, xmm4
	paddw   xmm11, xmm6
	movdqa  xmm6, xmm1
	punpcklbw xmm1, xmm7
	punpckhbw xmm6, xmm7
	paddw   xmm12, xmm1
	paddw   xmm13, xmm6
	movdqa  xmm6, xmm5
	punpcklbw xmm5, xmm7
	punpckhbw xmm6, xmm7
	paddw   xmm14, xmm5
	paddw   xmm15, xmm6
	movq    xmm6, [magic+rip]
	pshufd  xmm6, xmm6, 0x44
	pxor    xmm0, xmm0
	pxor    xmm1, xmm1
	pxor    xmm2, xmm2
	pxor    xmm3, xmm3
	sub     ecx, -248
	jl      .L60

.L59:	movd    xmm4, [rsi]
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm0, xmm4
	psubb   xmm1, xmm5
	movd    xmm4, [rsi+0x4]
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm2, xmm4
	psubb   xmm3, xmm5
	add     rsi, 8
	sub     ecx, 8
	jge     .L59

.L60:	sub     ecx, -8
	jle     .L61

	movq    xmm5, [rsi]
	lea     rax, [window+16+rip]
	sub     rax, rcx
	movq    xmm7, [rax]
	pandn   xmm7, xmm5
	movdqa  xmm4, xmm7
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm0, xmm4
	psubb   xmm1, xmm5
	psrldq  xmm7, 4
	movdqa  xmm4, xmm7
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm2, xmm4
	psubb   xmm3, xmm5
.L61:	pxor    xmm7, xmm7
	movdqa  xmm4, xmm0
	punpcklbw xmm0, xmm7
	punpckhbw xmm4, xmm7
	paddw   xmm8, xmm0
	paddw   xmm9, xmm4
	movdqa  xmm4, xmm1
	punpcklbw xmm1, xmm7
	punpckhbw xmm4, xmm7
	paddw   xmm10, xmm1
	paddw   xmm11, xmm4
	movdqa  xmm4, xmm2
	punpcklbw xmm2, xmm7
	punpckhbw xmm4, xmm7
	paddw   xmm12, xmm2
	paddw   xmm13, xmm4
	movdqa  xmm4, xmm3
	punpcklbw xmm3, xmm7
	punpckhbw xmm4, xmm7
	paddw   xmm14, xmm3
	paddw   xmm15, xmm4
	call    rbx
	add     rsp, 32
	pop     rbp
	ret

.L62:	sub     ecx, 8
	jl      .L64

.L63:	movd    xmm4, [rsi]
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm8, xmm4
	psubb   xmm10, xmm5
	movd    xmm4, [rsi+0x4]
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm12, xmm4
	psubb   xmm14, xmm5
	add     rsi, 8
	sub     ecx, 8
	jge     .L63

.L64:	add     ecx, 8
	jle     .L67

	mov     eax, esi
	and     eax, 0x07
	lea     edx, [rax+rcx]
	shl     ecx, 3
	xor     r9, r9
	bts     r9, rcx
	dec     r9
	cmp     edx, 8
	jg      .L65

	and     rsi, 0xFFFFFFFFFFFFFFF8
	mov     r8, [rsi]
	lea     ecx, [rax*8]
	shr     r8, cl
	jmp     .L66

.L65:	mov     r8, [rsi]

.L66:	and     r8, r9
	movd    xmm4, r8d
	shr     r8, 32
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm8, xmm4
	psubb   xmm10, xmm5
	movd    xmm4, r8d
	punpcklbw xmm4, xmm4
	punpcklwd xmm4, xmm4
	pshufd  xmm5, xmm4, 0xFA
	punpckldq xmm4, xmm4
	pand    xmm4, xmm6
	pand    xmm5, xmm6
	pcmpeqb xmm4, xmm6
	pcmpeqb xmm5, xmm6
	psubb   xmm12, xmm4
	psubb   xmm14, xmm5

.L67:	movdqa  xmm9, xmm8
	punpcklbw xmm8, xmm7
	punpckhbw xmm9, xmm7
	movdqa  xmm11, xmm10
	punpcklbw xmm10, xmm7
	punpckhbw xmm11, xmm7
	movdqa  xmm13, xmm12
	punpcklbw xmm12, xmm7
	punpckhbw xmm13, xmm7
	movdqa  xmm15, xmm14
	punpcklbw xmm14, xmm7
	punpckhbw xmm15, xmm7
	call    rbx
	add     rsp, 32
	pop     rbp
	ret
	.size	countsse2, .-countsse2

	.balign	16
	.globl	count8sse2
	.type	count8sse2, @function
count8sse2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea	rbx, [accum8+rip]
	call    countsse2
	pop	rbx
	pop     rbp
	ret
	.size	count8sse2, .-count8sse2

	.balign	16
	.globl	count16sse2
	.type	count16sse2, @function
count16sse2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea	rbx, [accum16+rip]
	shl	rcx, 1
	call    countsse2
	pop	rbx
	pop     rbp
	ret
	.size	count16sse2, .-count16sse2

	.balign	16
	.globl	count32sse2
	.type	count32sse2, @function
count32sse2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea	rbx, [accum32+rip]
	shl	rcx, 2
	call    countsse2
	pop	rbx
	pop     rbp
	ret
	.size	count32sse2, .-count32sse2

	.balign	16
	.globl	count64sse2
	.type	count64sse2, @function
count64sse2:
	push	rbp
	mov	rbp, rsp
	push	rbx
	mov	rcx, rdx
	lea	rbx, [accum64+rip]
	shl	rcx, 3
	call    countsse2
	pop	rbx
	pop     rbp
	ret
	.size	count64sse2, .-count64sse2
