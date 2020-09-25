#include "textflag.h"

// AVX512 based kernels for the positional population count operation.
// All these kernels have the same backbone based on a 15-fold CSA
// reduction to first reduce 960 byte into 4x64 byte, followed by a
// bunch of shuffles to group the positional registers into nibbles.
// These are then summed up using a width-specific summation function.
// Required CPU extensions: BMI2, AVX-512 -F, -VL, -BW, -DQ.

// magic constants
DATA magic<>+ 0(SB)/8, $0x0706050403020100
DATA magic<>+ 8(SB)/8, $0x8040201008040201
DATA magic<>+16(SB)/4, $0x55555555
DATA magic<>+20(SB)/4, $0x33333333
DATA magic<>+24(SB)/4, $0x0f0f0f0f
GLOBL magic<>(SB), RODATA|NOPTR, $28

// B:A = A+B+C, D used as scratch space
#define CSA(A, B, C, D) \
	VMOVDQA64 A, D \
	VPTERNLOGD $0x96, C, B, A \
	VPTERNLOGD $0xe8, C, D, B

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in BX, a possibly unaligned input buffer in SI,
// counters in DI and a remaining length in BP.
TEXT countavx512<>(SB), NOSPLIT, $0-0
	TESTQ CX, CX			// any data to process at all?
	CMOVQEQ CX, SI			// if not, avoid loading head

	// head and tail constants, counter registers
	VMOVQ magic<>+0(SB), X1		// 0706050403020100
	VPBROADCASTQ magic<>+8(SB), Z31	// 8040201008040201
	VPTERNLOGD $0xff, Z30, Z30, Z30	// ffffffff
	VPXORD Y25, Y25, Y25		// zero register
	VPXOR Y0, Y0, Y0		// counter register

	// turn X15 into a set of qword masks in Z29
	VPUNPCKLBW X1, X1, X1		// 7766:5544:3322:1100
	VPERMQ $0x50, Y1, Y1		// 7766:5544:7766:5544:3322:1100:3322:1100
	VPUNPCKLWD Y1, Y1, Y1		// 7777:6666:5555:4444:3333:2222:1111:0000
	VPMOVZXDQ Y1, Z1		// -7:-6:-5:-4:-3:-2:-1:-0
	VPSHUFD $0xa0, Z1, Z29		// 77:66:55:44:33:22:11:00

	// compute misalignment mask
	MOVL SI, DX
	ANDL $63, DX			// offset of the buffer start from 64 byte alignment
	JEQ nohead
	MOVQ $-1, R8
	SUBQ DX, SI			// align source to 64 byte
	SHLXQ CX, R8, R9		// mask with CX low order bits clear
	NOTQ R9				// mask with CX low order bits set
	CMPQ CX, $64			// does the buffer reach the end of the 64 byte load?
	CMOVQLT R9, R8			// mask with min(CX, 64) low order bits set
	SHLXQ DX, R8, R8		// mask out the head of the load
	KMOVQ R8, K1			// prepare mask register
	VMOVDQU8.Z (SI), K1, Z4		// load head with mask
	ADDQ $64, SI			// advance head past loaded data
	LEAQ -64(CX)(DX*1), CX		// account for head length in CX

	// process head, 16 bytes at a time
	MOVL $4, DX

head:	VPUNPCKHQDQ X4, X4, X6		// move second qword into X6
	SUBL $1, DX
	VPBROADCASTQ X4, Z5		// Z5 = 7--0:7--0:7--0:7--0:7--0:7--0:7--0:7--0
	VPBROADCASTQ X6, Z6		// Z6 = 7--0:7--0:7--0:7--0:7--0:7--0:7--0:7--0
	VPSHUFB Z29, Z5, Z5		// Z5 = 7..7:6..6:5..5:4..4:3..3:2..2:1..1:0..0
	VPSHUFB Z29, Z6, Z6		// Z6 = 7..7:6..6:5..5:4..4:3..3:2..2:1..1:0..0
	VSHUFI64X2 $0x39, Z4, Z4, Z4	// rotate Z4 right by 16 bytes
	VPTESTMB Z31, Z5, K1		// set bits in K1 if corresponding bit set in Z5
	VPTESTMB Z31, Z6, K2		// set bits in K2 if corresponding bit set in Z6
	VPSUBB Z30, Z0, K1, Z0		// subtract -1 from counters where K1 set
	VPSUBB Z30, Z0, K2, Z0		// subtract -1 from counters where K2 set
	JNZ head			// loop until processes completely

	// initialise counters
nohead:	VPUNPCKLBW Z25, Z0, Z8
	VPUNPCKHBW Z25, Z0, Z9

	SUBQ $15*64, CX			// enough data left to process?
	JLT endvec

	VPBROADCASTD magic<>+16(SB), Z28 // 0x55555555 for transposition
	VPBROADCASTD magic<>+20(SB), Z27 // 0x33333333 for transposition
	VPBROADCASTD magic<>+24(SB), Z26 // 0x0f0f0f0f for transposition

	MOVL $65535-8, AX		// space left til overflow could occur in Z8, Z9

