#include "textflag.h"

// 16 bit positional population count using SSE2.
// Processes 240 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: SSE2.

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	MOVOA A, D \
	PAND B, D \
	PXOR B, A \
	MOVOA A, B \
	PAND C, B \
	PXOR C, A \
	POR D, B

// magic transposition constants, comparison constants
DATA magic<>+ 0(SB)/8, $0x0f0f0f0f0f0f0f0f
DATA magic<>+ 8(SB)/8, $0x00aa00aa00aa00aa
DATA magic<>+16(SB)/8, $0x0000cccc0000cccc
DATA magic<>+24(SB)/8, $0x8040201008040201
GLOBL magic<>(SB), RODATA|NOPTR, $32

// pseudo-transpose the 4x8 bit matrices in Y.  Transforms
// Y = D7D6D5D4 D3D2D1D0 C7C6C5C4 C3C2C1C0 B7B6B5B4 B3B2B1B0 A7A6A5A4 A3A2A1A0
// to  D7C7B7A7 D3C3B3A3 D6C6B6A6 D2C2B2A2 D5C5B5A5 D1C1B1A1 D4C4B4A4 D0C0B0A0
// requires magic constants 0x00aa00aa in X6 and 0x0000cccc in X7
#define TRANSPOSE(Y) \
	BITPERMUTE(Y, X6, $7) \
	BITPERMUTE(Y, X7, $14)

// swap the bits of Y selected by mask M with those S bits to the left.
// uses X4 as a temporary register
#define BITPERMUTE(Y, M, S) \
	MOVOA Y, X4 \
	PSRLL S, X4 \
	PXOR Y, X4 \
	PAND M, X4 \
	PXOR X4, Y \
	PSLLL S, X4 \
	PXOR X4, Y

// func count16sse2(counts *[16]int, buf []uint8)
TEXT ·count16sse2(SB),NOSPLIT,$0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), CX		// CX = len(buf)

	SUBL $15*(16/2), CX		// pre-decrement CX
	JL end15

vec15:	MOVOU 0*16(SI), X0		// load 240 bytes from buf
	MOVOU 1*16(SI), X1		// and sum them into Y3:Y2:Y1:Y0
	MOVOU 2*16(SI), X4
	MOVOU 3*16(SI), X2
	MOVOU 4*16(SI), X3
	MOVOU 5*16(SI), X5
	MOVOU 6*16(SI), X6
	CSA(X0, X1, X4, X7)
	MOVOU 7*16(SI), X4
	CSA(X3, X2, X5, X7)
	MOVOU 8*16(SI), X5
	CSA(X0, X3, X6, X7)
	MOVOU 9*16(SI), X6
	CSA(X1, X2, X3, X7)
	MOVOU 10*16(SI), X3
	CSA(X0, X4, X5, X7)
	MOVOU 11*16(SI), X5
	CSA(X0, X3, X6, X7)
	MOVOU 12*16(SI), X6
	CSA(X1, X3, X4, X7)
	MOVOU 13*16(SI), X4
	CSA(X0, X5, X6, X7)
	MOVOU 14*16(SI), X6
	CSA(X0, X4, X6, X7)
	CSA(X1, X4, X5, X7)
	CSA(X2, X3, X4, X7)

	ADDL $15*16, SI
