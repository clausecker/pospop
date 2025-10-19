#include "kernelavx2.S"

# not yet ported to 32 bit flag size
	.balign	16
accum8:
	.type   accum8, @function
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

	.balign	16
accum16:
	.type   accum16, @function
	vpunpcklwd ymm12, ymm8, ymm7
	vpunpckhwd ymm8, ymm8, ymm7
	vpunpcklwd ymm14, ymm9, ymm7
	vpunpckhwd ymm9, ymm9, ymm7
	vpunpcklwd ymm4, ymm10, ymm7
	vpunpckhwd ymm10, ymm10, ymm7
	vpunpcklwd ymm5, ymm11, ymm7
	vpunpckhwd ymm11, ymm11, ymm7
	vpaddd  ymm12, ymm4, ymm12	#  0- 3, 16-19
	vpaddd  ymm8, ymm10, ymm8	#  4- 7, 20-23
	vpaddd  ymm14, ymm5, ymm14	#  8-11, 24-27
	vpaddd  ymm9, ymm11, ymm9	# 12-15, 28-31
	vperm2i128 ymm4, ymm12, ymm8, 0x20
	vperm2i128 ymm10, ymm12, ymm8, 0x31
	vpaddd  ymm12, ymm10, ymm4
	vperm2i128 ymm5, ymm14, ymm9, 0x20
	vperm2i128 ymm11, ymm14, ymm9, 0x31
	vpaddd  ymm4, ymm11, ymm5

	vpaddd ymm12, ymm12, [rdi+0x00]
	vpaddd ymm4, ymm4, [rdi+0x20]
	vmovdqu [rdi+0x00], ymm12
	vmovdqu [rdi+0x20], ymm4
	ret

# not yet ported to 32 bit flag size
	.balign	16
accum32:
	.type   accum32, @function
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

# not yet ported to 32 bit flag size
	.balign	16
accum64:
	.type   accum64, @function
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