vec:	VMOVDQA64 0*64(SI), Z0		// load 960 bytes from buf
	VMOVDQA64 1*64(SI), Z1		// and sum them into Z3:Z2:Z1:Z0
	VMOVDQA64 2*64(SI), Z4
	VMOVDQA64 3*64(SI), Z2
	VMOVDQA64 4*64(SI), Z3
	VMOVDQA64 5*64(SI), Z5
	VMOVDQA64 6*64(SI), Z6
	CSA(Z0, Z1, Z4, Z7)
	VMOVDQA64 7*64(SI), Z4
	CSA(Z3, Z2, Z5, Z7)
	VMOVDQA64 8*64(SI), Z5
	CSA(Z0, Z3, Z6, Z7)
	VMOVDQA64 9*64(SI), Z6
	CSA(Z1, Z2, Z3, Z7)
	VMOVDQA64 10*64(SI), Z3
	CSA(Z0, Z4, Z5, Z7)
	VMOVDQA64 11*64(SI), Z5
	CSA(Z0, Z3, Z6, Z7)
	VMOVDQA64 12*64(SI), Z6
	CSA(Z1, Z3, Z4, Z7)
	VMOVDQA64 13*64(SI), Z4
	CSA(Z0, Z5, Z6, Z7)
	VMOVDQA64 14*64(SI), Z6
	CSA(Z0, Z4, Z6, Z7)
	CSA(Z1, Z4, Z5, Z7)
	CSA(Z2, Z3, Z4, Z7)

	ADDQ $15*64, SI

#define D	45			// prefetch some iterations ahead
	PREFETCHT0 (D+ 0)*64(SI)
	PREFETCHT0 (D+ 1)*64(SI)
	PREFETCHT0 (D+ 2)*64(SI)
	PREFETCHT0 (D+ 3)*64(SI)
	PREFETCHT0 (D+ 4)*64(SI)
	PREFETCHT0 (D+ 5)*64(SI)
	PREFETCHT0 (D+ 6)*64(SI)
	PREFETCHT0 (D+ 7)*64(SI)
	PREFETCHT0 (D+ 8)*64(SI)
	PREFETCHT0 (D+ 9)*64(SI)
	PREFETCHT0 (D+10)*64(SI)
	PREFETCHT0 (D+11)*64(SI)
	PREFETCHT0 (D+12)*64(SI)
	PREFETCHT0 (D+13)*64(SI)
	PREFETCHT0 (D+14)*64(SI)
	PREFETCHT0 (D+15)*64(SI)

	// group nibbles in Z0, Z1, Z2, and Z3 into Z4, Z5, Z6, and Z7
	VPSRLD $1, Z0, Z4
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

	SUBL $15*8, AX			// account for possible overflow
	CMPL AX, $15*8			// enough space left in the counters?
	JGE have_space

	// flush accumulators into counters
	CALL *BX			// call accumulation function
	VPXOR Y8, Y8, Y8		// clear accumulators for next round
	VPXOR Y9, Y9, Y9
	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBQ $15*64, CX			// account for bytes consumed
	JGE vec

endvec:	VPXOR Y0, Y0, Y0		// counter register

	// process tail, 8 bytes at a time
	SUBL $8-15*64, CX		// 8 bytes left to process?
	JLT tail1

tail8:	VPBROADCASTQ (SI), Z4
	ADDQ $8, SI
	VPSHUFB Z29, Z4, Z4
	SUBL $8, CX
	VPTESTMB Z31, Z4, K1
	VPSUBB Z30, Z0, K1, Z0
	JGE tail8

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

TEXT accum64<>(SB), NOSPLIT, $0-0
	VPMOVZXWQ X8, Z3
	VPMOVZXWQ X9, Z4
	VPADDQ 0*64(DI), Z3, Z3
	VPADDQ 1*64(DI), Z4, Z4
	VMOVDQU64 Z3, 0*64(DI)
	VMOVDQU64 Z4, 1*64(DI)

	VEXTRACTI64X2 $1, Z8, X3
	VEXTRACTI64X2 $1, Z9, X4
	VPMOVZXWQ X3, Z3
	VPMOVZXWQ X4, Z4
	VPADDQ 2*64(DI), Z3, Z3
	VPADDQ 3*64(DI), Z4, Z4
	VMOVDQU64 Z3, 2*64(DI)
	VMOVDQU64 Z4, 3*64(DI)

	VEXTRACTI64X2 $2, Z8, X3
	VEXTRACTI64X2 $2, Z9, X4
	VPMOVZXWQ X3, Z3
	VPMOVZXWQ X4, Z4
	VPADDQ 4*64(DI), Z3, Z3
	VPADDQ 5*64(DI), Z4, Z4
	VMOVDQU64 Z3, 4*64(DI)
	VMOVDQU64 Z4, 5*64(DI)

	VEXTRACTI64X2 $3, Z8, X3
	VEXTRACTI64X2 $3, Z9, X4
	VPMOVZXWQ X3, Z3
	VPMOVZXWQ X4, Z4
	VPADDQ 6*64(DI), Z3, Z3
	VPADDQ 7*64(DI), Z4, Z4
	VMOVDQU64 Z3, 6*64(DI)
	VMOVDQU64 Z4, 7*64(DI)

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
