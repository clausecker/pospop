#include "textflag.h"

// An AVX512 based kernel first doing a 15-fold CSA reduction
// and then a 16-fold CSA reduction, carrying over place-value
// vectors between iterations.
// Required CPU extensions: BMI2, AVX-512 -F, -BW.

// magic constants
DATA magic<>+ 0(SB)/8, $0x0706050403020100
DATA magic<>+ 8(SB)/8, $0x8040201008040201
DATA magic<>+16(SB)/4, $0x55555555
DATA magic<>+20(SB)/4, $0x33333333
DATA magic<>+24(SB)/4, $0x0f0f0f0f
DATA magic<>+28(SB)/4, $0x00ff00ff

// permutation vectors for the last permutation step of the vec loop
// permutes words
// A = 0000 1111 2222 3333 4444 5555 6666 7777
// B = 8888 9999 AAAA BBBB CCCC DDDD EEEE FFFF
// into the order used by the counters:
// Q1 = 0123 4567 0123 4567 0123 4567 0123 4567
// Q2 = 89AB CDEF 89AB CDEF 89AB CDEF 89AB CDEF
DATA magic<>+32(SB)/8, $0x1c1814100c080400
DATA magic<>+40(SB)/8, $0x1d1915110d090501
DATA magic<>+48(SB)/8, $0x1e1a16120e0a0602
DATA magic<>+56(SB)/8, $0x1f1b17130f0b0703
GLOBL magic<>(SB), RODATA|NOPTR, $64

// B:A = A+B+C, D used as scratch space
#define CSA(A, B, C, D) \
	VMOVDQA64 A, D \
	VPTERNLOGD $0x96, C, B, A \
	VPTERNLOGD $0xe8, C, D, B

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in BX, a possibly unaligned input buffer in SI,
// counters in DI and an array length in CX.
TEXT countavx512<>(SB), NOSPLIT, $0-0
	// head and tail constants, counter registers
	VMOVQ magic<>+0(SB), X1		// 0706050403020100
	VPBROADCASTQ magic<>+8(SB), Z31	// 8040201008040201
	VPTERNLOGD $0xff, Z30, Z30, Z30	// ffffffff
	VPXORD Y25, Y25, Y25		// zero register

	// turn X15 into a set of qword masks in Z29
	VPUNPCKLBW X1, X1, X1		// 7766:5544:3322:1100
	VPERMQ $0x50, Y1, Y1		// 7766:5544:7766:5544:3322:1100:3322:1100
	VPUNPCKLWD Y1, Y1, Y1		// 7777:6666:5555:4444:3333:2222:1111:0000
	VPMOVZXDQ Y1, Z1		// -7:-6:-5:-4:-3:-2:-1:-0
	VPSHUFD $0xa0, Z1, Z29		// 77:66:55:44:33:22:11:00

	CMPQ CX, $15*64			// is the CSA kernel worth using?
	JLT runt

	// compute misalignment mask
	MOVL SI, DX
	ANDL $63, DX			// offset of the buffer start from 64 byte alignment
	MOVQ $-1, AX
	SUBQ DX, SI			// align source to 64 byte
	ADDQ DX, CX			// account for head length in CX
	SHLXQ DX, AX, AX		// mask out the head of the load
	KMOVQ AX, K1			// prepare mask register

	VMOVDQU8.Z 0*64(SI), K1, Z0	// load 960 bytes from buf
	VMOVDQA64 1*64(SI), Z1		// and sum them into Z3:Z2:Z1:Z0
	VMOVDQA64 2*64(SI), Z4
	VPXOR Y8, Y8, Y8		// initialise counters
	VPXOR Y9, Y9, Y9
	VMOVDQA64 3*64(SI), Z2
	VMOVDQA64 4*64(SI), Z3
	VMOVDQA64 5*64(SI), Z5
	CSA(Z0, Z1, Z4, Z22)
	VMOVDQA64 6*64(SI), Z6
	VMOVDQA64 7*64(SI), Z7
	VMOVDQA64 8*64(SI), Z10
	CSA(Z2, Z3, Z5, Z22)
	VMOVDQA64 9*64(SI), Z11
	VMOVDQA64 10*64(SI), Z12
	VMOVDQA64 11*64(SI), Z13
	CSA(Z6, Z7, Z10, Z22)
	VMOVDQA64 12*64(SI), Z4
	VMOVDQA64 13*64(SI), Z5
	VMOVDQA64 14*64(SI), Z10
	CSA(Z11, Z12, Z13, Z22)
	VPBROADCASTD magic<>+16(SB), Z28 // 0x55555555 for transposition
	VPBROADCASTD magic<>+20(SB), Z27 // 0x33333333 for transposition
	VPBROADCASTD magic<>+24(SB), Z26 // 0x0f0f0f0f for transposition
	CSA(Z4, Z5, Z10, Z22)
	CSA(Z0, Z2, Z6, Z22)
	CSA(Z1, Z3, Z7, Z22)
	CSA(Z0, Z11, Z4, Z22)
	CSA(Z2, Z12, Z5, Z22)
	CSA(Z1, Z2, Z11, Z22)
	CSA(Z2, Z3, Z12, Z22)

	ADDQ $15*64, SI
	SUBQ $(15+16)*64, CX		// enough data left to process?
	JLT post

	VPBROADCASTD magic<>+28(SB), Z24 // 0x00ff00ff
	VPMOVZXBW magic<>+32(SB), Z23	// transposition vector
	MOVL $65535, AX			// space left til overflow could occur in Z8, Z9

	// load 1024 bytes from buf, add them to Z0..Z3 into Z0..Z4
