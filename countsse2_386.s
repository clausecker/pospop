#include "textflag.h"

// SSE2 based kernels for the positional population count operation.
// All these kernels have the same backbone based on a 15-fold CSA
// reduction to first reduce 240 byte into 4x16 byte, followed by a
// bunch of shuffles to group the positional registers into nibbles.
// These are then summed up using a width-specific summation function.
// Required CPU extension: SSE2.

// magic transposition constants
DATA magic<> +0(SB)/8, $0x8040201008040201
DATA magic<>+ 8(SB)/8, $0xaaaaaaaa55555555
DATA magic<>+16(SB)/8, $0xcccccccc33333333
DATA magic<>+24(SB)/4, $0x0f0f0f0f
GLOBL magic<>(SB), RODATA|NOPTR, $28

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

// Process 4 bytes from X4.  Add low word counts to L, high to H
// assumes mask loaded into X2.  Trashes X4, X5.
#define COUNT4(L, H) \			// X4 = ----:----:----:3210
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
	PADDW S1, X \
	PADDW S2, X6 \
	MOVOA X, S1 \
	MOVOA X6, S2

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation funciton in BX, a possibly unaligned input buffer in SI,
// counters in DI and a remaining length in BP.
TEXT countsse<>(SB), NOSPLIT, $144-0
	TESTL BP, BP			// any data to process at all?
	CMOVLEQ BP, SI			// if not, avoid loading head

	// constants for processing the head
	MOVQ magic<>+0(SB), X6		// bit position mask
	PSHUFD $0x44, X6, X6		// broadcast into both qwords
	PXOR X0, X0			// counter registers
	PXOR X1, X1
	PXOR X2, X2
	PXOR X3, X3

	// load head into scratch space (until alignment/end is reached)
	MOVL SI, DX
	ANDL $15, DX			// offset of the buffer start from 16 byte alignment
	JEQ nohead			// if source buffer is aligned, skip head processing
	MOVL $16, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	MOVL $window<>(SB), DX
	MOVOA -16(SI)(AX*1), X7		// load head
	MOVOU (DX)(AX*1), X5		// load mask of the bytes that are part of the head
	PAND X5, X7			// and mask out those bytes that are not
	CMPL AX, BP			// is the head shorter than the buffer?
	JLT norunt

	// buffer is short and does not cross a 16 byte boundary
	SUBL BP, AX			// number of bytes by which we overshoot the buffer
	MOVOU (DX)(AX*1), X5		// load mask of bytes that overshoot the buffer
	PANDN X7, X5			// and clear them
	MOVOA X5, X7			// move head buffer back to X4
	MOVL BP, AX			// set up true prefix length

norunt:	SUBL AX, BP			// mark head as accounted for
	ADDL AX, SI			// and advance past the head

	// process head in four increments of 4 bytes
	MOVOA X7, X4
	PSRLO $4, X7
	COUNT4(X0, X1)
	MOVOA X7, X4
	PSRLO $4, X7
	COUNT4(X2, X3)
	MOVOA X7, X4
	PSRLO $4, X7
	COUNT4(X0, X1)
	MOVOA X7, X4
	COUNT4(X2, X3)

	// produce 16 byte aligned pointer to counter vector in DX
