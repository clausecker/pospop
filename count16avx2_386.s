// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

#include "textflag.h"

// 16 bit positional population count using AVX2.
// Processes 480 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: AVX2.

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	VPAND A, B, D \
	VPXOR A, B, A \
	VPAND A, C, B \
	VPXOR A, C, A \
	VPOR B, D, B

// magic transposition constants, comparison constants
DATA magic<>+ 0(SB)/8, $0x8040201008040201
DATA magic<>+ 8(SB)/2, $0x0f0f
DATA magic<>+10(SB)/2, $0x00aa
DATA magic<>+12(SB)/4, $0x0000cccc
DATA magic<>+16(SB)/4, $0x01010101
GLOBL magic<>(SB), RODATA|NOPTR, $20

// pseudo-transpose the 4Y8 bit matrices in Y.  Transforms
// Y = D7D6D5D4 D3D2D1D0 C7C6C5C4 C3C2C1C0 B7B6B5B4 B3B2B1B0 A7A6A5A4 A3A2A1A0
// to  D7C7B7A7 D3C3B3A3 D6C6B6A6 D2C2B2A2 D5C5B5A5 D1C1B1A1 D4C4B4A4 D0C0B0A0
// requires magic constants 0x00aa00aa in Y6 and 0x0000cccc in Y7
#define TRANSPOSE(Y) \
	BITPERMUTE(Y, Y6, $7) \
	BITPERMUTE(Y, Y7, $14)

// swap the bits of Y selected by mask M with those S bits to the left.
// uses Y4 as a temporary register
#define BITPERMUTE(Y, M, S) \
	VPSRLD S, Y, Y4 \
	VPXOR Y, Y4, Y4 \
	VPAND Y4, M, Y4 \
	VPXOR Y, Y4, Y \
	VPSLLD S, Y4, Y4 \
	VPXOR Y, Y4, Y

// func count16avx2(counts *[16]int, buf []uint8)
TEXT ·count16avx2(SB),NOSPLIT,$0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), CX		// CX = len(buf)

	SUBL $15*(32/2), CX		// pre-decrement CX
	JL end15

vec15:	VMOVDQU 0*32(SI), Y0		// load 240 bytes from buf
	VMOVDQU 1*32(SI), Y1		// and sum them into Y3:Y2:Y1:Y0
	VMOVDQU 2*32(SI), Y4
	VMOVDQU 3*32(SI), Y2
	VMOVDQU 4*32(SI), Y3
	VMOVDQU 5*32(SI), Y5
	VMOVDQU 6*32(SI), Y6
	CSA(Y0, Y1, Y4, Y7)
	VMOVDQU 7*32(SI), Y4
	CSA(Y3, Y2, Y5, Y7)
	VMOVDQU 8*32(SI), Y5
	CSA(Y0, Y3, Y6, Y7)
	VMOVDQU 9*32(SI), Y6
	CSA(Y1, Y2, Y3, Y7)
	VMOVDQU 10*32(SI), Y3
	CSA(Y0, Y4, Y5, Y7)
	VMOVDQU 11*32(SI), Y5
	CSA(Y0, Y3, Y6, Y7)
	VMOVDQU 12*32(SI), Y6
	CSA(Y1, Y3, Y4, Y7)
	VMOVDQU 13*32(SI), Y4
	CSA(Y0, Y5, Y6, Y7)
	VMOVDQU 14*32(SI), Y6
	CSA(Y0, Y4, Y6, Y7)
	CSA(Y1, Y4, Y5, Y7)
	CSA(Y2, Y3, Y4, Y7)

	ADDL $15*32, SI