vec:	VMOVDQA64 0*64(SI), Z4
	VMOVDQA64 1*64(SI), Z5
	VMOVDQA64 2*64(SI), Z6
	VMOVDQA64 3*64(SI), Z7
	VMOVDQA64 4*64(SI), Z10
	CSA(Z0, Z4, Z5, Z22)
	VMOVDQA64 5*64(SI), Z5
	VMOVDQA64 6*64(SI), Z11
	VMOVDQA64 7*64(SI), Z12
	CSA(Z6, Z7, Z10, Z22)
	VMOVDQA64 8*64(SI), Z10
	VMOVDQA64 9*64(SI), Z13
	VMOVDQA64 10*64(SI), Z14
	CSA(Z5, Z11, Z12, Z22)
	VMOVDQA64 11*64(SI), Z12
	VMOVDQA64 12*64(SI), Z15
	VMOVDQA64 13*64(SI), Z16
	CSA(Z10, Z13, Z14, Z22)
	VMOVDQA64 14*64(SI), Z14
	VMOVDQA64 15*64(SI), Z17
	CSA(Z12, Z15, Z16, Z22)
	ADDQ $16*64, SI
	PREFETCHT0 (SI)
	CSA(Z0, Z5, Z6, Z22)
	PREFETCHT0 64(SI)
	CSA(Z1, Z4, Z7, Z22)
	CSA(Z10, Z12, Z14, Z22)
	CSA(Z11, Z13, Z15, Z22)
	CSA(Z0, Z10, Z17, Z22)
	CSA(Z1, Z5, Z11, Z22)
	CSA(Z2, Z4, Z13, Z22)
	CSA(Z1, Z10, Z12, Z22)
	CSA(Z2, Z5, Z10, Z22)
	CSA(Z3, Z4, Z5, Z22)

	// now Z0..Z4 hold counters; preserve Z0..Z3 for next round and
	// add Z4 to counters.

	// split into even/odd and reduce into crumbs
	VPANDD Z4, Z28, Z5		// Z5 = bits 02468ace x32
	VPANDND Z4, Z28, Z6		// Z6 = bits 13579bdf x32
	VPSRLD $1, Z6, Z6
	VSHUFI64X2 $0x44, Z6, Z5, Z10
	VSHUFI64X2 $0xee, Z6, Z5, Z11
	VPADDD Z10, Z11, Z4		// Z4 = 02468ace x16 ... 13579bdf x16

	// split again and reduce into nibbles
	VPANDD Z4, Z27, Z5		// Z5 = 048c x16 ... 159d x16
	VPANDND Z4, Z27, Z6		// Z6 = 26ae x16 ... 37bf x16
	VPSRLD $2, Z6, Z6
	VSHUFI64X2 $0x88, Z6, Z5, Z10
	VSHUFI64X2 $0xdd, Z6, Z5, Z11
	VPADDD Z10, Z11, Z4		// Z4 = 048c x8  159d x8  26ae x8  37bf x8

	// split again and reduce into bytes (shifted left by 4)
	VPANDD Z4, Z26, Z5		// Z5 = 08 x8  19 x8  2a x8  3b x8
	VPANDND Z4, Z26, Z6		// Z6 = 4c x8  5d x8  6e x8  7f x8
	VPSLLD $4, Z5, Z5
	VPERMQ $0xd8, Z5, Z5		// Z5 = 08x4 19x4 08x4 19x4  2ax4 3bx4 2ax4 3bx4
	VPERMQ $0xd8, Z6, Z6		// Z6 = 4cx4 5dx4 4cx4 5dx4  6ex4 7fx4 6ex4 7fx4
	VSHUFI64X2 $0x88, Z6, Z5, Z10
	VSHUFI64X2 $0xdd, Z6, Z5, Z11
	VPADDD Z10, Z11, Z4		// Z4 = 08x4 19x4 2ax4 3bx4 4cx4 5dx4 6ex4 7fx4

	// split again into 16 bit counters
	VPSRLW $8, Z4, Z6		// Z6 = 8888 9999 aaaa bbbb cccc dddd eeee ffff
	VPANDD Z4, Z24, Z5		// Z5 = 0000 1111 2222 3333 4444 5555 6666 7777

	// accumulate in permuted order
	VPADDW Z5, Z8, Z8
	VPADDW Z6, Z9, Z9

	SUBL $16*8, AX			// account for possible overflow
	CMPL AX, $(15+15+16)*8		// enough space left in the counters?
	JGE have_space

	// fix permutation and flush into counters
	VPERMW Z8, Z23, Z8		// Z5 = 0123 4567 0123 4567 0123 4567 0123 4567
	VPERMW Z9, Z23, Z9		// Z6 = 89ab cdef 89ab cdef 89ab cdef 89ab cdef
	CALL *BX			// call accumulation function
	VPXOR Y8, Y8, Y8		// clear accumulators for next round
	VPXOR Y9, Y9, Y9
	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBQ $16*64, CX			// account for bytes consumed
	JGE vec

	// fix permutation for final step
	VPERMW Z8, Z23, Z8		// Z5 = 0123 4567 0123 4567 0123 4567 0123 4567
	VPERMW Z9, Z23, Z9		// Z6 = 89ab cdef 89ab cdef 89ab cdef 89ab cdef

	// sum up Z0..Z3 into the counter registers
