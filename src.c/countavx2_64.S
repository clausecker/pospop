#ifdef __amd64__
#include "kernelavx2.S"

	.text
	.type   accum8, @function
	.balign	16
accum8:	vpunpcklwd ymm12, ymm8, ymm7
	vpunpckhwd ymm8, ymm8, ymm7
	vpunpcklwd ymm14, ymm9, ymm7
	vpunpckhwd ymm9, ymm9, ymm7
	vpunpcklwd ymm4, ymm10, ymm7
	vpunpckhwd ymm10, ymm10, ymm7
	vpunpcklwd ymm5, ymm11, ymm7
	vpunpckhwd ymm11, ymm11, ymm7
	vpaddd  ymm12, ymm4, ymm12
	vpaddd  ymm8, ymm10, ymm8
	vpaddd  ymm14, ymm5, ymm14
	vpaddd  ymm9, ymm11, ymm9
	vpaddd  ymm12, ymm12, ymm14
	vpaddd  ymm8, ymm8, ymm9
	vperm2i128 ymm14, ymm12, ymm8, 0x20
	vperm2i128 ymm4, ymm12, ymm8, 0x31
	vpaddd  ymm12, ymm14, ymm4
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm14, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi]
	vpaddq  ymm14, ymm14, [rdi+0x20]
	vmovdqu [rdi], ymm12
	vmovdqu [rdi+0x20], ymm14
	ret
	.size	accum8, .-accum8

	.type   accum16, @function
	.balign	16
accum16:
	vpunpcklwd ymm12, ymm8, ymm7
	vpunpckhwd ymm8, ymm8, ymm7
	vpunpcklwd ymm14, ymm9, ymm7
	vpunpckhwd ymm9, ymm9, ymm7
	vpunpcklwd ymm4, ymm10, ymm7
	vpunpckhwd ymm10, ymm10, ymm7
	vpunpcklwd ymm5, ymm11, ymm7
	vpunpckhwd ymm11, ymm11, ymm7
	vpaddd  ymm12, ymm4, ymm12
	vpaddd  ymm8, ymm10, ymm8
	vpaddd  ymm14, ymm5, ymm14
	vpaddd  ymm9, ymm11, ymm9
	vperm2i128 ymm4, ymm12, ymm8, 0x20
	vperm2i128 ymm10, ymm12, ymm8, 0x31
	vpaddd  ymm12, ymm10, ymm4
	vperm2i128 ymm5, ymm14, ymm9, 0x20
	vperm2i128 ymm11, ymm14, ymm9, 0x31
	vpaddd  ymm4, ymm11, ymm5
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm14, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi]
	vpaddq  ymm14, ymm14, [rdi+0x20]
	vmovdqu [rdi], ymm12
	vmovdqu [rdi+0x20], ymm14
	vpermq  ymm4, ymm4, 0xD8
	vpunpckhdq ymm5, ymm4, ymm7
	vpunpckldq ymm4, ymm4, ymm7
	vpaddq  ymm4, ymm4, [rdi+0x40]
	vpaddq  ymm5, ymm5, [rdi+0x60]
	vmovdqu [rdi+0x40], ymm4
	vmovdqu [rdi+0x60], ymm5
	ret
	.size accum16, .-accum16

	.type   accum32, @function
	.balign	16
accum32:
	vpunpcklwd ymm12, ymm8, ymm7
	vpunpckhwd ymm8, ymm8, ymm7
	vpunpcklwd ymm14, ymm9, ymm7
	vpunpckhwd ymm9, ymm9, ymm7
	vpunpcklwd ymm4, ymm10, ymm7
	vpunpckhwd ymm10, ymm10, ymm7
	vpunpcklwd ymm5, ymm11, ymm7
	vpunpckhwd ymm11, ymm11, ymm7
	vpaddd  ymm12, ymm4, ymm12
	vpaddd  ymm8, ymm10, ymm8
	vpaddd  ymm14, ymm5, ymm14
	vpaddd  ymm9, ymm11, ymm9
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm4, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi]
	vpaddq  ymm4, ymm4, [rdi+0x80]
	vmovdqu [rdi], ymm12
	vmovdqu [rdi+0x80], ymm4
	vpermq  ymm8, ymm8, 0xD8
	vpunpckhdq ymm4, ymm8, ymm7
	vpunpckldq ymm8, ymm8, ymm7
	vpaddq  ymm8, ymm8, [rdi+0x20]
	vpaddq  ymm4, ymm4, [rdi+0xA0]
	vmovdqu [rdi+0x20], ymm8
	vmovdqu [rdi+0xA0], ymm4
	vpermq  ymm14, ymm14, 0xD8
	vpunpckhdq ymm4, ymm14, ymm7
	vpunpckldq ymm14, ymm14, ymm7
	vpaddq  ymm14, ymm14, [rdi+0x40]
	vpaddq  ymm4, ymm4, [rdi+0xC0]
	vmovdqu [rdi+0x40], ymm14
	vmovdqu [rdi+0xC0], ymm4
	vpermq  ymm9, ymm9, 0xD8
	vpunpckhdq ymm4, ymm9, ymm7
	vpunpckldq ymm9, ymm9, ymm7
	vpaddq  ymm9, ymm9, [rdi+0x60]
	vpaddq  ymm4, ymm4, [rdi+0xE0]
	vmovdqu [rdi+0x60], ymm9
	vmovdqu [rdi+0xE0], ymm4
	ret
	.size accum32, .-accum32

	.type   accum64, @function
	.balign	16