nohead:	MOVL $counts-144+15(SP), DX
	ANDL $~15, DX			// align to 16 bytes

	// initialise counters in (DX) to what we have
	PXOR X7, X7			// zero register
	MOVOA X0, X4
	PUNPCKLBW X7, X0
	PUNPCKHBW X7, X4
	MOVOA X0, 0*16(DX)
	MOVOA X4, 1*16(DX)
	MOVOA X1, X4
	PUNPCKLBW X7, X1
	PUNPCKHBW X7, X4
	MOVOA X1, 2*16(DX)
	MOVOA X4, 3*16(DX)
	MOVOA X2, X4
	PUNPCKLBW X7, X2
	PUNPCKHBW X7, X4
	MOVOA X2, 4*16(DX)
	MOVOA X4, 5*16(DX)
	MOVOA X3, X4
	PUNPCKLBW X7, X3
	PUNPCKHBW X7, X4
	MOVOA X3, 6*16(DX)
	MOVOA X4, 7*16(DX)

	SUBL $15*16, BP			// enough data left to process?
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
	MOVQ magic<>+8(SB), X7
	PSHUFD $0x55, X7, X6		// 0xaaaaaaaa
	PSHUFD $0x00, X7, X7		// 0x55555555

	ADDL $15*16, SI

	// group X0--X3 into nibbles in the same register
	MOVOA X0, X5
	PAND X6, X5
	PSRLL $1, X5
	MOVOA X1, X4
	PAND X7, X4
	PADDL X4, X4
	PAND X7, X0
	PAND X6, X1
	POR X4, X0			// X0 = eca86420 (low crumbs)
	POR X5, X1			// X1 = fdb97531 (high crumbs)

	MOVOA X2, X5
	PAND X6, X5
	PSRLL $1, X5
	MOVOA X3, X4
	PAND X7, X4
	PADDL X4, X4
	PAND X7, X2
	PAND X6, X3
	POR X4, X2			// X0 = eca86420 (low crumbs)
	POR X5, X3			// X1 = fdb97531 (high crumbs)

	MOVQ magic<>+16(SB), X7
	PSHUFD $0x55, X7, X6		// 0xcccccccc
	PSHUFD $0x00, X7, X7		// 0x33333333

	MOVOA X0, X5
	PAND X6, X5
	PSRLL $2, X5
	MOVOA X2, X4
	PAND X7, X4
	PSLLL $2, X4
	PAND X7, X0
	PAND X6, X2
	POR X4, X0			// X0 = c840
	POR X5, X2			// X2 = ea62

	MOVOA X1, X5
	PAND X6, X5
	PSRLL $2, X5
	MOVOA X3, X4
	PAND X7, X4
	PSLLL $2, X4
	PAND X7, X1
	PAND X6, X3
	POR X4, X1			// X1 = d951
	POR X5, X3			// X3 = fb73

	MOVD magic<>+24(SB), X7
	PSHUFD $0x00, X7, X7		// 0x0f0f0f0f

	// pre-shuffle nibbles
	MOVOA X2, X5
	PUNPCKLBW X3, X2		// X2 = fbea7362 (3:2:1:0)
	PUNPCKHBW X3, X5		// X5 = fbea7362 (7:6:5:4)
	MOVOA X0, X3
	PUNPCKLBW X1, X0		// X0 = d9c85140 (3:2:1:0)
	PUNPCKHBW X1, X3		// X4 = d9c85140 (7:6:5:4)
	MOVOA X0, X1
	PUNPCKLWL X2, X0		// X0 = fbead9c873625140 (1:0)
	PUNPCKHWL X2, X1		// X1 = fbead9c873625140 (3:2)
	MOVOA X3, X2
	PUNPCKLWL X5, X2		// X2 = fbead9c873625140 (5:4)
	PUNPCKHWL X5, X3		// X3 = fbead9c873625140 (7:6)

	// pull high and low nibbles and reduce once
	MOVOA X0, X4
	PSRLL $4, X4
	PAND X7, X0			// X0 = ba983210 (1:0)
	PAND X7, X4			// X4 = fedc7654 (1:0)

	MOVOA X2, X6
	PSRLL $4, X2
	PAND X7, X6			// X6 = ba983210 (5:4)
	PAND X7, X2			// X2 = fedc7654 (5:4)

	PADDB X6, X0			// X0 = ba983210 (1:0)
	PADDB X4, X2			// X2 = fedc7654 (1:0)

	MOVOA X1, X4
	PSRLL $4, X4
	PAND X7, X1			// X1 = ba983210 (3:2)
	PAND X7, X4			// X4 = fedc7654 (3:2)

	MOVOA X3, X6
	PSRLL $4, X3
	PAND X7, X6			// X6 = ba983210 (7:6)
	PAND X7, X3			// X3 = fedc7654 (7:6)

	PADDB X6, X1			// X1 = ba983210 (3:2)
	PADDB X4, X3			// X3 = fedc7654 (3:2)

	// unpack one last time
	MOVOA X0, X4
	PUNPCKLLQ X2, X0		// X0 = fedcba9876543210 (0)
	PUNPCKHLQ X2, X4		// X4 = fedcba9876543210 (1)
	MOVOA X1, X5
	PUNPCKLLQ X3, X1		// X1 = fedcba9876543210 (2)
	PUNPCKHLQ X3, X5		// X5 = fedcba9876543210 (3)

	// add to counters
	PXOR X7, X7			// zero register
	ACCUM(0*16(DX), 1*16(DX), X0)
	ACCUM(2*16(DX), 3*16(DX), X4)
	ACCUM(4*16(DX), 5*16(DX), X1)
	ACCUM(6*16(DX), 7*16(DX), X5)

	SUBL $15*2, AX			// account for possible overflow
	CMPL AX, $15*2			// enough space left in the counters?
	JGE have_space

	CALL *BX			// call accumulation function

	// clear counts for next round
	PXOR X7, X7
	MOVOA X7, 0*16(DX)
	MOVOA X7, 1*16(DX)
	MOVOA X7, 2*16(DX)
	MOVOA X7, 3*16(DX)
	MOVOA X7, 4*16(DX)
	MOVOA X7, 5*16(DX)
	MOVOA X7, 6*16(DX)
	MOVOA X7, 7*16(DX)

	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBL $15*16, BP			// account for bytes consumed
	JGE vec

	// constants for processing the tail