post:	VPSRLD $1, Z0, Z4		// group nibbles in Z0--Z3 into Z4--Z7
	VPADDD Z1, Z1, Z5
	VPSRLD $1, Z2, Z6
	VPADDD Z3, Z3, Z7
	VPTERNLOGD $0xe4, Z28, Z5, Z0	// Z0 = eca86420 (low crumbs)
	VPTERNLOGD $0xd8, Z28, Z4, Z1	// Z1 = fdb97531 (high crumbs)
	VPTERNLOGD $0xe4, Z28, Z7, Z2	// Z2 = eca86420 (low crumbs)
	VPTERNLOGD $0xd8, Z28, Z6, Z3	// Z3 = fdb97531 (high crumbs)

	VPSRLD $2, Z0, Z4
	VPSRLD $2, Z1, Z6
	VPSLLD $2, Z2, Z5
	VPSLLD $2, Z3, Z7
	VPTERNLOGD $0xd8, Z27, Z4, Z2	// Z2 = ea63
	VPTERNLOGD $0xd8, Z27, Z6, Z3	// Z3 = fb73
	VPTERNLOGD $0xe4, Z27, Z5, Z0	// Z0 = c840
	VPTERNLOGD $0xe4, Z27, Z7, Z1	// Z1 = d951

	// pre-shuffle nibbles (within 128 bit lanes)!
	VPUNPCKLBW Z3, Z2, Z6		// Z6 = fbea7362 (3:2:1:0)
	VPUNPCKHBW Z3, Z2, Z3		// Z3 = fbea7362 (7:6:5:4)
	VPUNPCKLBW Z1, Z0, Z5		// Z5 = d9c85140 (3:2:1:0)
	VPUNPCKHBW Z1, Z0, Z2		// Z2 = d9c85140 (7:6:5:4)
	VPUNPCKLWD Z6, Z5, Z4		// Z4 = fbead9c873625140 (1:0)
	VPUNPCKHWD Z6, Z5, Z5		// Z5 = fbead9c873625140 (3:2)
	VPUNPCKLWD Z3, Z2, Z6		// Z6 = fbead9c873625140 (5:4)
	VPUNPCKHWD Z3, Z2, Z7		// Z7 = fbead9c873625140 (7:6)

	// pull out high and low nibbles
	VPANDD Z26, Z4, Z0
	VPSRLD $4, Z4, Z4
	VPANDD Z26, Z4, Z4

	VPANDD Z26, Z5, Z1
	VPSRLD $4, Z5, Z5
	VPANDD Z26, Z5, Z5

	VPANDD Z26, Z6, Z2
	VPSRLD $4, Z6, Z6
	VPANDD Z26, Z6, Z6

	VPANDD Z26, Z7, Z3
	VPSRLD $4, Z7, Z7
	VPANDD Z26, Z7, Z7

	// reduce once
	VPADDB Z2, Z0, Z0		// Z0 = ba983210 (1:0)
	VPADDB Z3, Z1, Z1		// Z1 = ba983210 (3:2)
	VPADDB Z6, Z4, Z2		// Z2 = fedc7654 (1:0)
	VPADDB Z7, Z5, Z3		// Z3 = fedc7654 (3:2)

	// shuffle again to form ordered groups of 16 counters in each lane
	VPUNPCKLDQ Z2, Z0, Z4		// Z4 = fedcba9876543210 (0)
	VPUNPCKHDQ Z2, Z0, Z5		// Z5 = fedcba9876543210 (1)
	VPUNPCKLDQ Z3, Z1, Z6		// Z6 = fedcba9876543210 (2)
	VPUNPCKHDQ Z3, Z1, Z7		// Z7 = fedcba9876543210 (3)

	// reduce lanes once (4x1 lane -> 2x2 lanes)
	VSHUFI64X2 $0x44, Z5, Z4, Z0	// Z0 = fedcba9876543210 (1:1:0:0)
	VSHUFI64X2 $0xee, Z5, Z4, Z1	// Z1 = fedcba9876543210 (1:1:0:0)
	VSHUFI64X2 $0x44, Z7, Z6, Z2	// Z2 = fedcba9876543210 (3:3:2:2)
	VSHUFI64X2 $0xee, Z7, Z6, Z3	// Z2 = fedcba9876543210 (3:3:2:2)
	VPADDB Z1, Z0, Z0
	VPADDB Z3, Z2, Z2

	// reduce lanes again (2x2 lanes -> 1x4 lane)
	VSHUFI64X2 $0x88, Z2, Z0, Z1	// Z1 = fedcba9876543210 (3:2:1:0)
	VSHUFI64X2 $0xdd, Z2, Z0, Z0	// Z0 = fedcba9876543210 (3:2:1:0)
	VPADDB Z1, Z0, Z0

	// Zero extend and add to Z8, Z9
	VPUNPCKLBW Z25, Z0, Z1		// Z1 = 76543210 (3:2:1:0)
	VPUNPCKHBW Z25, Z0, Z2		// Z2 = fedcba98 (3:2:1:0)
	VPADDW Z1, Z8, Z8
	VPADDW Z2, Z9, Z9

