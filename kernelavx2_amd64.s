#include "textflag.h"
#include "funcdata.h"

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
DATA magic<>+44(SB)/4, $0x00aa00aa
DATA magic<>+48(SB)/4, $0x0f0f0f0f
GLOBL magic<>(SB), RODATA|NOPTR, $52

// sliding window for head/tail loads.  Unfortunately, there doesn't seem to be
// a good way to do this with less memory wasted.
DATA window<>+ 0(SB)/8, $0x0000000000000000
DATA window<>+ 8(SB)/8, $0x0000000000000000
DATA window<>+16(SB)/8, $0x0000000000000000
DATA window<>+24(SB)/8, $0x0000000000000000
DATA window<>+32(SB)/8, $0xffffffffffffffff
DATA window<>+40(SB)/8, $0xffffffffffffffff
DATA window<>+48(SB)/8, $0xffffffffffffffff
DATA window<>+56(SB)/8, $0xffffffffffffffff
GLOBL window<>(SB), RODATA|NOPTR, $64

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
TEXT countavx<>(SB), NOSPLIT, $32-0
	TESTQ CX, CX			// any data to process at all?
	CMOVQEQ CX, SI			// if yes, make it so we don't attempt to load a head

	// constants for processing the head
	VPBROADCASTQ magic<>+32(SB), Y2	// byte mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VPXOR Y7, Y7, Y7		// zero register
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// load head into scratch space (until alignment/end is reached)
	MOVL SI, DX			// make a copy of SI
	ANDL $31, DX			// offset of the buffer start from 32 byte alignment
	JZ nohead			// if source buffer is aligned, skip head porcessing
	MOVL $32, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	VMOVDQA -32(SI)(AX*1), Y4	// load head
	LEAQ window<>(SB), DX		// load window mask base pointer
	VMOVDQU (DX)(AX*1), Y5		// load mask of the bytes that are part of the head
	VPAND Y5, Y4, Y4		// and mask out those bytes that are not
	CMPQ AX, CX			// is the head shorter than the buffer?
	JL norunt			// if yes, perform special processing

	// special processing if the buffer is short and doesn't cross
	// a 32 byte boundary
	SUBL CX, AX			// number of bytes by which we overshoot the buffer
	VMOVDQU (DX)(AX*1), Y5		// load mask of bytes that overshoot the buffer
	VPANDN Y4, Y5, Y4		// and clear them in Y4
	MOVL CX, AX			// set up the true prefix length

norunt:	VMOVDQU Y4, scratch-32(SP)	// copy to scratch space
	SUBQ AX, CX			// mark head as accounted for
	MOVL SI, DX			// keep a copy of the head pointer
	ADDQ AX, SI			// and advance past head

	ANDL $31, DX			// compute misalignment again
	SHRL $3, DX			// misalignment in qwords (rounded down)
	ANDL $3, DX			// and reduced to range 0--3

	// process head, 8 bytes at a time (up to 4 times)
head:	VPBROADCASTD scratch-32+0(SP)(DX*8), Y4
					// Y4 = 3210:3210:3210:3210:3210:3210:3210:3210
	VPBROADCASTD scratch-32+4(SP)(DX*8), Y5
	VPSHUFB Y3, Y4, Y4		// Y4 = 3333:3333:2222:2222:1111:1111:0000:0000
	VPSHUFB Y3, Y5, Y5
	VPAND Y2, Y4, Y4		// mask out one bit in each copy of the bytes
	VPAND Y2, Y5, Y5
	VPCMPEQB Y2, Y4, Y4		// set bytes to -1 if the bits were set
	VPCMPEQB Y2, Y5, Y5		// or to 0 otherwise
	VPSUBB Y4, Y0, Y0		// add 1/0 (subtract -1/0) to counters
	VPSUBB Y5, Y1, Y1
	ADDL $1, DX
	CMPL DX, $4			// have we processed the full head?
	JLT head

	// initialise counters to what we have
