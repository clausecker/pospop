#include "textflag.h"

// AVX2 based kernels for the positional population count operation.
// All these kernels have the same backbone based on a 15-fold CSA
// reduction to first reduce 480 byte into 4x32 byte, followed by a
// bunch of shuffles to group the positional registers into nibbles.
// These are then summed up using a width-specific summation function.
// Required CPU extension: AVX2.

// magic transposition constants, comparison constants
DATA magic<>+ 0(SB)/8, $0x0000000000000000
DATA magic<>+ 8(SB)/8, $0x0101010101010101
DATA magic<>+16(SB)/8, $0x0202020202020202
DATA magic<>+24(SB)/8, $0x0303030303030303
DATA magic<>+32(SB)/8, $0x8040201008040201
DATA magic<>+40(SB)/4, $0x11111111
DATA magic<>+44(SB)/4, $0x0f0f0f0f
GLOBL magic<>(SB), RODATA|NOPTR, $48

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

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in BX, a possibly unaligned input buffer in SI,
// counters in DI and a remaining length in CX.
TEXT countavx<>(SB), NOSPLIT, $32-0
	TESTQ CX, CX			// any data to process at all?
	CMOVQEQ CX, SI			// if not, avoid loading head

	// constants for processing the head
	VPBROADCASTQ magic<>+32(SB), Y2	// bit position mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VPXOR Y7, Y7, Y7		// zero register
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// load head into scratch space (until alignment/end is reached)
	MOVL SI, DX
	ANDL $31, DX			// offset of the buffer start from 32 byte alignment
	JEQ nohead			// if source buffer is aligned, skip head processing
	MOVL $32, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	VMOVDQA -32(SI)(AX*1), Y4	// load head
	LEAQ window<>(SB), DX		// load window mask base pointer
	VMOVDQU (DX)(AX*1), Y5		// load mask of the bytes that are part of the head
	VPAND Y5, Y4, Y4		// and mask out those bytes that are not
	CMPQ AX, CX			// is the head shorter than the buffer?
	JLT norunt			// if yes, perform special processing

	// buffer is short and does not cross a 32 byte boundary
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

	VPBROADCASTD magic<>+40(SB), Y15 // 0x11111111 for transposition
	VPBROADCASTD magic<>+44(SB), Y14 // 0x0f0f0f0f for deinterleaving the nibbles

	MOVL $65535-4, AX		// space left til overflow could occur in Y8--Y11