endvec:	VPXOR Y0, Y0, Y0		// counter register

	// process tail, 8 bytes at a time
	SUBL $8-16*64, CX		// 8 bytes left to process?
	JLT tail1

tail8:	VPBROADCASTQ (SI), Z4
	ADDQ $8, SI
	VPSHUFB Z29, Z4, Z4
	SUBL $8, CX
	VPTESTMB Z31, Z4, K1
	VPSUBB Z30, Z0, K1, Z0
	JGT tail8

	// process remaining 0--7 bytes
tail1:	SUBL $-8, CX
	JLE end				// anything left to process?

	VPBROADCASTQ (SI), Z4
	VPSHUFB Z29, Z4, Z4
	XORL AX, AX
	BTSL CX, AX			// 1 << CX
	DECL AX				// bit mask of CX ones
	KMOVB AX, K1			// move into a mask register
	VMOVDQA64.Z Z4, K1, Z4		// mask out the bytes that aren't in the tail
	VPTESTMB Z31, Z4, K1
	VPSUBB Z30, Z0, K1, Z0

	// add tail to counters
end:	VPUNPCKLBW Z25, Z0, Z1
	VPUNPCKHBW Z25, Z0, Z2
	VPADDW Z1, Z8, Z8
	VPADDW Z2, Z9, Z9

	// and perform a final accumulation
	CALL *BX
	VZEROUPPER
	RET

	// special processing for when the data is less than
	// one iteration of the kernel
