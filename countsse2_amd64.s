#include "textflag.h"

// SSE2 based kernels for the positional population count operation.
// All these kernels have the same backbone based on a 15-fold CSA
// reduction to first reduce 240 byte into 4x16 byte, followed by a
// bunch of shuffles to group the positional registers into nibbles.
// These are then summed up using a width-specific summation function.
// Required CPU extension: SSE2.

// magic transposition constants
DATA magic<> +0(SB)/8, $0x8040201008040201
DATA magic<>+ 8(SB)/4, $0x0000cccc
DATA magic<>+12(SB)/4, $0x00aa00aa
DATA magic<>+16(SB)/4, $0x0f0f0f0f
DATA magic<>+20(SB)/4, $0x00000000	// padding
GLOBL magic<>(SB), RODATA|NOPTR, $24

// sliding window for head/tail loads.  Unfortunately, there doesn't
// seem to be a good way to do this with less memory wasted.
DATA window<> +0(SB)/8, $0x0000000000000000
DATA window<> +8(SB)/8, $0x0000000000000000
DATA window<>+16(SB)/8, $0xffffffffffffffff
DATA window<>+24(SB)/8, $0xffffffffffffffff
GLOBL window<>(SB), RODATA|NOPTR, $32

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	MOVOA A, D \
	PAND B, D \
	PXOR B, A \
	MOVOA A, B \
	PAND C, B \
	PXOR C, A \
	POR D, B

// pseudo-transpose the 4x8 bit matrices in Y.  Transforms
// Y = D7D6D5D4 D3D2D1D0 C7C6C5C4 C3C2C1C0 B7B6B5B4 B3B2B1B0 A7A6A5A4 A3A2A1A0
// to  D7C7B7A7 D3C3B3A3 D6C6B6A6 D2C2B2A2 D5C5B5A5 D1C1B1A1 D4C4B4A4 D0C0B0A0
// requires magic constants 0x00aa00aa in X6 and 0x0000cccc in X5
#define TRANSPOSE(Y) \
	BITPERMUTE(Y, X6, $7) \
	BITPERMUTE(Y, X5, $14)

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

// Process 4 bytes from S.  Add low word counts to L, high to H
// assumes mask loaded into X2.  Trashes X4, X5.
#define COUNT4(L, H, S) \
	MOVD S, X4 \			// X4 = ----:----:----:3210
	PUNPCKLBW X4, X4 \		// X4 = ----:----:3322:1100
	PUNPCKLWL X4, X4 \		// X4 = 3333:2222:1111:0000
	PSHUFD $0xfa, X4, X5 \		// X5 = 3333:3333:2222:2222
	PUNPCKLLQ X4, X4 \		// X5 = 1111:1111:0000:0000
	PAND X6, X4 \
	PAND X6, X5 \
	PCMPEQB X6, X4 \
	PCMPEQB X6, X5 \
	PSUBB X4, L \
	PSUBB X5, H

// zero extend X from bytes into words and add to the counter vectors
// S1 and S2.  X7 is expected to be a zero register, X6 and X are trashed.
#define ACCUM(S1, S2, X) \
	MOVOA X, X6 \
	PUNPCKLBW X7, X \
	PUNPCKHBW X7, X6 \
	PADDW X, S1 \
	PADDW X6, S2

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation funciton in BX, a possibly unaligned input buffer in SI,
// counters in DI and a remaining length in CX.
TEXT countsse<>(SB), NOSPLIT, $0-0
	TESTQ CX, CX			// any data to process at all?
	CMOVQEQ CX, SI			// if not, avoid loading head

	// constants for processing the head
	MOVQ magic<>+0(SB), X6		// bit position mask
	PSHUFD $0x44, X6, X6		// broadcast into both qwords
	PXOR X7, X7			// zero register
	PXOR X8, X8			// counter registers
	PXOR X10, X10
	PXOR X12, X12
	PXOR X14, X14

	// load head into scratch space (until alignment/end is reached)
	MOVL SI, DX
	ANDL $15, DX			// offset of the buffer start from 16 byte alignment
	JEQ nohead			// if source buffer is aligned, skip head processing
	MOVL $16, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	MOVOA -16(SI)(AX*1), X3		// load head
	LEAQ window<>(SB), DX		// load window mask base pointer
	MOVOU (DX)(AX*1), X5		// load mask of the bytes that are part of the head
	PAND X5, X3			// and mask out those bytes that are not
	CMPQ AX, CX			// is the head shorter than the buffer?
	JLT norunt

	// buffer is short and does not cross a 16 byte boundary
	SUBL CX, AX			// number of bytes by which we overshoot the buffer
	MOVOU (DX)(AX*1), X5		// load mask of bytes that overshoot the buffer
	PANDN X3, X5			// and clear them
	MOVOA X5, X3			// move head buffer back to X4
	MOVL CX, AX			// set up true prefix length