vec:	VMOVDQA 0*32(SI), Y0		// load 480 bytes from buf
	VMOVDQA 1*32(SI), Y1		// and sum them into Y3:Y2:Y1:Y0
	VMOVDQA 2*32(SI), Y4
	VMOVDQA 3*32(SI), Y2
	VMOVDQA 4*32(SI), Y3
	VMOVDQA 5*32(SI), Y5
	VMOVDQA 6*32(SI), Y6
	CSA(Y0, Y1, Y4, Y7)
	VMOVDQA 7*32(SI), Y4
	CSA(Y3, Y2, Y5, Y7)
	VMOVDQA 8*32(SI), Y5
	CSA(Y0, Y3, Y6, Y7)
	VMOVDQA 9*32(SI), Y6
	CSA(Y1, Y2, Y3, Y7)
	VMOVDQA 10*32(SI), Y3
	CSA(Y0, Y4, Y5, Y7)
	VMOVDQA 11*32(SI), Y5
	CSA(Y0, Y3, Y6, Y7)
	VMOVDQA 12*32(SI), Y6
	CSA(Y1, Y3, Y4, Y7)
	VMOVDQA 13*32(SI), Y4
	CSA(Y0, Y5, Y6, Y7)
	VMOVDQA 14*32(SI), Y6
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

	// group nibbles in Y0, Y1, Y2, and Y3 into Y4, Y5, Y6, and Y7
	VPAND Y0, Y15, Y4
	VPSRLD $1, Y0, Y0
	VPAND Y0, Y15, Y5
	VPSRLD $1, Y0, Y0
	VPAND Y0, Y15, Y6
	VPSRLD $1, Y0, Y0
	VPAND Y0, Y15, Y7

	VPADDD Y15, Y15, Y13		// 0x22222222
	VPADDD Y1, Y1, Y12
	VPAND Y12, Y13, Y12
	VPOR Y12, Y4, Y4
	VPAND Y1, Y13, Y12
	VPSRLD $1, Y1, Y1
	VPOR Y12, Y5, Y5
	VPAND Y1, Y13, Y12
	VPSRLD $1, Y1, Y1
	VPOR Y12, Y6, Y6
	VPAND Y1, Y13, Y12
	VPOR Y12, Y7, Y7

	VPADDD Y13, Y13, Y13		// 0x44444444
	VPSLLD $2, Y2, Y12
	VPAND Y12, Y13, Y12
	VPOR Y12, Y4, Y4
	VPADDD Y2, Y2, Y12
	VPAND Y12, Y13, Y12
	VPOR Y12, Y5, Y5
	VPAND Y2, Y13, Y12
	VPSRLD $1, Y2, Y2
	VPOR Y12, Y6, Y6
	VPAND Y2, Y13, Y12
	VPOR Y12, Y7, Y7

	VPADDD Y13, Y13, Y13		// 0x88888888
	VPSLLD $3, Y3, Y12
	VPAND Y12, Y13, Y12
	VPOR Y12, Y4, Y4
	VPSLLD $2, Y3, Y12
	VPAND Y12, Y13, Y12
	VPOR Y12, Y5, Y5
	VPADDD Y3, Y3, Y12
	VPAND Y12, Y13, Y12
	VPOR Y12, Y6, Y6
	VPAND Y3, Y13, Y12
	VPOR Y12, Y7, Y7

	// dword contents in nibbles:
	// Y4 = c840c840, Y5 = d951d951, Y6 = ea62ea62, Y6 = fb73fb73

	// pre-shuffle nibbles
	VPUNPCKLBW Y5, Y4, Y0		// Y0 = d9c85140         (3:2:1:0)
	VPUNPCKHBW Y5, Y4, Y1		// Y1 = d9c85140	 (7:6:5:4)
	VPUNPCKLBW Y7, Y6, Y2		// Y2 = fbea7362	 (3:2:1:0)
	VPUNPCKHBW Y7, Y6, Y3		// Y3 = fbea7362	 (7:6:5:4)
	VPUNPCKLWD Y2, Y0, Y4		// Y4 = fbead9c873625140  (1:0)
	VPUNPCKHWD Y2, Y0, Y5		// Y5 = fbead9c873625140  (3:2)
	VPUNPCKLWD Y3, Y1, Y6		// Y6 = fbead9c873625140  (5:4)
	VPUNPCKHWD Y3, Y1, Y7		// Y7 = fbead9c873625140  (7:6)

	// pull out high and low nibbles
	VPAND Y4, Y14, Y0
	VPSRLD $4, Y4, Y4
	VPAND Y4, Y14, Y4
	VPAND Y5, Y14, Y1
	VPSRLD $4, Y5, Y5
	VPAND Y5, Y14, Y5
	VPAND Y6, Y14, Y2
	VPSRLD $4, Y6, Y6
	VPAND Y6, Y14, Y6
	VPAND Y7, Y14, Y3
	VPSRLD $4, Y7, Y7
	VPAND Y7, Y14, Y7

	// reduce common values
	VPADDB Y2, Y0, Y0		// Y0 = ba98:3210:ba98:3210 (1:0)
	VPADDB Y3, Y1, Y1		// Y1 = ba98:3210:ba98:3210 (3:2)
	VPADDB Y6, Y4, Y2		// Y2 = fedc:7654:fedc:7654 (1:0)
	VPADDB Y7, Y5, Y3		// Y3 = fedc:7654:fedc:7654 (3:2)

	// shuffle dwords and group them
	VPUNPCKLDQ Y2, Y0, Y4
	VPUNPCKHDQ Y2, Y0, Y5
	VPUNPCKLDQ Y3, Y1, Y6
	VPUNPCKHDQ Y3, Y1, Y7
	VPERM2I128 $0x20, Y5, Y4, Y0
	VPERM2I128 $0x31, Y5, Y4, Y2
	VPERM2I128 $0x20, Y7, Y6, Y1
	VPERM2I128 $0x31, Y7, Y6, Y3
	VPADDB Y2, Y0, Y0		// Y0 = fedc:ba98:7654:3210 (1:0)
	VPADDB Y3, Y1, Y1		// Y1 = fedc:ba98:7654:3210 (3:2)

	// zero-extend and add to Y8--Y11
	VPXOR Y7, Y7, Y7
	VPUNPCKLBW Y7, Y0, Y4
	VPUNPCKHBW Y7, Y0, Y5
	VPUNPCKLBW Y7, Y1, Y6
	VPUNPCKHBW Y7, Y1, Y1

	VPADDW Y4, Y8, Y8
	VPADDW Y5, Y9, Y9
	VPADDW Y6, Y10, Y10
	VPADDW Y1, Y11, Y11

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

	VMOVQ (SI), X5			// load 8 byte from buffer.  This is ok
					// as buffer is aligned to 8 byte here
	MOVQ $window<>+32(SB), AX	// load window address
	SUBQ CX, AX			// adjust mask pointer
	VMOVQ (AX), X6			// load window mask
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
	VPXOR Y7, Y7, Y7
	CALL *BX
	VZEROUPPER
	RET