runt:	VPXOR Y0, Y0, Y0		// counter register
	SUBL $8, CX			// 8 bytes left to process?
	JLT runt1

runt8:	VPBROADCASTQ (SI), Z4
	ADDQ $8, SI
	VPSHUFB Z29, Z4, Z4
	SUBL $8, CX
	VPTESTMB Z31, Z4, K1
	VPSUBB Z30, Z0, K1, Z0
	JGE runt8

	// process remaining 0--8 bytes
runt1:	ADDL $8, CX
	XORL AX, AX
	BTSL CX, AX			// 1 << CX
	DECL AX				// mask of CX ones
	KMOVD AX, K1
	VMOVDQU8.Z (SI), K1, X4
	VPBROADCASTQ X4, Z4
	VPSHUFB Z29, Z4, Z4
	VPTESTMB Z31, Z4, K1
	VPSUBB Z30, Z0, K1, Z0

	// populate counters and accumulate
runt0:	VPUNPCKLBW Z25, Z0, Z8
	VPUNPCKHBW Z25, Z0, Z9
	CALL *BX
	VZEROUPPER
	RET

TEXT accum8<>(SB), NOSPLIT, $0-0
	// unpack and zero-extend
	VPMOVZXWQ X8, Z10
	VEXTRACTI128 $1, Y8, X11
	VPMOVZXWQ X11, Z11
	VEXTRACTI64X2 $2, Z8, X12
	VPMOVZXWQ X12, Z12
	VEXTRACTI64X2 $3, Z8, X13
	VPMOVZXWQ X13, Z13
	VPMOVZXWQ X9, Z14
	VEXTRACTI128 $1, Y9, X15
	VPMOVZXWQ X15, Z15
	VEXTRACTI64X2 $2, Z9, X16
	VPMOVZXWQ X16, Z16
	VEXTRACTI64X2 $3, Z9, X17
	VPMOVZXWQ X17, Z17

	// fold over thrice
	VPADDQ Z12, Z10, Z10
	VPADDQ Z13, Z11, Z11
	VPADDQ Z16, Z14, Z14
	VPADDQ Z17, Z15, Z15
	VPADDQ Z11, Z10, Z10
	VPADDQ Z15, Z14, Z14
	VPADDQ Z14, Z10, Z10

	// add to counters
	VPADDQ 0*64(DI), Z10, Z10
	VMOVDQU64 Z10, 0*64(DI)

	RET

TEXT accum16<>(SB), NOSPLIT, $0-0
	// unpack and zero-extend
	VPMOVZXWQ X8, Z10
	VEXTRACTI128 $1, Y8, X11
	VPMOVZXWQ X11, Z11
	VEXTRACTI64X2 $2, Z8, X12
	VPMOVZXWQ X12, Z12
	VEXTRACTI64X2 $3, Z8, X13
	VPMOVZXWQ X13, Z13
	VPMOVZXWQ X9, Z14
	VEXTRACTI128 $1, Y9, X15
	VPMOVZXWQ X15, Z15
	VEXTRACTI64X2 $2, Z9, X16
	VPMOVZXWQ X16, Z16
	VEXTRACTI64X2 $3, Z9, X17
	VPMOVZXWQ X17, Z17

	// fold over twice
	VPADDQ Z12, Z10, Z10
	VPADDQ Z13, Z11, Z11
	VPADDQ Z16, Z14, Z14
	VPADDQ Z17, Z15, Z15
	VPADDQ Z11, Z10, Z10
	VPADDQ Z15, Z14, Z14

	// add to counters
	VPADDQ 0*64(DI), Z10, Z10
	VPADDQ 1*64(DI), Z14, Z14
	VMOVDQU64 Z10, 0*64(DI)
	VMOVDQU64 Z14, 1*64(DI)

	RET

