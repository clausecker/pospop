#include "textflag.h"

// AVX2 based kernels for the position population count operation.  All
// these kernels have the same backbone based on a 15-fold CSA reduction
// to first reduce 480 byte into 4x16 byte, followed by a bunch of
// shuffles to group the positional registers into nibbles.  These are
// then summed up using a width-specific summation function.

// magic transposition constants, comparison constants
DATA magic<>+ 0(SB)/8, $0x0000000000000000
DATA magic<>+ 8(SB)/8, $0x0101010101010101
DATA magic<>+16(SB)/8, $0x0202020202020202
DATA magic<>+24(SB)/8, $0x0303030303030303
DATA magic<>+32(SB)/8, $0x8040201008040201
DATA magic<>+40(SB)/4, $0x0000cccc
DATA magic<>+44(SB)/2, $0x00aa
DATA magic<>+46(SB)/2, $0x0f0f
GLOBL magic<>(SB), RODATA|NOPTR, $48

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	VPAND A, B, D \
	VPXOR A, B, A \
	VPAND A, C, B \
	VPXOR A, C, A \
	VPOR  B, D, B

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
// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in BX, a 32 byte aligned input buffer pointer
// in SI, a pointer to counters in DI and a remaining length in CX.
TEXT ·countavx<>(SB), NOSPLIT, $32-0
	VPBROADCASTQ magic<>+32(SB), Y2	// byte mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VPXOR Y7, Y7, Y7		// zero register
	VMOVDQU Y7, scratch-32(SP)	// clear out scratch space
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// load head into Y0 (until alignment/end is reached)
	MOVQ CX, DX			// move counter out of the way
	ANDL $32-1, CX			// number of bytes til alignment is reached
	JZ nohead			// skip head if there is none
	CMPQ DX, CX			// is the buffer very short?
	CMOVLGT DX, CX			// if yes, only process what we have

	MOVQ DI, AX			// move DI out of the way
	LEAQ scratch-32(SP), DI		// temporary buffer for the head
	REP; MOVSB			// copy head to temp. buffer
	MOVQ AX, DI			// restore DI

	// process head, 8 bytes at a time

	// see tail for comments
	XORL CX, CX
head:	VPBROADCASTD scratch-32+0(SP)(BX*8), Y4
	VPBROADCASTD scratch-32+4(SP)(BX*8), Y5
	VPSHUFB Y3, Y4, Y4
	VPSHUFB Y3, Y5, Y5
	VPAND Y2, Y4, Y4
	VPAND Y2, Y5, Y5
	VPCMPEQB Y2, Y4, Y4
	VPCMPEQB Y2, Y5, Y5
	VPSUBB Y4, Y0, Y0
	VPSUBB Y5, Y1, Y1
	ADDL $1, CX
	CMPL CX, $4
	JLT head

	// initialise counters to what we have
nohead:	VPUNPCKLBW Y7, Y0, Y8
	VPUNPCKHBW Y7, Y0, Y9
	VPUNPCKLBW Y7, Y1, Y10
	VPUNPCKHBW Y7, Y1, Y11

	ANDQ $~(32-1), DX		// remove head bytes from count
					// SI has been advanced as a side
					// effect of REP; MOVSB
	MOVQ DX, CX			// and restore count register

	SUBQ $15*32, CX			// enough data left to process?
	JLT endvec			// also, pre-subtract

	VPBROADCASTD magic<>+40(SB), Y15 // for transpose
	VPBROADCASTW magic<>+44(SB), Y14 // for transpose
	VPBROADCASTW magic<>+46(SB), Y13 // low nibbles

	MOVL $65535-4, AX		// space left til overflow could occur in Y8--Y11

vec:	VMOVDQU 0*32(SI), Y0		// load 480 bytes from buf
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
#define D	75			// prefetch some iterations ahead
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

	// sum up low nibbles into Y4
	VPADDB Y4, Y5, Y4
	VPADDB Y6, Y7, Y5
	VPADDB Y4, Y5, Y4

	// pull out high nibbles from matrices
	VPAND Y0, Y13, Y0
	VPAND Y1, Y13, Y1
	VPAND Y2, Y13, Y2
	VPAND Y3, Y13, Y3

	// sum up high nibbles into Y5
	VPADDB Y0, Y1, Y0
	VPADDB Y2, Y4, Y1
	VPADDB Y0, Y1, Y5

	VPUNPCKLDQ Y5, Y4, Y0
	VPUNPCKLDQ Y5, Y4, Y1

	// zero-extend and add to Y8--Y11
	VPMOVZXBW X0, Y2
	VPMOVZXBW X1, Y3
	VEXTRACTI128 $1, Y0, X0
	VEXTRACTI128 $1, Y1, X1
	VPADDW Y2, Y8, Y8
	VPADDW Y3, Y9, Y9
	VPMOVZXBW X0, Y2
	VPMOVZXBW X1, Y3
	VPADDW Y2, Y10, Y10
	VPADDW Y3, Y11, Y11

	SUBL $15*4, AX			// account for possible overflow
	CMPL AX, $15*4			// enough space left in the counters?
	JLE have_space

	// flush accumulators into counters
	CALL *BX			// call accumulation function
	VPXOR Y8, Y8, Y8		// clear accumulators for next round
	VPXOR Y9, Y9, Y9
	VPXOR Y10, Y10, Y10
	VPXOR Y11, Y11, Y11

	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBQ $15*32, CX			// account for bytes consumed
	JGE vec

endvec:	VPBROADCASTQ magic<>+32(SB), Y2	// byte mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// process tail, 8 bytes at a time
	SUBL $8-15*32, CX		// 8 bytes left to process?
	JLT tail1

tail8:	VPBROADCASTD 0(SI), Y4
	VPBROADCASTD 4(SI), Y5
	ADDQ $8, SI
	VPSHUFB Y3, Y4, Y4
	VPSHUFB Y3, Y5, Y5
	VPAND Y2, Y4, Y4
	VPAND Y2, Y5, Y5
	VPCMPEQB Y2, Y4, Y4
	VPCMPEQB Y2, Y5, Y5
	VPSUBB Y4, Y0, Y0
	VPSUBB Y5, Y1, Y1
	SUBL $8, CX
	JGE tail8

	// process remaining 0--7 byte
tail1:	SUBL $-8, CX			// anything left to process?
	JLT end

	MOVQ DI, AX			// move DI out of the way
	LEAQ scratch-32(SP), DI		// temporary buffer for the head
	REP; MOVSB			// copy head to temp. buffer
	MOVQ AX, DI			// restore DI

	VPBROADCASTD scratch-32+0(SP)(BX*8), Y4
	VPBROADCASTD scratch-32+4(SP)(BX*8), Y5
	VPSHUFB Y3, Y4, Y4
	VPSHUFB Y3, Y5, Y5
	VPAND Y2, Y4, Y4
	VPAND Y2, Y5, Y5
	VPCMPEQB Y2, Y4, Y4
	VPCMPEQB Y2, Y5, Y5
	VPSUBB Y4, Y0, Y0
	VPSUBB Y5, Y1, Y1

	// add tail to counters
end:	VPUNPCKLBW Y7, Y0, Y4
	VPUNPCKHBW Y7, Y0, Y5
	VPUNPCKLBW Y7, Y1, Y6
	VPUNPCKHBW Y7, Y1, Y7

	VPADDW Y4, Y8, Y8
	VPADDW Y5, Y9, Y9
	VPADDW Y6, Y10, Y10
	VPADDW Y7, Y11, Y11

	// and perform a final accumulation
	CALL *BX
	RET