accum64:
	vpunpcklwd ymm12, ymm8, ymm7
	vpunpckhwd ymm14, ymm8, ymm7
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm4, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi]
	vpaddq  ymm4, ymm4, [rdi+0x80]
	vmovdqu [rdi], ymm12
	vmovdqu [rdi+0x80], ymm4
	vpermq  ymm14, ymm14, 0xD8
	vpunpckhdq ymm4, ymm14, ymm7
	vpunpckldq ymm14, ymm14, ymm7
	vpaddq  ymm14, ymm14, [rdi+0x20]
	vpaddq  ymm4, ymm4, [rdi+0xA0]
	vmovdqu [rdi+0x20], ymm14
	vmovdqu [rdi+0xA0], ymm4
	vpunpcklwd ymm12, ymm9, ymm7
	vpunpckhwd ymm14, ymm9, ymm7
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm4, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi+0x40]
	vpaddq  ymm4, ymm4, [rdi+0xC0]
	vmovdqu [rdi+0x40], ymm12
	vmovdqu [rdi+0xC0], ymm4
	vpermq  ymm14, ymm14, 0xD8
	vpunpckhdq ymm4, ymm14, ymm7
	vpunpckldq ymm14, ymm14, ymm7
	vpaddq  ymm14, ymm14, [rdi+0x60]
	vpaddq  ymm4, ymm4, [rdi+0xE0]
	vmovdqu [rdi+0x60], ymm14
	vmovdqu [rdi+0xE0], ymm4
	vpunpcklwd ymm12, ymm10, ymm7
	vpunpckhwd ymm14, ymm10, ymm7
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm4, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi+0x100]
	vpaddq  ymm4, ymm4, [rdi+0x180]
	vmovdqu [rdi+0x100], ymm12
	vmovdqu [rdi+0x180], ymm4
	vpermq  ymm14, ymm14, 0xD8
	vpunpckhdq ymm4, ymm14, ymm7
	vpunpckldq ymm14, ymm14, ymm7
	vpaddq  ymm14, ymm14, [rdi+0x120]
	vpaddq  ymm4, ymm4, [rdi+0x1A0]
	vmovdqu [rdi+0x120], ymm14
	vmovdqu [rdi+0x1A0], ymm4
	vpunpcklwd ymm12, ymm11, ymm7
	vpunpckhwd ymm14, ymm11, ymm7
	vpermq  ymm12, ymm12, 0xD8
	vpunpckhdq ymm4, ymm12, ymm7
	vpunpckldq ymm12, ymm12, ymm7
	vpaddq  ymm12, ymm12, [rdi+0x140]
	vpaddq  ymm4, ymm4, [rdi+0x1C0]
	vmovdqu [rdi+0x140], ymm12
	vmovdqu [rdi+0x1C0], ymm4
	vpermq  ymm14, ymm14, 0xD8
	vpunpckhdq ymm4, ymm14, ymm7
	vpunpckldq ymm14, ymm14, ymm7
	vpaddq  ymm14, ymm14, [rdi+0x160]
	vpaddq  ymm4, ymm4, [rdi+0x1E0]
	vmovdqu [rdi+0x160], ymm14
	vmovdqu [rdi+0x1E0], ymm4
	ret
	.size	accum64, .-accum64

#endif /* defined(__amd64__) */

	.section .note.GNU-stack,"",%progbits