// zero extend Y8--Y11 into dwords and fold the upper 32 counters
// over the lower 32 counters, leaving the registers with
// Y0 contains  0- 3, 16-19
// Y8 contains  4- 7, 20-23
// Y1 contains  8-11, 24-27
// Y9 contains 12-15, 28-31
// Assumes Y7 == 0.
#define FOLD32 \
	VPUNPCKLWD Y7, Y8, Y0	\
	VPUNPCKHWD Y7, Y8, Y8	\
	VPUNPCKLWD Y7, Y9, Y1	\
	VPUNPCKHWD Y7, Y9, Y9	\
	VPUNPCKLWD Y7, Y10, Y2	\
	VPUNPCKHWD Y7, Y10, Y10	\
	VPUNPCKLWD Y7, Y11, Y3	\
	VPUNPCKHWD Y7, Y11, Y11	\
	VPADDD Y0, Y2, Y0	\
	VPADDD Y8, Y10, Y8	\
	VPADDD Y1, Y3, Y1	\
	VPADDD Y9, Y11, Y9

// zero-extend dwords in Y trashing Y and Z.  Add the low
// half dwords to a*8(DI) and the high half to b*8(DI).
// Assumes Y7 == 0
#define ACCUM(a, b, Y, Z) \
	VPERMQ $0xd8, Y, Y \
	VPUNPCKHDQ Y7, Y, Z \
	VPUNPCKLDQ Y7, Y, Y \
	VPADDQ (a)*8(DI), Y, Y \
	VPADDQ (b)*8(DI), Z, Z \
	VMOVDQU Y, (a)*8(DI) \
	VMOVDQU Z, (b)*8(DI)

// Count8 accumulation function.  Accumulates words Y8--Y11
// into 8 qword counters at (DI).  Trashes Y0--Y12.
TEXT accum8<>(SB), NOSPLIT, $0-0
	FOLD32

	VPADDD Y1, Y0, Y0		// 0- 3,  0- 3
	VPADDD Y9, Y8, Y8		// 4- 7,  4- 7
	VPERM2I128 $0x20, Y8, Y0, Y1
	VPERM2I128 $0x31, Y8, Y0, Y2
	VPADDD Y2, Y1, Y0		// 0- 3,  4- 7
	ACCUM(0, 4, Y0, Y1)
	RET

// Count16 accumulation function.  Accumulates words Y8--Y11
// into 16 qword counters at (DI).  Trashes Y0--Y12.
TEXT accum16<>(SB), NOSPLIT, $0-0
	FOLD32

	// fold over upper 16 bit over lower 32 counters
	VPERM2I128 $0x20, Y8, Y0, Y2	//  0- 3,  4- 7
	VPERM2I128 $0x31, Y8, Y0, Y10	// 16-19, 20-23
	VPADDD Y2, Y10, Y0		//  0- 7
	VPERM2I128 $0x20, Y9, Y1, Y3	//  8-11, 12-15
	VPERM2I128 $0x31, Y9, Y1, Y11	// 24-27, 29-31
	VPADDD Y3, Y11, Y2		//  8-15

	// zero extend into qwords and add to counters
	ACCUM(0, 4, Y0, Y1)
	ACCUM(8, 12, Y2, Y3)

	RET

// Count32 accumulation function.  Accumulates words Y8--Y11
// int 32 qword counters at (DI).  Trashes Y0--Y12
TEXT accum32<>(SB), NOSPLIT, $0-0
	FOLD32

	ACCUM( 0, 16, Y0, Y2)
	ACCUM( 4, 20, Y8, Y2)
	ACCUM( 8, 24, Y1, Y2)
	ACCUM(12, 28, Y9, Y2)

	RET

// accumulate the 16 counters in Y into k*8(DI) to (k+15)*8(DI)
// trashes Y0--Y3.  Assumes Y12 == 0
#define ACCUM64(k, Y) \
	VPUNPCKLWD Y7, Y, Y0 \
	VPUNPCKHWD Y7, Y, Y1 \
	ACCUM(k, k+16, Y0, Y2) \
	ACCUM(k+4, k+20, Y1, Y2)

// Count64 accumulation function.  Accumulates words Y8--Y11
// into 64 qword counters at (DI).  Trashes Y0--Y12.
TEXT accum64<>(SB), NOSPLIT, $0-0
	ACCUM64(0, Y8)
	ACCUM64(8, Y9)
	ACCUM64(32, Y10)
	ACCUM64(40, Y11)
	RET

// func count8avx2(counts *[8]int, buf []uint8)
TEXT ·count8avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum8<>(SB), BX
	CALL countavx<>(SB)
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

// func count32avx2(counts *[32]int, buf []uint32)
TEXT ·count32avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum32<>(SB), BX
	SHLQ $2, CX			// count in bytes
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
