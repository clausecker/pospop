#include "textflag.h"

// 8 bit positional population count using AVX-2.
// Processes 480 bytes at a time using a 15-fold
// carry-save-adder reduction.  The bits are then
// grouped with VPMOVMSKB and counted individually
// with POPCNT.  Required feature flags: POPCNT, AVX2

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	VPAND A, B, D \
	VPXOR A, B, A \
	VPAND A, C, B \
	VPXOR A, C, A \
	VPOR  B, D, B

// count the number of set MSB of the bytes of Y into R.
#define COUNT(Y, R) \
	VPMOVMSKB Y, R \
	POPCNTL R, R

// same as COUNT, but shift Y left afterwards.
#define COUNTS(Y, R) \
	COUNT(Y, R) \
	VPADDB Y, Y, Y

// count the number of MSB set in Y4:Y3:Y1:Y0
// and accumulate into R
#define ACCUM(R) \
	COUNT(Y4, AX) \
	COUNT(Y3, BX) \
	LEAL (BX)(AX*2), AX \
	COUNT(Y1, BX) \
	COUNT(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDQ AX, R

// same as ACCUM, but use COUNTS instead of COUNT
#define ACCUMS(R) \
	COUNTS(Y4, AX) \
	COUNTS(Y3, BX) \
	LEAL (BX)(AX*2), AX \
	COUNTS(Y1, BX) \
	COUNTS(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDQ AX, R

// magic constants
DATA magic<>+ 0(SB)/8, $0x0000000000000000
DATA magic<>+ 8(SB)/8, $0x0101010101010101
DATA magic<>+16(SB)/8, $0x0202020202020202
DATA magic<>+24(SB)/8, $0x0303030303030303
DATA magic<>+32(SB)/8, $0x8040201008040201
GLOBL magic<>(SB), RODATA|NOPTR, $40

// func count8avx2(counts *[8]int, buf []byte)
TEXT ·count8avx2(SB),NOSPLIT,$0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)

	SUBQ $15*32, CX			// pre-decrement CX
	JL end15

	// load counts into register R8--R15
	MOVQ 8*0(DI), R8
	MOVQ 8*1(DI), R9
	MOVQ 8*2(DI), R10
	MOVQ 8*3(DI), R11
	MOVQ 8*4(DI), R12
	MOVQ 8*5(DI), R13
	MOVQ 8*6(DI), R14
	MOVQ 8*7(DI), R15

vec15:	VMOVDQU 0*32(SI), Y0		// load 480 bytes from buf into Y0--Y14
	VMOVDQU 1*32(SI), Y1
	VMOVDQU 2*32(SI), Y2
	CSA(Y0, Y1, Y2, Y15)

	VMOVDQU 3*32(SI), Y3
	VMOVDQU 4*32(SI), Y4
	VMOVDQU 5*32(SI), Y5
	CSA(Y3, Y4, Y5, Y15)

	VMOVDQU 6*32(SI), Y6
	VMOVDQU 7*32(SI), Y7
	VMOVDQU 8*32(SI), Y8
	CSA(Y6, Y7, Y8, Y15)

	VMOVDQU 9*32(SI), Y9
	VMOVDQU 10*32(SI), Y10
	VMOVDQU 11*32(SI), Y11
	CSA(Y9, Y10, Y11, Y15)

	VMOVDQU 12*32(SI), Y12
	VMOVDQU 13*32(SI), Y13
	VMOVDQU 14*32(SI), Y14
	CSA(Y12, Y13, Y14, Y15)

	ADDQ $15*32, SI
#define D	75
	PREFETCHT0 (D+ 0)*32(SI)
	PREFETCHT0 (D+ 2)*32(SI)
	PREFETCHT0 (D+ 4)*32(SI)
	PREFETCHT0 (D+ 6)*32(SI)
	PREFETCHT0 (D+ 8)*32(SI)
	PREFETCHT0 (D+10)*32(SI)
	PREFETCHT0 (D+12)*32(SI)
	PREFETCHT0 (D+14)*32(SI)

	CSA(Y0, Y3, Y6, Y15)
	CSA(Y1, Y4, Y7, Y15)
	CSA(Y0, Y9, Y12, Y15)
	CSA(Y1, Y3, Y10, Y15)
	CSA(Y1, Y9, Y13, Y15)
	CSA(Y3, Y4, Y9, Y15)

	// Y4:Y3:Y1:Y0 = Y0+Y1+...+Y14

	ACCUMS(R15)
	ACCUMS(R14)
	ACCUMS(R13)
	ACCUMS(R12)
	ACCUMS(R11)
	ACCUMS(R10)
	ACCUMS(R9)
	ACCUM(R8)

	SUBQ $15*32, CX
	JGE vec15			// repeat as long as bytes are left

	// write values back to count
	MOVQ R8, 8*0(DI)
	MOVQ R9, 8*1(DI)
	MOVQ R10, 8*2(DI)
	MOVQ R11, 8*3(DI)
	MOVQ R12, 8*4(DI)
	MOVQ R13, 8*5(DI)
	MOVQ R14, 8*6(DI)
	MOVQ R15, 8*7(DI)

end15:	VPXOR X0, X0, X0		// Y0: 32 byte sized counters
	VPBROADCASTQ magic<>+32(SB), Y2	// Y2: mask of bits positions

	SUBQ $4-15*32, CX		// undo last subtraction and
	JL end4				// pre-subtract 4 bytes from CX

	VMOVDQU magic<>+0(SB), Y3	// Y3: shuffle mask

	// 4 bytes at a time
vec4:	VPBROADCASTD (SI), Y1		// load 4 bytes from the buffer
	ADDQ $4, SI			// advance past loaded bytes
	VPSHUFB Y3, Y1, Y1		// shuffle bytes into the right places
	VPAND Y2, Y1, Y1		// mask out the desired bits
	VPCMPEQB Y2, Y1, Y1		// set byte to -1 if corresponding bit set
	VPSUBB Y1, Y0, Y0		// and subtract from the counters

	SUBQ $4, CX			// decrement counter and loop
	JGE vec4

end4:	SUBQ $1-4, CX			// undo last-subtraction and
	JL end1				// pre-subtract 4 bytes from CX

	VPXOR X3, X3, X3		// X2: counters for the scalar tail

	// scalar tail
scalar:	VPBROADCASTB (SI), X1		// load a byte from the buffer
	INCQ SI				// advance buffer past the loaded bytes
	VPAND X2, X1, X1		// mask out the desired bits
	VPCMPEQB X2, X1, X1		// set byte to -1 if corresponding bit set
	VPSUBB X1, X3, X3		// and subtract from the counters
	SUBQ $1, CX			// decrement counter and loop
	JGE scalar

	VPSRLDQ $8, X3, X3		// discard low copy of counters
	VPADDB Y3, Y0, Y0		// and add them to the others

	// add to counters
end1:	VEXTRACTI128 $1, Y0, X1		// extract high counter pair
	VPADDB X1, X0, X0		// and fold over low pair

	VPMOVZXBQ X0, Y1		// extra individual counters
	VPSRLDQ $4, X0, X0
	VPADDQ 0*32(DI), Y1, Y1

	VPMOVZXBQ X0, Y2
	VPSRLDQ $4, X0, X0
	VPADDQ 1*32(DI), Y2, Y2

	VPMOVZXBQ X0, Y3
	VPSRLDQ $4, X0, X0
	VPADDQ Y3, Y1, Y1

	VPMOVZXBQ X0, Y3
	VPSRLDQ $4, X0, X0
	VPADDQ Y3, Y2, Y2

	VPMOVZXBQ X0, Y3
	VPSRLDQ $4, X0, X0
	VPADDQ Y3, Y1, Y1

	VPMOVZXBQ X0, Y3
	VPSRLDQ $4, X0, X0
	VPADDQ Y3, Y2, Y2

	VPMOVZXBQ X0, Y3
	VPSRLDQ $4, X0, X0
	VPADDQ Y3, Y1, Y1

	VPMOVZXBQ X0, Y3
	VPADDQ Y3, Y2, Y2

	// write counters back
	VMOVDQU Y1, 0*32(DI)
	VMOVDQU Y2, 1*32(DI)

	VZEROUPPER
	RET
