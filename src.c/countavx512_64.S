#ifdef __amd64__

#include "kernelavx512.S"

	.balign 16
accum8:
	.type   accum8, @function
	vpmovzxwq zmm0, xmm8
	vextracti64x2 xmm1, zmm8, 0x01
	vpmovzxwq zmm1, xmm1
	vextracti64x2 xmm2, zmm8, 0x02
	vpmovzxwq zmm2, xmm2
	vextracti64x2 xmm3, zmm8, 0x03
	vpmovzxwq zmm3, xmm3
	vpmovzxwq zmm4, xmm9
	vextracti64x2 xmm5, zmm9, 0x01
	vpmovzxwq zmm5, xmm5
	vextracti64x2 xmm6, zmm9, 0x02
	vpmovzxwq zmm6, xmm6
	vextracti64x2 xmm7, zmm9, 0x03
	vpmovzxwq zmm7, xmm7
	vpaddq  zmm0, zmm0, zmm2
	vpaddq  zmm1, zmm1, zmm3
	vpaddq  zmm4, zmm4, zmm6
	vpaddq  zmm5, zmm5, zmm7
	vpaddq  zmm0, zmm0, zmm1
	vpaddq  zmm4, zmm4, zmm5
	vpaddq  zmm0, zmm0, zmm4
	vpaddq  zmm0, zmm0, [rdi]
	vmovdqu64 [rdi], zmm0
	ret

	.balign 16
accum16:
	.type   accum16, @function
	vpmovzxwq zmm10, xmm8
	vextracti64x2 xmm11, zmm8, 0x01
	vpmovzxwq zmm11, xmm11
	vextracti64x2 xmm12, zmm8, 0x02
	vpmovzxwq zmm12, xmm12
	vextracti64x2 xmm13, zmm8, 0x03
	vpmovzxwq zmm13, xmm13
	vpmovzxwq zmm14, xmm9
	vextracti64x2 xmm15, zmm9, 0x01
	vpmovzxwq zmm15, xmm15
	vextracti64x2 xmm16, zmm9, 0x02
	vpmovzxwq zmm16, xmm16
	vextracti64x2 xmm17, zmm9, 0x03
	vpmovzxwq zmm17, xmm17
	vpaddq  zmm10, zmm10, zmm12
	vpaddq  zmm11, zmm11, zmm13
	vpaddq  zmm14, zmm14, zmm16
	vpaddq  zmm15, zmm15, zmm17
	vpaddq  zmm10, zmm10, zmm11
	vpaddq  zmm14, zmm14, zmm15
	vpaddq  zmm10, zmm10, [rdi]
	vpaddq  zmm14, zmm14, [rdi+0x1*0x40]
	vmovdqu64 [rdi], zmm10
	vmovdqu64 [rdi+0x1*0x40], zmm14
	ret

	.balign 16
accum32:
	.type   accum32, @function
	vextracti64x2 xmm2, zmm8, 0x02
	vextracti64x2 xmm3, zmm9, 0x02
	vpmovzxwq zmm0, xmm8
	vpmovzxwq zmm1, xmm9
	vpmovzxwq zmm2, xmm2
	vpmovzxwq zmm3, xmm3
	vpaddq  zmm0, zmm0, zmm2
	vpaddq  zmm1, zmm1, zmm3
	vpaddq  zmm0, zmm0, [rdi]
	vpaddq  zmm1, zmm1, [rdi+0x1*0x40]
	vmovdqu64 [rdi], zmm0
	vmovdqu64 [rdi+0x1*0x40], zmm1
	vextracti64x2 xmm0, zmm8, 0x01
	vextracti64x2 xmm1, zmm9, 0x01
	vextracti64x2 xmm2, zmm8, 0x03
	vextracti64x2 xmm3, zmm9, 0x03
	vpmovzxwq zmm0, xmm0
	vpmovzxwq zmm1, xmm1
	vpmovzxwq zmm2, xmm2
	vpmovzxwq zmm3, xmm3
	vpaddq  zmm0, zmm0, zmm2
	vpaddq  zmm1, zmm1, zmm3
	vpaddq  zmm0, zmm0, [rdi+0x2*0x40]
	vpaddq  zmm1, zmm1, [rdi+0x3*0x40]
	vmovdqu64 [rdi+0x2*0x40], zmm0
	vmovdqu64 [rdi+0x3*0x40], zmm1
	ret

	.balign 16
accum64:
	.type   accum64, @function
	vpmovzxwq zmm3, xmm8
	vpmovzxwq zmm4, xmm9
	vpaddq  zmm3, zmm3, [rdi]
	vpaddq  zmm4, zmm4, [rdi+0x1*0x40]
	vmovdqu64 [rdi], zmm3
	vmovdqu64 [rdi+0x1*0x40], zmm4
	vextracti64x2 xmm3, zmm8, 0x01
	vextracti64x2 xmm4, zmm9, 0x01
	vpmovzxwq zmm3, xmm3
	vpmovzxwq zmm4, xmm4
	vpaddq  zmm3, zmm3, [rdi+0x2*0x40]
	vpaddq  zmm4, zmm4, [rdi+0x3*0x40]
	vmovdqu64 [rdi+0x2*0x40], zmm3
	vmovdqu64 [rdi+0x3*0x40], zmm4
	vextracti64x2 xmm3, zmm8, 0x02
	vextracti64x2 xmm4, zmm9, 0x02
	vpmovzxwq zmm3, xmm3
	vpmovzxwq zmm4, xmm4
	vpaddq  zmm3, zmm3, [rdi+0x4*0x40]
	vpaddq  zmm4, zmm4, [rdi+0x5*0x40]
	vmovdqu64 [rdi+0x4*0x40], zmm3
	vmovdqu64 [rdi+0x5*0x40], zmm4
	vextracti64x2 xmm3, zmm8, 0x03
	vextracti64x2 xmm4, zmm9, 0x03
	vpmovzxwq zmm3, xmm3
	vpmovzxwq zmm4, xmm4
	vpaddq  zmm3, zmm3, [rdi+0x6*0x40]
	vpaddq  zmm4, zmm4, [rdi+0x7*0x40]
	vmovdqu64 [rdi+0x6*0x40], zmm3
	vmovdqu64 [rdi+0x7*0x40], zmm4
	ret

#endif /* defined(__amd64__) */