norunt:	SUBQ AX, CX			// mark head as accounted for
	ADDQ AX, SI			// and advance past the head

	// process head in four increments of 4 bytes
	COUNT4(X8, X10, X3)
	PSRLO $4, X3
	COUNT4(X12, X14, X3)
	PSRLO $4, X3
	COUNT4(X8, X10, X3)
	PSRLO $4, X3
	COUNT4(X12, X14, X3)

	// initialise counters in X8--X15 to what we have
nohead:	MOVOA X8, X9
	PUNPCKLBW X7, X8
	PUNPCKHBW X7, X9
	MOVOA X10, X11
	PUNPCKLBW X7, X10
	PUNPCKHBW X7, X11
	MOVOA X12, X13
	PUNPCKLBW X7, X12
	PUNPCKHBW X7, X13
	MOVOA X14, X15
	PUNPCKLBW X7, X14
	PUNPCKHBW X7, X15

	SUBQ $15*16, CX			// enough data left to process?
	JLT endvec			// also, pre-subtract

	MOVL $65535-4, AX		// space left til overflow could occur in Y8--Y11

vec:	MOVOA 0*16(SI), X0		// load 240 bytes from buf
	MOVOA 1*16(SI), X1		// and sum them into Y3:Y2:Y1:Y0
	MOVOA 2*16(SI), X4
	MOVOA 3*16(SI), X2
	MOVOA 4*16(SI), X3
	MOVOA 5*16(SI), X5
	MOVOA 6*16(SI), X6
	CSA(X0, X1, X4, X7)
	MOVOA 7*16(SI), X4
	CSA(X3, X2, X5, X7)
	MOVOA 8*16(SI), X5
	CSA(X0, X3, X6, X7)
	MOVOA 9*16(SI), X6
	CSA(X1, X2, X3, X7)
	MOVOA 10*16(SI), X3
	CSA(X0, X4, X5, X7)
	MOVOA 11*16(SI), X5
	CSA(X0, X3, X6, X7)
	MOVOA 12*16(SI), X6
	CSA(X1, X3, X4, X7)
	MOVOA 13*16(SI), X4
	CSA(X0, X5, X6, X7)
	MOVOA 14*16(SI), X6
	CSA(X0, X4, X6, X7)
	CSA(X1, X4, X5, X7)
	CSA(X2, X3, X4, X7)

	// load magic constants
	MOVOU magic<>+8(SB), X7
	PSHUFD $0x00, X7, X5		// 0x0000cccc for transposition
	PSHUFD $0x55, X7, X6		// 0x00aa00aa for transposition
	PSHUFD $0xaa, X7, X7		// 0x0f0f0f0f for deinterleaving the nibbles

	ADDQ $15*16, SI
#define D	90
	PREFETCHT0 (D+ 0)*16(SI)
	PREFETCHT0 (D+ 4)*16(SI)
	PREFETCHT0 (D+ 8)*16(SI)
	PREFETCHT0 (D+12)*16(SI)

	// shuffle registers such that X3:X2:X1:X0 contains dwords
	// of the form 0xDDCCBBAA
	MOVOA X2, X4
	PUNPCKLBW X3, X2		// X2 = DDCCDDCC (lo)
	PUNPCKHBW X3, X4		// X4 = DDCCDDCC (hi)
	MOVOA X0, X3
	PUNPCKLBW X1, X0		// X0 = BBAABBAA (lo)
	PUNPCKHBW X1, X3		// X3 = BBAABBAA (hi)
	MOVOA X0, X1
	PUNPCKLWL X2, X0		// X0 = DDCCBBAA (0)
	PUNPCKHWL X2, X1		// X1 = DDCCBBAA (1)
	MOVOA X3, X2
	PUNPCKLWL X4, X2		// X2 = DDCCBBAA (2)
	PUNPCKHWL X4, X3		// X3 = DDCCBBAA (3)

	// pseudo-transpose the 8x4 bit matrix in each dword
	TRANSPOSE(X0)
	TRANSPOSE(X1)
	TRANSPOSE(X2)
	TRANSPOSE(X3)

	// pull out low nibbles from matrices
	MOVOA X0, X4
	PSRLL $4, X0
	PAND X7, X4
	MOVOA X1, X5
	PSRLL $4, X1
	PAND X7, X5
	MOVOA X2, X6
	PSRLL $4, X2
	PAND X7, X6
	PADDB X6, X4			// X4 = ba98:3210:ba98:3210 (lo)
	MOVOA X3, X6
	PSRLL $4, X3
	PAND X7, X6
	PADDB X6, X5			// X5 = ba98:3210:ba98:3210 (hi)

	// pull out high nibbles from matrices
	PAND X7, X0
	PAND X7, X1
	PAND X7, X2
	PAND X7, X3

	// sum up high nibbles into X0, X1
	PADDB X2, X0			// X0 = fedc:7654:fedc:7654 (lo)
	PADDB X3, X1			// X1 = fedc:7654:fedc:7654 (hi)

	// shuffle them around
	MOVOA X4, X2
	PUNPCKLLQ X0, X2		// X2 = fedc:ba98:7654:3210 (1/4)
	PUNPCKHLQ X0, X4		// X4 = fedc:ba98:7654:3210 (2/4)
	MOVOA X5, X3
	PUNPCKLLQ X1, X3		// X3 = fedc:ba98:7654:3210 (3/4)
	PUNPCKHLQ X1, X5		// X5 = fedc:ba98:7654:3210 (4/4)

	// add to counters
	PXOR X7, X7			// zero register
	ACCUM( X8,  X9, X2)
	ACCUM(X10, X11, X4)
	ACCUM(X12, X13, X3)
	ACCUM(X14, X15, X5)

	SUBL $15*2, AX			// account for possible overflow
	CMPL AX, $15*2			// enough space left in the counters?
	JGE have_space

	CALL *BX			// call accumulation function

	// clear counters for next round
	PXOR X8, X8
	PXOR X9, X9
	PXOR X10, X10
	PXOR X11, X11
	PXOR X12, X12
	PXOR X13, X13
	PXOR X14, X14
	PXOR X15, X15

	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBQ $15*16, CX			// account for bytes consumed
	JGE vec

	// constants for processing the tail
