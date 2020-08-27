#include "textflag.h"

// 8 bit positional population count using SSE2.
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
// requires magic constants 0x00aa00aa in Y14 and 0x0000cccc in Y15
#define TRANSPOSE(Y) \
	BITPERMUTE(Y, X14, $7) \
	BITPERMUTE(Y, X15, $14)

// swap the bits of Y selected by mask M with those S bits to the left.
// uses X7 as a temporary register
#define BITPERMUTE(Y, M, S) \
	MOVOA Y, X7 \
	PSRLL S, X7 \
	PXOR Y, X7 \
	PAND M, X7 \
	PXOR X7, Y \
	PSLLL S, X7 \
	PXOR X7, Y

// func count8sse2(counts *[8]int, buf []uint8)
TEXT ·count8sse2(SB),NOSPLIT,$0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)

	// keep counters in registers
	// for better performance
	MOVOU 0*8(DI), X9
	MOVOU 2*8(DI), X10
	MOVOU 4*8(DI), X11
	MOVOU 6*8(DI), X12

	SUBQ $15*16, CX			// pre-decrement CX
	JL end15

	MOVQ magic<>+ 0(SB), X13	// low nibbles
	MOVQ magic<>+ 8(SB), X14	// for TRANSPOSE
	MOVQ magic<>+16(SB), X15	// for TRANSPOSE

	// broadcast constants to 128 bit
	PUNPCKLLQ X14, X14
	PUNPCKLLQ X15, X15
	PUNPCKLLQ X13, X13

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

	ADDQ $15*16, SI
#define D	90
	PREFETCHT0 (D+ 0)*16(SI)
	PREFETCHT0 (D+ 4)*16(SI)
	PREFETCHT0 (D+ 8)*16(SI)
	PREFETCHT0 (D+12)*16(SI)

	// shuffle registers such that X3:X2:X1:X0 contains dwords
	// of the form 0xDDCCBBAA
	MOVOU X2, X5
	PUNPCKLBW X3, X2		// X2 = DDCCDDCC (lo)
	PUNPCKHBW X3, X5		// X5 = DDCCDDCC (hi)
	MOVOU X0, X3
	PUNPCKLBW X1, X0		// X0 = BBAABBAA (lo)
	PUNPCKHBW X1, X3		// X3 = BBAABBAA (hi)
	MOVOU X0, X1
	PUNPCKLWL X2, X0		// X0 = DDCCBBAA (0)
	PUNPCKHWL X2, X1		// X1 = DDCCBBAA (1)
	MOVOU X3, X2
	PUNPCKLWL X5, X2		// X2 = DDCCBBAA (2)
	PUNPCKHWL X5, X3		// X3 = DDCCBBAA (3)

	// pseudo-transpose the 8x4 bit matrix in each dword
	TRANSPOSE(X0)
	TRANSPOSE(X1)
	TRANSPOSE(X2)
	TRANSPOSE(X3)

	// pull out low nibbles from matrices
	MOVOA X0, X4
	PAND X13, X4
	PSRLL $4, X0

	MOVOU X1, X5
	PAND X13, X5
	PSRLL $4, X1
	PADDB X5, X4

	MOVOU X2, X6
	PAND X13, X6
	PSRLL $4, X2

	MOVOU X3, X7
	PAND X13, X7
	PSRLL $4, X3

	PADDB X7, X6
	PADDB X4, X6		// X6 = ba98:3210:ba98:3210

	// pull out high nibbles from matrices
	PAND X13, X0
	PAND X13, X1
	PADDB X0, X1
	PAND X13, X2
	PAND X13, X3
	PADDB X2, X3
	PADDB X3, X1		// X1 = fedc:7654:fedc:7654

	MOVOA X6, X0
	PUNPCKLLQ X1, X0
	PUNPCKHLQ X1, X6
	PADDB X6, X0		// X0 = fedc:ba98:7654:3210

	// sum fedc:ba98 and 7654:3210 and zero extend to words
	PXOR X4, X4		// zero register
	MOVOA X0, X1
	PUNPCKLBW X4, X0
	PUNPCKHBW X4, X1
	PADDB X1, X0		// X0 = 76:54:32:10

        // add to counters

	// zero extend low half word -> dword
	MOVOA X0, X2
	PUNPCKLWL X4, X0
	PUNPCKHWL X4, X2

	// zero extend low dwords -> qwords and add to counters
	MOVOA X0, X3
	PUNPCKLLQ X4, X0
	PUNPCKHLQ X4, X3
	PADDQ X0, X9
	PADDQ X3, X10

	MOVOA X2, X0
	PUNPCKLLQ X4, X0
	PUNPCKHLQ X4, X2
	PADDQ X0, X11
	PADDQ X2, X12

	SUBQ $15*16, CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBQ $1-15*16, CX		// undo last subtraction and
	JL end1				// pre-subtract 2 byte from CX

	// scalar tail: process one byte at a time
	PXOR X0, X0			// X1: 16 byte sized counters
	MOVQ magic<>+24(SB), X2		// X2: mask of bits positions

scalar:	MOVBLZX (SI), AX		// load two bytes from the buffer
	INCQ SI				// advance buffer past the loaded bytes
	MOVD AX, X1			// into an SSE register
	PUNPCKLBW X1, X1		// double byte into words
	PSHUFLW $0x00, X1, X1		// broadcast word into qword
	PAND X2, X1			// mask out the desired bytes
	PCMPEQB X2, X1			// set byte to -1 if corresponding bit set
	PSUBB X1, X0			// and subtract from the counters

	SUBQ $1, CX			// decrement counter and loop
	JGE scalar

	// zero extend to words
	PXOR X4, X4			// zero register
	PUNPCKLBW X4, X0

        // add to counters

	// zero extend low half word -> dword
	MOVOA X0, X2
	PUNPCKLWL X4, X0
	PUNPCKHWL X4, X2

	// zero extend low dwords -> qwords and add to counters
	MOVOA X0, X3
	PUNPCKLLQ X4, X0
	PUNPCKHLQ X4, X3
	PADDQ X0, X9
	PADDQ X3, X10

	MOVOA X2, X0
	PUNPCKLLQ X4, X0
	PUNPCKHLQ X4, X2
	PADDQ X0, X11
	PADDQ X2, X12

	// write counters back
end1:	MOVOU X9, 0*8(DI)
	MOVOU X10, 2*8(DI)
	MOVOU X11, 4*8(DI)
	MOVOU X12, 6*8(DI)

	VZEROUPPER
	RET