endvec:	MOVQ magic<>+0(SB), X6		// bit position mask
	PSHUFD $0x44, X6, X6		// broadcast into both qwords
	PXOR X0, X0			// counter registers
	PXOR X1, X1
	PXOR X2, X2
	PXOR X3, X3

	// process tail, 4 bytes at a time
	SUBL $8-15*16, BP		// 8 bytes left to process?
	JLT tail1

tail8:	MOVL (SI), X4
	COUNT4(X0, X1)
	MOVL 4(SI), X4
	COUNT4(X2, X3)
	ADDL $8, SI
	SUBL $8, BP
	JGE tail8

	// process remaining 0--7 byte
tail1:	SUBL $-8, BP			// anything left to process?
	JLE end

	MOVQ (SI), X5			// load 8 bytes from buffer.  Note that
					// buffer is aligned to 8 byte here
	MOVL $window<>+16(SB), AX	// load window address
	SUBL BP, AX			// adjust mask pointer
	MOVQ (AX), X7			// load window mask
	PANDN X5, X7			// and mask out the desired bytes

	// process rest
	MOVOA X7, X4
	PSRLO $4, X7
	COUNT4(X0, X1)
	MOVOA X7, X4
	COUNT4(X2, X3)

	// add tail to counters
end:	PXOR X7, X7			// zero register
	ACCUM(0*16(DX), 1*16(DX), X0)
	ACCUM(2*16(DX), 3*16(DX), X1)
	ACCUM(4*16(DX), 5*16(DX), X2)
	ACCUM(6*16(DX), 7*16(DX), X3)

	CALL *BX
	RET

// zero-extend words in X and Y to dwords, sum them, and move the
// halves back into X and Y.  Assumes X7 == 0.  Trashes X2 and X3.
#define FOLDW(X, Y) \
	MOVOA X, X2 \
	PUNPCKLWL X7, X \
	PUNPCKHWL X7, X2 \
	MOVOA Y, X3 \
	PUNPCKLWL X7, X3 \
	PUNPCKHWL X7, Y \
	PADDL X3, X \
	PADDL X2, Y

// add dwords in X to (a)*4(DI), trashing X2.
#define ACCUMQ(a, X) \
	MOVOU (a)*4(DI), X2 \
	PADDL X, X2 \
	MOVOU X2, (a)*4(DI)

// zero-extend words in s*16(DX) to dwords and add to a*4(DI) to (a+7)*4(DI).
// Assumes X7 == 0 and trashes X0, X1, and X2.
#define ACCUMO(a, s) \
	MOVOA (s)*16(DX), X0 \
	MOVOA X0, X1 \
	PUNPCKLWL X7, X0 \
	PUNPCKHWL X7, X1 \
	ACCUMQ(a, X0) \
	ACCUMQ(a+4, X1)

