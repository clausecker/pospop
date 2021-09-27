#include "textflag.h"

// An SSE2 based kernel first doing a 15-fold CSA reduction and then
// a 16-fold CSA reduction, carrying over place-value vectors between
// iterations.  Required CPU extension: SSE2.

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
	PXOR C, B \
	PXOR A, C \
	PXOR B, A \
	POR  C, B \
	PXOR A, B

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
TEXT countssecarry<>(SB), NOSPLIT, $0-0
	// constants for processing the head
	MOVQ magic<>+0(SB), X6		// bit position mask
	PSHUFD $0x44, X6, X6		// broadcast into both qwords
	PXOR X7, X7			// zero register
	PXOR X8, X8			// counter registers
	PXOR X10, X10
	PXOR X12, X12
	PXOR X14, X14

	CMPQ CX, $15*16			// is the CSA kernel worth using?
	JLT runt

	// load head into scratch space (until alignment/end is reached)
	MOVL SI, DX
	ANDL $15, DX			// offset of the buffer start from 16 byte alignment
	JEQ nohead			// if source buffer is aligned, skip head processing
	MOVL $16, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	MOVQ $window<>(SB), DX		// load window mask base pointer
	MOVOU (DX)(AX*1), X3		// load mask of the bytes that are part of the head
	PAND -16(SI)(AX*1), X3		// load head and mask out bytes that are not in the head
	CMPQ AX, CX			// is the head shorter than the buffer?
	SUBQ AX, CX			// mark head as accounted for
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
	MOVQ magic<>+8(SB), X7
	PSHUFD $0x55, X7, X6		// 0xaaaaaaaa
	PSHUFD $0x00, X7, X7		// 0x55555555

	ADDQ $15*16, SI
#define D	90
	PREFETCHT0 (D+ 0)*16(SI)
	PREFETCHT0 (D+ 4)*16(SI)
	PREFETCHT0 (D+ 8)*16(SI)
	PREFETCHT0 (D+12)*16(SI)

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
	ACCUM( X8,  X9, X0)
	ACCUM(X10, X11, X4)
	ACCUM(X12, X13, X1)
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

tail8:	COUNT4(X0, X1, 0(SI))
	COUNT4(X2, X3, 4(SI))
	ADDQ $8, SI
	SUBL $8, CX
	JGE tail8

	// process remaining 0--7 byte
tail1:	SUBL $-8, CX			// anything left to process?
	JLE end

	MOVQ (SI), X5			// load 8 bytes from buffer.  Note that
					// buffer is aligned to 8 byte here
	MOVQ $window<>+16(SB), AX	// load window address
	SUBQ CX, AX			// adjust mask
	MOVQ (AX), X7			// load window mask
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

	// buffer is short, do just head/tail processing
runt:	SUBL $8, CX			// 8 bytes left to process?
	JLT runt1

	// process runt 8 bytes at a time
runt8:	COUNT4(X8, X10, 0(SI))
	COUNT4(X12, X14, 4(SI))
	ADDQ $8, SI
	SUBL $8, CX
	JGE runt8

	// process remaining 0--7 byte
	// while making sure we don't get a page fault
runt1:	ADDL $8, CX			// anything left to process?
	JLE runt_accum

	MOVL SI, AX
	ANDL $7, AX			// offset from 8 byte alignment
	LEAL (AX)(CX*1), DX		// length of buffer plus alignment
	SHLL $3, CX			// remaining length in bits
	XORQ R9, R9
	BTSQ CX, R9
	DECQ R9				// mask of bits where R8 is in range
	CMPL DX, $8			// if this exceeds the alignment boundary
	JGE crossrunt1			// we can safely load directly

	ANDQ $~7, SI			// align buffer to 8 bytes
	MOVQ (SI), R8			// and and load 8 bytes from buffer
	LEAL (AX*8), CX			// offset from 8 byte alignment in bits
	SHRQ CX, R8			// buffer starting from the beginning
	JMP dorunt1

crossrunt1:
	MOVQ (SI), R8			// load 8 bytes from unaligned buffer

dorunt1:
	ANDQ R9, R8			// mask out bytes behind the buffer
	MOVQ R8, X3
	COUNT4(X8, X10, X3)
	PSRLO $4, X3
	COUNT4(X12, X14, X3)

	// move tail to counters and perform final accumulation
runt_accum:
	MOVOA X8, X9
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

	CALL *BX
	RET