TEXT accum32<>(SB), NOSPLIT, $0-0
	// fold high half over low half and reduce
	VEXTRACTI64X2 $2, Z8, X12
	VEXTRACTI64X2 $2, Z9, X13
	VPMOVZXWQ X8, Z10
	VPMOVZXWQ X9, Z11
	VPMOVZXWQ X12, Z12
	VPMOVZXWQ X13, Z13
	VPADDQ Z12, Z10, Z10
	VPADDQ Z13, Z11, Z11
	VPADDQ 0*64(DI), Z10, Z10
	VPADDQ 1*64(DI), Z11, Z11
	VMOVDQU64 Z10, 0*64(DI)
	VMOVDQU64 Z11, 1*64(DI)

	VEXTRACTI128 $1, Y8, X10
	VEXTRACTI128 $1, Y9, X11
	VEXTRACTI64X2 $3, Z8, X12
	VEXTRACTI64X2 $3, Z9, X13
	VPMOVZXWQ X10, Z10
	VPMOVZXWQ X11, Z11
	VPMOVZXWQ X12, Z12
	VPMOVZXWQ X13, Z13
	VPADDQ Z12, Z10, Z10
	VPADDQ Z13, Z11, Z11
	VPADDQ 2*64(DI), Z10, Z10
	VPADDQ 3*64(DI), Z11, Z11
	VMOVDQU64 Z10, 2*64(DI)
	VMOVDQU64 Z11, 3*64(DI)

	RET

TEXT accum64<>(SB), NOSPLIT, $0-0
	VPMOVZXWQ X8, Z13
	VPMOVZXWQ X9, Z14
	VPADDQ 0*64(DI), Z13, Z13
	VPADDQ 1*64(DI), Z14, Z14
	VMOVDQU64 Z13, 0*64(DI)
	VMOVDQU64 Z14, 1*64(DI)

	VEXTRACTI128 $1, Y8, X13
	VEXTRACTI128 $1, Y9, X14
	VPMOVZXWQ X13, Z13
	VPMOVZXWQ X14, Z14
	VPADDQ 2*64(DI), Z13, Z13
	VPADDQ 3*64(DI), Z14, Z14
	VMOVDQU64 Z13, 2*64(DI)
	VMOVDQU64 Z14, 3*64(DI)

	VEXTRACTI64X2 $2, Z8, X13
	VEXTRACTI64X2 $2, Z9, X14
	VPMOVZXWQ X13, Z13
	VPMOVZXWQ X14, Z14
	VPADDQ 4*64(DI), Z13, Z13
	VPADDQ 5*64(DI), Z14, Z14
	VMOVDQU64 Z13, 4*64(DI)
	VMOVDQU64 Z14, 5*64(DI)

	VEXTRACTI64X2 $3, Z8, X13
	VEXTRACTI64X2 $3, Z9, X14
	VPMOVZXWQ X13, Z13
	VPMOVZXWQ X14, Z14
	VPADDQ 6*64(DI), Z13, Z13
	VPADDQ 7*64(DI), Z14, Z14
	VMOVDQU64 Z13, 6*64(DI)
	VMOVDQU64 Z14, 7*64(DI)

	RET

// func count8avx512(counts *[8]int, buf []uint8)
TEXT ·count8avx512(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	MOVQ $accum8<>(SB), BX
	CALL countavx512<>(SB)
	RET

// func count16avx512(counts *[16]int, buf []uint16)
TEXT ·count16avx512(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	MOVQ $accum16<>(SB), BX
	SHLQ $1, CX
	CALL countavx512<>(SB)
	RET

// func count32avx512(counts *[32]int, buf []uint32)
TEXT ·count32avx512(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	MOVQ $accum32<>(SB), BX
	SHLQ $2, CX
	CALL countavx512<>(SB)
	RET

// func count64avx512(counts *[64]int, buf []uint64)
TEXT ·count64avx512(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	MOVQ $accum64<>(SB), BX
	SHLQ $3, CX
	CALL countavx512<>(SB)
	RET
