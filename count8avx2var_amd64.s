// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

// +build ignore

#include "textflag.h"

// 8 bit positional population count using AVX-2.
// Processes 480 bytes at a time using a 15-fold
// carry-save-adder reduction followed by a series
// of bit matrix transpositions.  This kernel is
// not used as it is slightly slower than the
// VPMOVMSKB variant.
// Required feature flags: AVX2

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

// magic transposition constants
DATA magic<>+0(SB)/4, $0x00aa00aa
DATA magic<>+4(SB)/4, $0x0000cccc
DATA magic<>+8(SB)/4, $0x0f0f0f0f
GLOBL magic<>(SB), RODATA|NOPTR, $12

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

// func count8avx2(counts *[8]int, buf []byte)
TEXT ·count8avx2(SB),NOSPLIT,$0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)

	// load counts into register R8--R15
	MOVQ 8*0(DI), R8
	MOVQ 8*1(DI), R9
	MOVQ 8*2(DI), R10
	MOVQ 8*3(DI), R11
	MOVQ 8*4(DI), R12
	MOVQ 8*5(DI), R13
	MOVQ 8*6(DI), R14
	MOVQ 8*7(DI), R15

	SUBQ $15*32, CX			// pre-decrement CX
	JL end15

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

#define D	50
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

	VPBROADCASTD magic<>+0(SB), Y14	// for TRANSPOSE
	VPBROADCASTD magic<>+4(SB), Y15	// for TRANSPOSE
	VPBROADCASTD magic<>+8(SB), Y13	// low nibbles

	// Y4:Y3:Y1:Y0 = Y0+Y1+...+Y14

	// shuffle registers such that Y3:Y2:Y1:Y0 contains dwords
	// of the form 0xDDCCBBAA
	VPUNPCKLBW Y4, Y3, Y6		// Y6 = DDCCDDCC (lo)
	VPUNPCKHBW Y4, Y3, Y7		// Y7 = DDCCDDCC (hi)
	VPUNPCKLBW Y1, Y0, Y4		// Y4 = BBAABBAA (lo)
	VPUNPCKHBW Y1, Y0, Y5		// Y5 = BBAABBAA (hi)
	VPUNPCKLWD Y6, Y4, Y0		// Y0 = DDCCBBAA (0)
	VPUNPCKHWD Y6, Y4, Y1		// Y1 = DDCCBBAA (1)
	VPUNPCKLWD Y7, Y5, Y2		// Y2 = DDCCBBAA (2)
	VPUNPCKHWD Y7, Y5, Y3		// Y3 = DDCCBBAA (3)

	// pseudo-transpose the 8x4 bit matrix in each dword
	TRANSPOSE(Y0)
	TRANSPOSE(Y1)
	TRANSPOSE(Y2)
	TRANSPOSE(Y3)

	// pull out the low halves and sum them up into Y4
	// then right-shift high halves for further summing
	VPAND Y0, Y13, Y4
	VPSRLD $4, Y0, Y0
	VPAND Y1, Y13, Y5
	VPSRLD $4, Y1, Y1
	VPADDB Y4, Y5, Y4
	VPAND Y2, Y13, Y5
	VPSRLD $4, Y2, Y2
	VPADDB Y4, Y5, Y4
	VPAND Y3, Y13, Y5
	VPSRLD $4, Y3, Y3
	VPADDB Y4, Y5, Y4

	// pull out high halves and sum them up into Y0
	VPAND Y0, Y13, Y0
	VPAND Y1, Y13, Y1
	VPADDB Y0, Y1, Y0
	VPAND Y2, Y13, Y2
	VPAND Y3, Y13, Y3
	VPADDB Y2, Y3, Y2
	VPADDB Y0, Y2, Y0

	// join the two together with horizontal sums
	VPHADDD Y0, Y4, Y0	// Y0 = 7654:7654:3210:3210:7654:7654:3210:3210
	VEXTRACTI128 $1, Y0, X1	// X1 =                     7654:7654:3210:3210
	VPHADDD X0, X1, X0	// X0 =                     7654:3210:7654:3210
	VPMOVZXBW X0, Y0	// Y0 =                     7654:3210:7654:3210
	VEXTRACTI128 $1, Y0, X1	// X1 =                               7654:3210
	VPADDW X0, X1, X0	// X0 =                               7654:3210

	// add to counters
	VPEXTRW $0, X0, AX
	ADDQ AX, R8
	VPEXTRW $1, X0, AX
	ADDQ AX, R9
	VPEXTRW $2, X0, AX
	ADDQ AX, R10
	VPEXTRW $3, X0, AX
	ADDQ AX, R11
	VPEXTRW $4, X0, AX
	ADDQ AX, R12
	VPEXTRW $5, X0, AX
	ADDQ AX, R13
	VPEXTRW $6, X0, AX
	ADDQ AX, R14
	VPEXTRW $7, X0, AX
	ADDQ AX, R15

	SUBQ $15*32, CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBQ $-14*32, CX		// undo last subtraction and
					// pre-subtract 32 bit from CX
	JL end1

vec1:	VMOVDQU (SI), Y0		// load 32 bytes from buf
	ADDQ $32, SI			// advance SI past them

	COUNTS(Y0, AX)
	ADDQ AX, R15

	COUNTS(Y0, AX)
	ADDQ AX, R14

	COUNTS(Y0, AX)
	ADDQ AX, R13

	COUNTS(Y0, AX)
	ADDQ AX, R12

	COUNTS(Y0, AX)
	ADDQ AX, R11

	COUNTS(Y0, AX)
	ADDQ AX, R10

	COUNTS(Y0, AX)
	ADDQ AX, R9

	COUNT(Y0, AX)
	ADDQ AX, R8

	SUBQ $32, CX
	JGE vec1			// repeat as long as bytes are left

end1:	VZEROUPPER			// restore SSE-compatibility
	SUBQ $-32, CX			// undo last subtraction
	JLE end				// if CX<=0, there's nothing left

scalar:	MOVBLZX (SI), AX		// load a byte from buf
	INCQ SI				// advance past it

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R8			// add it to R8

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R9			// add it to R9

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R10			// add it to R10

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R11			// add it to R11

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R12			// add it to R12

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R13			// add it to R13

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R14			// add it to R14

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R15			// add it to R15

	DECQ CX				// mark this byte as done
	JNE scalar			// and proceed if any bytes are left

	// write R8--R15 back to counts
end:	MOVQ R8, 8*0(DI)
	MOVQ R9, 8*1(DI)
	MOVQ R10, 8*2(DI)
	MOVQ R11, 8*3(DI)
	MOVQ R12, 8*4(DI)
	MOVQ R13, 8*5(DI)
	MOVQ R14, 8*6(DI)
	MOVQ R15, 8*7(DI)

	RET