endvec:	MOVQ magic<>+0(SB), X6		// bit position mask
	PSHUFD $0x44, X6, X6		// broadcast into both qwords
	PXOR X0, X0			// counter registers
	PXOR X1, X1
	PXOR X2, X2
	PXOR X3, X3

	// process tail, 4 bytes at a time
	SUBL $8-15*16, CX		// 8 bytes left to process?
	JLT tail1

tail8:	COUNT4(X0, X1, (SI))
	COUNT4(X2, X3, 4(SI))
	ADDQ $8, SI
	SUBL $8, CX
	JGE tail8

	// process remaining 0--7 byte
tail1:	SUBL $-8, CX			// anything left to process?
	JLE end

	MOVQ (SI), X7			// load 8 bytes from buffer.  Note that
					// buffer is aligned to 8 byte here
	MOVQ $window<>+16(SB), AX	// load window address
	NEGQ CX				// form a negative shift amount
	MOVQ (AX)(CX*1), X5		// load window mask
	PANDN X5, X7			// and mask out the desired bytes

	// process rest
	COUNT4(X0, X1, X7)
	PSRLO $4, X7
	COUNT4(X2, X3, X7)

	// add tail to counters
end:	PXOR X7, X7			// zero register
	MOVOA X0, X4
	PUNPCKLBW X7, X0
	PUNPCKHBW X7, X4
	PADDW X0, X8
	PADDW X4, X9
	MOVOA X1, X4
	PUNPCKLBW X7, X1
	PUNPCKHBW X7, X4
	PADDW X1, X10
	PADDW X4, X11
	MOVOA X2, X4
	PUNPCKLBW X7, X2
	PUNPCKHBW X7, X4
	PADDW X2, X12
	PADDW X4, X13
	MOVOA X3, X4
	PUNPCKLBW X7, X3
	PUNPCKHBW X7, X4
	PADDW X3, X14
	PADDW X4, X15

	CALL *BX
	RET

// zero-extend dwords in X trashing X, Y, and Z.  Add the low half
// dwords to a*8(DI) and the high half to (a+2)*8(DI).
// Assumes X7 == 0.
#define ACCUMQ(a, X, Y, Z) \
	MOVOA X, Y \
	PUNPCKLLQ X7, X \
	PUNPCKHLQ X7, Y \
	MOVOU (a)*8(DI), Z \
	PADDQ X, Z \
	MOVOU Z, (a)*8(DI) \
	MOVOU (a+2)*8(DI), Z \
	PADDQ Y, Z \
	MOVOU Z, (a+2)*8(DI)

// zero-extend words in X to qwords and add to a*8(DI) to (a+7)*8(DI).
// Assumes X7 == 0 an X8 <= X <= X15.
#define ACCUMO(a, X) \
	MOVOA X, X0 \
	PUNPCKLWL X7, X0 \
	PUNPCKHWL X7, X \
	ACCUMQ(a, X0, X1, X2) \
	ACCUMQ(a+4, X, X1, X2)

// Coun64 accumulation function.  Accumulates words X0--X7 into
// 64 qword counters at (DI).  Trashes X0--X12.
TEXT accum64<>(SB), NOSPLIT, $0-0
	PXOR X7, X7

	ACCUMO(0, X8)
	ACCUMO(8, X9)
	ACCUMO(16, X10)
	ACCUMO(24, X11)
	ACCUMO(32, X12)
	ACCUMO(40, X13)
	ACCUMO(48, X14)
	ACCUMO(56, X15)

	RET

// func conut64sse2(counts *[64]int, buf []uint64)
TEXT ·count64sse2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum64<>(SB), BX
	SHLQ $3, CX			// count in bytes
	CALL countsse<>(SB)
	RET