// Count8 accumulation function.  Accumulates words into
// 8 dword counters at (DI).  Trashes X0--X7.
TEXT accum8<>(SB), NOSPLIT, $0-0
	MOVOA 0*16(DX), X0
	MOVOA 4*16(DX), X1
	MOVOA 2*16(DX), X4
	MOVOA 6*16(DX), X5
	FOLDW(X0, X1)
	FOLDW(X4, X5)
	PADDL X4, X0
	PADDL X5, X1
	ACCUMQ(0, X0)
	ACCUMQ(4, X1)
	MOVOA 1*16(DX), X0
	MOVOA 5*16(DX), X1
	MOVOA 3*16(DX), X4
	MOVOA 7*16(DX), X5
	FOLDW(X0, X1)
	FOLDW(X4, X5)
	PADDL X4, X0
	PADDL X5, X1
	ACCUMQ(0, X0)
	ACCUMQ(4, X1)
	RET

// Count16 accumulation function.  Accumulates words into
// 16 dword counters at (DI).  Trashes X0--X7.
TEXT accum16<>(SB), NOSPLIT, $0-0
	MOVOA 0*16(DX), X0
	MOVOA 4*16(DX), X1
	MOVOA 2*16(DX), X4
	MOVOA 6*16(DX), X5
	FOLDW(X0, X1)
	FOLDW(X4, X5)
	PADDL X4, X0
	PADDL X5, X1
	ACCUMQ(0, X0)
	ACCUMQ(4, X1)
	MOVOA 1*16(DX), X0
	MOVOA 5*16(DX), X1
	MOVOA 3*16(DX), X4
	MOVOA 7*16(DX), X5
	FOLDW(X0, X1)
	FOLDW(X4, X5)
	PADDL X4, X0
	PADDL X5, X1
	ACCUMQ(8, X0)
	ACCUMQ(12, X1)
	RET

// Count32 accumulation function.  Accumulates words into
// 32 dword counters at (DI).  Trashes X0--X7.
TEXT accum32<>(SB), NOSPLIT, $0-0
	MOVOA 0*16(DX), X0
	MOVOA 4*16(DX), X1
	FOLDW(X0, X1)
	ACCUMQ(0, X0)
	ACCUMQ(4, X1)
	MOVOA 1*16(DX), X0
	MOVOA 5*16(DX), X1
	FOLDW(X0, X1)
	ACCUMQ(8, X0)
	ACCUMQ(12, X1)
	MOVOA 2*16(DX), X0
	MOVOA 6*16(DX), X1
	FOLDW(X0, X1)
	ACCUMQ(16, X0)
	ACCUMQ(20, X1)
	MOVOA 3*16(DX), X0
	MOVOA 7*16(DX), X1
	FOLDW(X0, X1)
	ACCUMQ(24, X0)
	ACCUMQ(28, X1)
	RET

// Count64 accumulation function.  Accumulates words into
// 64 dword counters at (DI).  Trashes X0, X1, and X7.
TEXT accum64<>(SB), NOSPLIT, $0-0
	ACCUMO( 0, 0)
	ACCUMO( 8, 1)
	ACCUMO(16, 2)
	ACCUMO(24, 3)
	ACCUMO(32, 4)
	ACCUMO(40, 5)
	ACCUMO(48, 6)
	ACCUMO(56, 7)
	RET

// func count8sse2(counts *[8]int, buf []uint8)
TEXT ·count8sse2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum8<>(SB), BX
	CALL countsse<>(SB)
	RET

// func count16sse2(counts *[16]int, buf []uint16)
TEXT ·count16sse2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum16<>(SB), BX
	SHLL $1, BP			// count in bytes
	CALL countsse<>(SB)
	RET

// func count32sse2(counts *[32]int, buf []uint32)
TEXT ·count32sse2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum32<>(SB), BX
	SHLL $2, BP			// count in bytes
	CALL countsse<>(SB)
	RET


// func count64sse2(counts *[64]int, buf []uint64)
TEXT ·count64sse2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum64<>(SB), BX
	SHLL $3, BP			// count in bytes
	CALL countsse<>(SB)
	RET