nohead:	VPUNPCKLBW Y7, Y0, Y8		// 0-7, 16-23
	VPUNPCKHBW Y7, Y0, Y9		// 8-15, 24-31
	VPUNPCKLBW Y7, Y1, Y10		// 32-39, 48-55
	VPUNPCKHBW Y7, Y1, Y11		// 40-47, 56-63

	SUBQ $15*32, CX			// enough data left to process?
	JLT endvec			// also, pre-subtract

	VPBROADCASTD magic<>+40(SB), Y15 // for transpose
	VPBROADCASTD magic<>+44(SB), Y14 // for transpose
	VPBROADCASTD magic<>+48(SB), Y13 // low nibbles

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
	VPAND Y2, Y13, Y6
	VPSRLD $4, Y2, Y2
	VPAND Y3, Y13, Y7
	VPSRLD $4, Y3, Y3

	// sum up low nibbles into Y4
	VPADDB Y4, Y6, Y6
	VPADDB Y5, Y7, Y7
	VPERM2I128 $0x20, Y7, Y6, Y4
	VPERM2I128 $0x31, Y7, Y6, Y5
	VPADDB Y5, Y4, Y4

	// pull out high nibbles from matrices
	VPAND Y0, Y13, Y0
	VPAND Y1, Y13, Y1
	VPAND Y2, Y13, Y2
	VPAND Y3, Y13, Y3

	// sum up high nibbles into Y5
	VPADDB Y0, Y2, Y2
	VPADDB Y1, Y3, Y3
	VPERM2I128 $0x20, Y3, Y2, Y0
	VPERM2I128 $0x31, Y3, Y2, Y1
	VPADDB Y1, Y0, Y5

	VPUNPCKLDQ Y5, Y4, Y2
	VPUNPCKHDQ Y5, Y4, Y3
	VPERM2I128 $0x20, Y3, Y2, Y0
	VPERM2I128 $0x31, Y3, Y2, Y1

	// zero-extend and add to Y8--Y11
	VPXOR Y7, Y7, Y7
	VPUNPCKLBW Y7, Y0, Y4
	VPUNPCKHBW Y7, Y0, Y5
	VPUNPCKLBW Y7, Y1, Y6
	VPUNPCKHBW Y7, Y1, Y7

	VPADDW Y4, Y8, Y8
	VPADDW Y5, Y9, Y9
	VPADDW Y6, Y10, Y10
	VPADDW Y7, Y11, Y11

	SUBL $15*4, AX			// account for possible overflow
	CMPL AX, $15*4			// enough space left in the counters?
	JGE have_space

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
	JLE end

	MOVQ (SI), X5			// load 8 byte from buffer.  This is ok
					// as buffer is aligned to 8 byte here
	MOVQ $window<>+32(SB), AX	// load window address
	NEGQ CX				// form a negative shift amount
	MOVQ (AX)(CX*1), X6		// load window mask
	VPANDN X5, X6, X5		// and mask out the desired bytes

	VPBROADCASTD X5, Y4
	VPSRLDQ $4, X5, X5
	VPBROADCASTD X5, Y5
	VPSHUFB Y3, Y4, Y4
	VPSHUFB Y3, Y5, Y5
	VPAND Y2, Y4, Y4
	VPAND Y2, Y5, Y5
	VPCMPEQB Y2, Y4, Y4
	VPCMPEQB Y2, Y5, Y5
	VPSUBB Y4, Y0, Y0
	VPSUBB Y5, Y1, Y1

	// add tail to counters
end:	VPXOR Y7, Y7, Y7
	VPUNPCKLBW Y7, Y0, Y4
	VPUNPCKHBW Y7, Y0, Y5
	VPUNPCKLBW Y7, Y1, Y6
	VPUNPCKHBW Y7, Y1, Y7

	VPADDW Y4, Y8, Y8
	VPADDW Y5, Y9, Y9
	VPADDW Y6, Y10, Y10
	VPADDW Y7, Y11, Y11

	// and perform a final accumulation
	CALL *BX
	VZEROUPPER
	RET

