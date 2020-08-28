// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

#include "textflag.h"

// 8 bit positional population count using AVX-2.
// Processes 480 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: POPCNT, AVX2

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
	COUNT(Y3, AX) \
	COUNT(Y2, BX) \
	LEAL (BX)(AX*2), AX \
	COUNT(Y1, BX) \
	COUNT(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDL AX, R

// same as ACCUM, but use COUNTS instead of COUNT
#define ACCUMS(R) \
	COUNTS(Y3, AX) \
	COUNTS(Y2, BX) \
	LEAL (BX)(AX*2), AX \
	COUNTS(Y1, BX) \
	COUNTS(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDL AX, R

// magic constants
DATA magic<>+ 0(SB)/8, $0x0000000000000000
DATA magic<>+ 8(SB)/8, $0x0101010101010101
DATA magic<>+16(SB)/8, $0x0202020202020202
DATA magic<>+24(SB)/8, $0x0303030303030303
DATA magic<>+32(SB)/8, $0x8040201008040201
GLOBL magic<>(SB), RODATA|NOPTR, $40

// func count8avx2(counts *[8]int, buf []byte)
TEXT ·count8avx2(SB),NOSPLIT,$0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), CX		// CX = len(buf)

	SUBL $15*32, CX			// pre-decrement CX
	JL end15

vec15:	VMOVDQU 0*32(SI), Y0		// load 480 bytes from buf
	VMOVDQU 1*32(SI), Y1		// and sum them into Y3:Y2:Y1:Y0
	VMOVDQU 2*32(SI), Y2
	CSA(Y0, Y1, Y2, Y7)

	VMOVDQU 3*32(SI), Y2
	VMOVDQU 4*32(SI), Y3
	VMOVDQU 5*32(SI), Y4
	CSA(Y2, Y3, Y4, Y7)

	VMOVDQU 6*32(SI), Y4
	CSA(Y0, Y2, Y4, Y7)

	VMOVDQU 7*32(SI), Y4
	VMOVDQU 8*32(SI), Y5
	CSA(Y0, Y4, Y5, Y7)
	CSA(Y1, Y2, Y3, Y7)

	VMOVDQU 9*32(SI), Y3
	VMOVDQU 10*32(SI), Y5
	CSA(Y0, Y3, Y5, Y7)
	CSA(Y1, Y3, Y4, Y7)

	VMOVDQU 11*32(SI), Y4
	VMOVDQU 12*32(SI), Y5
	CSA(Y0, Y4, Y5, Y7)

	VMOVDQU 13*32(SI), Y5
	VMOVDQU 14*32(SI), Y6
	CSA(Y0, Y5, Y6, Y7)
	CSA(Y1, Y4, Y5, Y7)
	CSA(Y2, Y3, Y4, Y7)

	ADDL $15*32, SI
#define D	75
	PREFETCHT0 (D+ 0)*32(SI)
	PREFETCHT0 (D+ 2)*32(SI)
	PREFETCHT0 (D+ 4)*32(SI)
	PREFETCHT0 (D+ 6)*32(SI)
	PREFETCHT0 (D+ 8)*32(SI)
	PREFETCHT0 (D+10)*32(SI)
	PREFETCHT0 (D+12)*32(SI)
	PREFETCHT0 (D+14)*32(SI)

	// Y4:Y3:Y1:Y0 = Y0+Y1+...+Y14

	ACCUMS(7*4(DI))
	ACCUMS(6*4(DI))
	ACCUMS(5*4(DI))
	ACCUMS(4*4(DI))
	ACCUMS(3*4(DI))
	ACCUMS(2*4(DI))
	ACCUMS(1*4(DI))
	ACCUM(0*4(DI))

	SUBL $15*32, CX
	JGE vec15			// repeat as long as bytes are left

end15:	VPXOR X0, X0, X0		// Y0: 32 byte sized counters
	VPBROADCASTQ magic<>+32(SB), Y2	// Y2: mask of bits positions

	SUBL $4-15*32, CX		// undo last subtraction and
	JL end4				// pre-subtract 4 bytes from CX

	VMOVDQU magic<>+0(SB), Y3	// Y3: shuffle mask

	// 4 bytes at a time
vec4:	VPBROADCASTD (SI), Y1		// load 4 bytes from the buffer
	ADDL $4, SI			// advance past loaded bytes
	VPSHUFB Y3, Y1, Y1		// shuffle bytes into the right places
	VPAND Y2, Y1, Y1		// mask out the desired bits
	VPCMPEQB Y2, Y1, Y1		// set byte to -1 if corresponding bit set
	VPSUBB Y1, Y0, Y0		// and subtract from the counters

	SUBL $4, CX			// decrement counter and loop
	JGE vec4

end4:	SUBL $1-4, CX			// undo last-subtraction and
	JL end1				// pre-subtract 4 bytes from CX

	VPXOR X3, X3, X3		// X2: counters for the scalar tail

	// scalar tail
scalar:	VPBROADCASTB (SI), X1		// load a byte from the buffer
	INCL SI				// advance buffer past the loaded bytes
	VPAND X2, X1, X1		// mask out the desired bits
	VPCMPEQB X2, X1, X1		// set byte to -1 if corresponding bit set
	VPSUBB X1, X3, X3		// and subtract from the counters
	SUBL $1, CX			// decrement counter and loop
	JGE scalar

	VPSRLDQ $8, X3, X3		// discard low copy of counters
	VPADDB Y3, Y0, Y0		// and add them to the others

	// add to counters
end1:	VMOVDQU (DI), Y2		// load counters
	VEXTRACTI128 $1, Y0, X1		// extract high counter pair
	VPADDB X1, X0, X0		// and fold over low pair

	VPMOVZXBW X0, Y0		// zero extend to words
	VEXTRACTI128 $1, Y0, X1		// extra high counters
	VPADDW X1, X0, X0		// and fold over low counters

	VPMOVZXWD X0, Y0		// zero extend to dwords
	VPADDD Y0, Y2, Y0		// add to counters
	VMOVDQU Y0, (DI)		// and write back

	VZEROUPPER
	RET