#define D	90
	PREFETCHT0 (D+ 0)*16(SI)
	PREFETCHT0 (D+ 4)*16(SI)
	PREFETCHT0 (D+ 8)*16(SI)
	PREFETCHT0 (D+12)*16(SI)

	// load magic constants
	MOVQ magic<>+ 0(SB), X5		// low nibbles
	MOVQ magic<>+ 8(SB), X6		// for TRANSPOSE
	MOVQ magic<>+16(SB), X7		// for TRANSPOSE

	// broadcast constants to 128 bit
	PUNPCKLLQ X5, X5
	PUNPCKLLQ X6, X6
	PUNPCKLLQ X7, X7

	// shuffle registers such that X3:X2:X1:X0 contains dwords
	// of the form 0xDDCCBBAA
	MOVOU X2, X4
	PUNPCKLBW X3, X2		// X2 = DDCCDDCC (lo)
	PUNPCKHBW X3, X4		// X5 = DDCCDDCC (hi)
	MOVOU X0, X3
	PUNPCKLBW X1, X0		// X0 = BBAABBAA (lo)
	PUNPCKHBW X1, X3		// X3 = BBAABBAA (hi)
	MOVOU X0, X1
	PUNPCKLWL X2, X0		// X0 = DDCCBBAA (0)
	PUNPCKHWL X2, X1		// X1 = DDCCBBAA (1)
	MOVOU X3, X2
	PUNPCKLWL X4, X2		// X2 = DDCCBBAA (2)
	PUNPCKHWL X4, X3		// X3 = DDCCBBAA (3)

	// pseudo-transpose the 8x4 bit matrix in each dword
	TRANSPOSE(X0)
	TRANSPOSE(X1)
	TRANSPOSE(X2)
	TRANSPOSE(X3)

	// pull out low nibbles from matrices
	MOVOA X0, X4
	PAND X5, X4
	PSRLL $4, X0

	MOVOU X1, X6
	PAND X5, X6
	PSRLL $4, X1
	PADDB X6, X4

	MOVOU X2, X6
	PAND X5, X6
	PSRLL $4, X2

	MOVOU X3, X7
	PAND X5, X7
	PSRLL $4, X3

	PADDB X7, X6
	PADDB X6, X4		// X4 = ba98:3210:ba98:3210

	// load low counters counters
	MOVOU 0*4(DI), X6
	MOVOU 4*4(DI), X7

	// pull out high nibbles from matrices
	PAND X5, X0
	PAND X5, X1
	PADDB X0, X1
	PAND X5, X2
	PAND X5, X3
	PADDB X2, X3
	PADDB X3, X1		// X1 = fedc:7654:fedc:7654

	// load high counters
	MOVOU 8*4(DI), X3
	MOVOU 12*4(DI), X5

	// merge counters and sum
	MOVOA X4, X0
	PUNPCKLLQ X1, X0
	PUNPCKHLQ X1, X4
	PADDB X4, X0		// X0 = fedc:ba98:7654:3210

	// zero extend X0 to words X1:X0
	PXOR X4, X4		// zero register
	MOVOA X0, X1
	PUNPCKLBW X4, X0
	PUNPCKHBW X4, X1

	// zero extend X0 to X2:X0 and add to X6:X7
	MOVOA X0, X2
	PUNPCKLWL X4, X0
	PUNPCKHWL X4, X2
	PADDL X0, X6
	PADDL X2, X7

	// write low counters back
	MOVOU X6, 0*4(DI)
	MOVOU X7, 4*4(DI)

	// zero extend X1 to X2:X1 and add to X3:X5
	MOVOA X1, X2
	PUNPCKLWL X4, X1
	PUNPCKHWL X4, X2
	PADDL X1, X3
	PADDL X2, X5

	// write high counters back
	MOVOU X3, 8*4(DI)
	MOVOU X5, 12*4(DI)

	SUBL $15*(16/2), CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBL $1-15*(16/2), CX		// undo last subtraction and
	JL end1				// pre-subtract 1 word from CX

	// scalar tail: process two bytes at a time
	PXOR X0, X0			// X1: 16 byte sized counters
	MOVQ magic<>+24(SB), X2		// X2: mask of bits positions
	PUNPCKLQDQ X2, X2

	MOVOU 0*4(DI), X6		// counters  0-- 3
	MOVOU 4*4(DI), X7		// counters  4-- 7
	MOVOU 8*4(DI), X3		// counters  8--11
	MOVOU 12*4(DI), X5		// coutners 12--15

scalar:	MOVWLZX (SI), AX		// load one byte from the buffer
	ADDL $2, SI			// advance buffer past the loaded bytes
	MOVL AX, X1			// into an SSE register
	PUNPCKLBW X1, X1		// double bytes into words
	PUNPCKLWL X1, X1		// double words into dwords
	PSHUFL $0x50, X1, X1		// high word goes into high qword, low into low qword
	PAND X2, X1			// mask out the desired bytes
	PCMPEQB X2, X1			// set byte to -1 if corresponding bit set
	PSUBB X1, X0			// and subtract from the counters

	SUBL $1, CX			// decrement counter and loop
	JGE scalar

	// zero extend X0 to words X1:X0
	PXOR X4, X4		// zero register
	MOVOA X0, X1
	PUNPCKLBW X4, X0
	PUNPCKHBW X4, X1

	// zero extend X0 to X2:X0 and add to X6:X7
	MOVOA X0, X2
	PUNPCKLWL X4, X0
	PUNPCKHWL X4, X2
	PADDL X0, X6
	PADDL X2, X7

	// write low counters back
	MOVOU X6, 0*4(DI)
	MOVOU X7, 4*4(DI)

	// zero extend X1 to X2:X1 and add to X3:X5
	MOVOA X1, X2
	PUNPCKLWL X4, X1
	PUNPCKHWL X4, X2
	PADDL X1, X3
	PADDL X2, X5

	// write high counters back
	MOVOU X3, 8*4(DI)
	MOVOU X5, 12*4(DI)

end1:	RET