// Count16 accumulation function.  Accumulates words Y8--Y11
// into 16 qword counters at (DI).  Trashes Y0--Y11.
TEXT accum16<>(SB), NOSPLIT, $0-0
	VPXOR Y12, Y12, Y12		// zero register

	// load counters from (DI)
	VMOVDQU  0*8(DI), Y4
	VMOVDQU  4*8(DI), Y5
	VMOVDQU  8*8(DI), Y6
	VMOVDQU 12*8(DI), Y7

	// zero-extend Y8--Y11 to dwords and reduce
	// from 64 counters to 16 counters
	VPUNPCKLWD Y12, Y8, Y0
	VPUNPCKHWD Y12, Y8, Y8
	VPUNPCKLWD Y12, Y9, Y1
	VPUNPCKHWD Y12, Y9, Y9
	VPADDD Y8, Y0, Y0
	VPADDD Y9, Y1, Y1

	VPUNPCKLWD Y12, Y10, Y2
	VPUNPCKHWD Y12, Y10, Y10
	VPUNPCKLWD Y12, Y11, Y3
	VPUNPCKHWD Y12, Y11, Y11
	VPADDD Y10, Y2, Y2
	VPADDD Y11, Y3, Y3
	VPADDD Y2, Y0, Y0
	VPADDD Y3, Y1, Y2

	VPUNPCKHDQ Y12, Y0, Y1
	VPUNPCKLDQ Y12, Y0, Y0
	VPUNPCKHDQ Y12, Y2, Y3
	VPUNPCKLDQ Y12, Y2, Y2

	VPADDQ Y4, Y0, Y4
	VPADDQ Y5, Y1, Y5
	VPADDQ Y6, Y2, Y6
	VPADDQ Y7, Y3, Y7

	VMOVDQU Y4,  0*8(DI)
	VMOVDQU Y5,  4*8(DI)
	VMOVDQU Y6,  8*8(DI)
	VMOVDQU Y7, 12*8(DI)

	RET

// accumulate the 16 counters in Y into k*8(DI) to (k+15)*8(DI)
// trashes Y0--Y3.  Assumes Y12 == 0
#define ACCUM(k, Y) \
	VPUNPCKLWD Y12, Y, Y0 \
	VPUNPCKHWD Y12, Y, Y1 \
	VPERMQ $0xd8, Y0, Y0 \
	VPERMQ $0xd8, Y1, Y1 \
	VPUNPCKLDQ Y12, Y0, Y2 \
	VPUNPCKHDQ Y12, Y0, Y3 \
	VPADDQ (k+0)*8(DI), Y2, Y2 \
	VPADDQ (k+16)*8(DI), Y3, Y3 \
	VMOVDQU Y2, (k+0)*8(DI) \
	VMOVDQU Y3, (k+16)*8(DI) \
	VPUNPCKLDQ Y12, Y1, Y2 \
	VPUNPCKHDQ Y12, Y1, Y3 \
	VPADDQ (k+4)*8(DI), Y2, Y2 \
	VPADDQ (k+20)*8(DI), Y3, Y3 \
	VMOVDQU Y2, (k+4)*8(DI) \
	VMOVDQU Y3, (k+20)*8(DI)

// Count64 accumulation function.  Accumulates words Y8--Y11
// into 64 qword counters at (DI).
TEXT accum64<>(SB), NOSPLIT, $0-0
	VPXOR Y12, Y12, Y12
	ACCUM(0, Y8)
	ACCUM(8, Y9)
	ACCUM(32, Y10)
	ACCUM(40, Y11)
	RET

// func count16avx2(counts *[16]int, buf []uint16)
TEXT ·count16avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum16<>(SB), BX
	SHLQ $1, CX			// count in bytes
	CALL countavx<>(SB)
	RET

// func count64avx2(counts *[64]int, buf []uint64)
TEXT ·count64avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum64<>(SB), BX
	SHLQ $3, CX			// count in bytes
	CALL countavx<>(SB)
	RET