#define D	75
	PREFETCHT0 (D+ 0)*32(SI)
	PREFETCHT0 (D+ 2)*32(SI)
	PREFETCHT0 (D+ 4)*32(SI)
	PREFETCHT0 (D+ 6)*32(SI)
	PREFETCHT0 (D+ 8)*32(SI)
	PREFETCHT0 (D+12)*32(SI)
	PREFETCHT0 (D+16)*32(SI)

	// load magic constants
	VPBROADCASTW magic<>+ 8(SB), Y5	// low nibbles
	VPBROADCASTW magic<>+10(SB), Y6	// for TRANSPOSE
	VPBROADCASTD magic<>+12(SB), Y7	// for TRANSPOSE

	// shuffle registers such that Y3:Y2:Y1:Y0 contains dwords
	// of the form 0YDDCCBBAA
	VPUNPCKHBW Y3, Y2, Y4		// Y4 = DDCCDDCC (hi)
	VPUNPCKLBW Y3, Y2, Y2		// Y2 = DDCCDDCC (lo)
	VPUNPCKHBW Y1, Y0, Y3		// Y3 = BBAABBAA (hi)
	VPUNPCKLBW Y1, Y0, Y0		// Y0 = BBAABBAA (lo)
	VPUNPCKHWD Y2, Y0, Y1		// Y1 = DDCCBBAA (1)
	VPUNPCKLWD Y2, Y0, Y0		// Y0 = DDCCBBAA (0)
	VPUNPCKLWD Y4, Y3, Y2		// Y2 = DDCCBBAA (2)
	VPUNPCKHWD Y4, Y3, Y3		// Y3 = DDCCBBAA (3)

	// pseudo-transpose the 8Y4 bit matriY in each dword
	TRANSPOSE(Y0)
	TRANSPOSE(Y1)
	TRANSPOSE(Y2)
	TRANSPOSE(Y3)

	// pull out low nibbles from matrices
	VPAND Y0, Y5, Y4
	VPSRLD $4, Y0, Y0

	VPAND Y1, Y5, Y6
	VPSRLD $4, Y1, Y1
	VPADDB Y4, Y6, Y4

	VPAND Y2, Y5, Y6
	VPSRLD $4, Y2, Y2

	VPAND Y3, Y5, Y7
	VPSRLD $4, Y3, Y3

	VPADDB Y7, Y6, Y6
	VPADDB Y6, Y4, Y4	// Y4 = ba98:3210:ba98:3210

	// load counters
	VMOVDQU 0*4(DI), Y6
	VMOVDQU 8*4(DI), Y7

	// pull out high nibbles from matrices
	VPAND Y5, Y0, Y0
	VPAND Y5, Y1, Y1
	VPADDB Y0, Y1, Y1
	VPAND Y5, Y2, Y2
	VPAND Y5, Y3, Y3
	VPADDB Y2, Y3, Y3
	VPADDB Y3, Y1, Y1	// Y1 = fedc:7654:fedc:7654

	// merge counters and sum
	VPUNPCKHDQ Y1, Y4, Y0
	VPUNPCKLDQ Y1, Y4, Y4
	VPADDB Y4, Y0, Y0	// Y0 = fedc:ba98:7654:3210

	// fold over high half
	VEXTRACTI128 $1, Y0, X1
	VPADDB X1, X0, X0

	// zero extend to dwords and add to counters
	VPMOVZXBD X0, Y1
	VPSRLDQ $8, X0, X0
	VPADDD Y1, Y6, Y6
	VPMOVZXBD X0, Y1
	VPADDD Y1, Y7, Y7

	// write counters back
	VMOVDQU Y6, 0*4(DI)
	VMOVDQU Y7, 8*4(DI)

	SUBL $15*(32/2), CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBL $1-15*(32/2), CX		// undo last subtraction and
	JL end1				// pre-subtract 1 word from CX

	// scalar tail: process two bytes at a time
	VPXOR X0, X0, X0		// Y1: 16 byte sized counters
	VPBROADCASTQ magic<>+0(SB), X2	// Y2: mask of bits positions
	VMOVD magic<>+16(SB), X3	// X3: permutation vector for the word loaded
	VPSHUFD $0x05, X3, X3

	VMOVDQU 0*4(DI), Y6		// counters  0-- 7
	VMOVDQU 8*4(DI), Y7		// counters  8--15

scalar:	VPBROADCASTW (SI), X1
	ADDL $2, SI			// advance buffer past the loaded bytes
	VPSHUFB X3, X1, X1		// shuffle high byte into high qword, low byte into low qword
	VPAND X2, X1, X1		// mask out the desired bytes
	VPCMPEQB X2, X1, X1		// set byte to -1 if corresponding bit set
	VPSUBB X1, X0, X0		// and subtract from the counters

	SUBL $1, CX			// decrement counter and loop
	JGE scalar

	// zero extend to dwords and add to counters
	VPMOVZXBD X0, Y1
	VPSRLDQ $8, X0, X0
	VPADDD Y1, Y6, Y6
	VPMOVZXBD X0, Y1
	VPADDD Y1, Y7, Y7

	// write counters back
	VMOVDQU Y6, 0*4(DI)
	VMOVDQU Y7, 8*4(DI)

end1:	VZEROUPPER
	RET
