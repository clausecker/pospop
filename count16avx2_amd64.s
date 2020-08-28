// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

#include "textflag.h"

// 16 bit positional population count using AVX-2.
// Processes 480 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: AVX2

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	VPAND A, B, D \
	VPXOR A, B, A \
	VPAND A, C, B \
	VPXOR A, C, A \
	VPOR  B, D, B

// magic transposition constants, comparison constants
DATA magic<>+ 0(SB)/8, $0x8040201008040201
DATA magic<>+ 8(SB)/4, $0x00aa00aa
DATA magic<>+12(SB)/4, $0x0000cccc
DATA magic<>+16(SB)/4, $0x0f0f0f0f
DATA magic<>+20(SB)/4, $0x01010101
GLOBL magic<>(SB), RODATA|NOPTR, $24

// pseudo-transpose the 4x8 bit matrices in Y.  Transforms
// Y = D7D6D5D4 D3D2D1D0 C7C6C5C4 C3C2C1C0 B7B6B5B4 B3B2B1B0 A7A6A5A4 A3A2A1A0
// to  D7C7B7A7 D3C3B3A3 D6C6B6A6 D2C2B2A2 D5C5B5A5 D1C1B1A1 D4C4B4A4 D0C0B0A0
// requires magic constants 0x00aa00aa in Y14 and 0x0000cccc in Y15
#define TRANSPOSE(Y) \
	BITPERMUTE(Y, Y14, $7) \
	BITPERMUTE(Y, Y15, $14)

// swap the bits of Y selected by mask M with those S bits to the left
#define BITPERMUTE(Y, M, S) \
	VPSRLD S, Y, Y12 \
	VPXOR Y, Y12, Y12 \
	VPAND Y12, M, Y12 \
	VPXOR Y, Y12, Y \
	VPSLLD S, Y12, Y12 \
	VPXOR Y, Y12, Y

// func count8avx2(counts *[16]int, buf []uint16)
TEXT ·count16avx2(SB),NOSPLIT,$0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)

	// counters, 4 in each register
	VMOVDQU 0*32(DI), Y8
	VMOVDQU 1*32(DI), Y9
	VMOVDQU 2*32(DI), Y10
	VMOVDQU 3*32(DI), Y11

	SUBQ $15*32/2, CX			// pre-decrement CX
	JL end15

	VPBROADCASTD magic<>+ 8(SB), Y14	// for TRANSPOSE
	VPBROADCASTD magic<>+12(SB), Y15	// for TRANSPOSE
	VPBROADCASTD magic<>+16(SB), Y13	// low nibbles