// zero-extend dwords in X trashing X, X1, and X2.  Add the low half
// dwords to a*8(DI) and the high half to (a+2)*8(DI).
// Assumes X7 == 0.
#define ACCUMQ(a, X) \
	MOVOA X, X1 \
	PUNPCKLLQ X7, X \
	PUNPCKHLQ X7, X1 \
	MOVOU (a)*8(DI), X2 \
	PADDQ X, X2 \
	MOVOU X2, (a)*8(DI) \
	MOVOU (a+2)*8(DI), X2 \
	PADDQ X1, X2 \
	MOVOU X2, (a+2)*8(DI)

// zero-extend words in X to qwords and add to a*8(DI) to (a+7)*8(DI).
// Assumes X7 == 0 an X8 <= X <= X15.
#define ACCUMO(a, X) \
	MOVOA X, X0 \
	PUNPCKLWL X7, X0 \
	PUNPCKHWL X7, X \
	ACCUMQ(a, X0) \
	ACCUMQ(a+4, X)

// zero-extend words in X and Y to dwords, sum them, and move the
// halves back into X and Y.  Assumes X7 == 0.  Trashes X0, X1.
#define FOLDW(X, Y) \
	MOVOA X, X0 \
	PUNPCKLWL X7, X \
	PUNPCKHWL X7, X0 \
	MOVOA Y, X1 \
	PUNPCKLWL X7, X1 \
	PUNPCKHWL X7, Y \
	PADDL X1, X \
	PADDL X0, Y

// Count8 accumulation function.  Accumulates words X0--X7 into
// 8 qword counters at (DI).  Trashes X0--X12.
TEXT accum8<>(SB), NOSPLIT, $0-0
	FOLDW(X8, X12)
	FOLDW(X9, X13)
	FOLDW(X10, X14)
	FOLDW(X11, X15)
	PADDL X10, X8
	PADDL X11, X9
	PADDL X14, X12
	PADDL X15, X13
	PADDL X9, X8
	ACCUMQ(0, X8)
	PADDL X13, X12
	ACCUMQ(4, X12)
	RET

// Count16 accumulation function.  Accumulates words X0--X7 into
// 16 qword counters at (DI).  Trashes X0--X12.
TEXT accum16<>(SB), NOSPLIT, $0-0
	FOLDW(X8, X12)
	FOLDW(X9, X13)
	FOLDW(X10, X14)
	FOLDW(X11, X15)
	PADDL X10, X8
	ACCUMQ(0, X8)
	PADDL X14, X12
	ACCUMQ(4, X12)
	PADDL X11, X9
	ACCUMQ(8, X9)
	PADDL X15, X13
	ACCUMQ(12, X13)
	RET

// Count32 accumulation function.  Accumulates words X0--X7 into
// 32 qword counters at (DI).  Trashes X0--X12.
TEXT accum32<>(SB), NOSPLIT, $0-0
	FOLDW(X8, X12)
	ACCUMQ(0, X8)
	ACCUMQ(4, X12)
	FOLDW(X9, X13)
	ACCUMQ(8, X9)
	ACCUMQ(12, X13)
	FOLDW(X10, X14)
	ACCUMQ(16, X10)
	ACCUMQ(20, X14)
	FOLDW(X11, X15)
	ACCUMQ(24, X11)
	ACCUMQ(28, X15)
	RET

// Count64 accumulation function.  Accumulates words X0--X7 into
// 64 qword counters at (DI).  Trashes X0--X12.
TEXT accum64<>(SB), NOSPLIT, $0-0
	ACCUMO(0, X8)
	ACCUMO(8, X9)
	ACCUMO(16, X10)
	ACCUMO(24, X11)
	ACCUMO(32, X12)
	ACCUMO(40, X13)
	ACCUMO(48, X14)
	ACCUMO(56, X15)
	RET

// func count8sse2carry(counts *[8]int, buf []uint8)
TEXT ·count8sse2carry(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum8<>(SB), BX
	CALL countssecarry<>(SB)
	RET

// func count16sse2carry(counts *[16]int, buf []uint16)
TEXT ·count16sse2carry(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum16<>(SB), BX
	SHLQ $1, CX			// count in bytes
	CALL countssecarry<>(SB)
	RET

// func count32sse2carry(counts *[32]int, buf []uint32)
TEXT ·count32sse2carry(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum32<>(SB), BX
	SHLQ $2, CX			// count in bytes
	CALL countssecarry<>(SB)
	RET

// func count64sse2carry(counts *[64]int, buf []uint64)
TEXT ·count64sse2carry(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum64<>(SB), BX
	SHLQ $3, CX			// count in bytes
	CALL countssecarry<>(SB)
	RET