vec15:	VMOVDQU 0*32(SI), Y0		// load 480 bytes from buf
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

	// shuffle registers such that Y3:Y2:Y1:Y0 contains dwords
	// of the form 0xDDCCBBAA
	VPUNPCKLBW Y1, Y0, Y4		// Y4 = BBAABBAA (lo)
	VPUNPCKHBW Y1, Y0, Y5		// Y5 = BBAABBAA (hi)
	VPUNPCKLBW Y3, Y2, Y6		// Y6 = DDCCDDCC (lo)
	VPUNPCKHBW Y3, Y2, Y7		// Y7 = DDCCDDCC (hi)
	VPUNPCKLWD Y6, Y4, Y0		// Y0 = DDCCBBAA (0)
	VPUNPCKHWD Y6, Y4, Y1		// Y1 = DDCCBBAA (1)
	VPUNPCKLWD Y7, Y5, Y2		// Y2 = DDCCBBAA (2)
	VPUNPCKHWD Y7, Y5, Y3		// Y3 = DDCCBBAA (3)

	// pseudo-transpose the 8x4 bit matrix in each dword
	TRANSPOSE(Y0)
	TRANSPOSE(Y1)
	TRANSPOSE(Y2)
	TRANSPOSE(Y3)

	// pull out low nibbles from matrices
	VPAND Y0, Y13, Y4
	VPSRLD $4, Y0, Y0
	VPAND Y1, Y13, Y5
	VPSRLD $4, Y1, Y1
	VPADDB Y4, Y5, Y4
	VPAND Y2, Y13, Y6
	VPSRLD $4, Y2, Y2
	VPAND Y3, Y13, Y7
	VPSRLD $4, Y3, Y3
	VPADDB Y6, Y7, Y6
	VPADDB Y4, Y6, Y6	// Y6 = ba98:3210:ba98:3210:ba98:3210:ba98:3210

	// pull out high nibbles from matrices
	VPAND Y0, Y13, Y0
	VPAND Y1, Y13, Y1
	VPADDB Y0, Y1, Y4
	VPAND Y2, Y13, Y2
	VPAND Y3, Y13, Y3
	VPADDB Y2, Y3, Y5
	VPADDB Y4, Y5, Y4	// Y4 = fedc:7654:fedc:7654:fedc:7654:fedc:7654

	VPUNPCKLDQ Y4, Y6, Y0
	VPUNPCKHDQ Y4, Y6, Y1
	VPADDB Y0, Y1, Y0	// Y0 = fedc:ba98:7654:3210:fedc:ba98:7654:3210
	VEXTRACTI128 $1, Y0, X1	// X1 =                     fedc:ba98:7654:3210
	VPADDB X1, X0, X0	// X0 =                     fedc:ba98:7654:3210

        // add to counters
	VPMOVZXBQ X0, Y1
	VPSRLDQ $8, X0, X2
	VPSRLDQ $4, X0, X0
	VPADDQ Y1, Y8, Y8

	VPMOVZXBQ X0, Y1
	VPADDQ Y1, Y9, Y9

	VPMOVZXBQ X2, Y1
	VPSRLDQ $4, X2, X2
	VPADDQ Y1, Y10, Y10

	VPMOVZXBQ X2, Y1
	VPADDQ Y1, Y11, Y11

	SUBQ $15*(32/2), CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBQ $(2/2)-15*(32/2), CX	// undo last subtraction and
	JL end1				// pre-subtract 2 byte from CX

	// scalar tail: process two bytes at a time
	VPXOR X0, X0, X0		// X1: 16 byte sized counters
	VPBROADCASTQ magic<>+0(SB), X2	// X2: mask of bits positions
	VMOVD magic<>+20(SB), X3	// X3: permutation vector to broadcast
	VPSHUFD $0x05, X3, X3		// one byte into low 8 bytes and another
					// bytes into the high 8 bytes

scalar:	VPBROADCASTW (SI), X1		// load two bytes from the buffer
	ADDQ $2, SI			// advance buffer past the loaded bytes
	VPSHUFB X3, X1, X1		// shuffle them around as needed
	VPAND X2, X1, X1		// mask out the desired bytes
	VPCMPEQB X2, X1, X1		// set byte to -1 if corresponding bit set
	VPSUBB X1, X0, X0		// and subtract from the counters

	SUBQ $1, CX			// decrement counter and loop
	JGE scalar

	// add to counters
	VPMOVZXBQ X0, Y1
	VPSRLDQ $8, X0, X2
	VPSRLDQ $4, X0, X0
	VPADDQ Y1, Y8, Y8

	VPMOVZXBQ X0, Y1
	VPADDQ Y1, Y9, Y9

	VPMOVZXBQ X2, Y1
	VPSRLDQ $4, X2, X2
	VPADDQ Y1, Y10, Y10

	VPMOVZXBQ X2, Y1
	VPADDQ Y1, Y11, Y11

	// write counters back
end1:	VMOVDQU Y8, 0*32(DI)
	VMOVDQU Y9, 1*32(DI)
	VMOVDQU Y10, 2*32(DI)
	VMOVDQU Y11, 3*32(DI)

	VZEROUPPER
	RET
