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
// requires magic constants 0x00aa00aa in Y6 and 0x0000cccc in Y5
#define TRANSPOSE(Y) \
	BITPERMUTE(Y, Y6, $7) \
	BITPERMUTE(Y, Y5, $14)

// swap the bits of Y selected by mask M with those S bits to the left
#define BITPERMUTE(Y, M, S) \
	VPSRLD S, Y, Y4 \
	VPXOR Y, Y4, Y4 \
	VPAND Y4, M, Y4 \
	VPXOR Y, Y4, Y \
	VPSLLD S, Y4, Y4 \
	VPXOR Y, Y4, Y

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in BX, a possibly unaligned input buffer in SI,
// counters in DI and a remaining length in BP.
TEXT countavx<>(SB), NOSPLIT, $160-0
	TESTL BP, BP			// any data to process at all?
	CMOVLEQ BP, SI			// if not, avoid loading head

	// constants for processing the head
	VPBROADCASTQ magic<>+32(SB), Y6	// bit position mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// load head into scratch space (until alignment/end is reached)
	MOVL SI, DX
	ANDL $31, DX			// offset of the buffer start from 32 byte alignment
	JEQ nohead			// if source buffer is aligned, skip head processing
	MOVL $32, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	VMOVDQA -32(SI)(AX*1), Y7	// load head
	MOVL $window<>(SB), DX		// load window mask base pointer
	VMOVDQU (DX)(AX*1), Y5		// load mask of the bytes that are part of the head
	VPAND Y5, Y7, Y7		// and mask out those bytes that are not
	CMPL AX, BP			// is the head shorter than the buffer?
	JLT norunt			// if yes, perform special processing

	// buffer is short and does not cross a 32 byte boundary
	SUBL BP, AX			// number of bytes by which we overshoot the buffer
	VMOVDQU (DX)(AX*1), Y5		// load mask of bytes that overshoot the buffer
	VPANDN Y7, Y5, Y7		// and clear them in Y4
	MOVL BP, AX			// set up the true prefix length

norunt:	VMOVDQU Y7, scratch-160(SP)	// copy to scratch space
	SUBL AX, BP			// mark head as accounted for
	MOVL SI, DX			// keep a copy of the head pointer
	ADDL AX, SI			// and advance past head

	ANDL $31, DX			// compute misalignment again
	SHRL $3, DX			// misalignment in qwords (rounded down)
	ANDL $3, DX			// and reduced to range 0--3

	// process head, 8 bytes at a time (up to 4 times)
head:	VPBROADCASTD scratch-160+0(SP)(DX*8), Y4
					// Y4 = 3210:3210:3210:3210:3210:3210:3210:3210
	VPBROADCASTD scratch-160+4(SP)(DX*8), Y5
	VPSHUFB Y3, Y4, Y4		// Y4 = 3333:3333:2222:2222:1111:1111:0000:0000
	VPSHUFB Y3, Y5, Y5
	VPAND Y6, Y4, Y4		// mask out one bit in each copy of the bytes
	VPAND Y6, Y5, Y5
	VPCMPEQB Y6, Y4, Y4		// set bytes to -1 if the bits were set
	VPCMPEQB Y6, Y5, Y5		// or to 0 otherwise
	VPSUBB Y4, Y0, Y0		// add 1/0 (subtract -1/0) to counters
	VPSUBB Y5, Y1, Y1
	ADDL $1, DX
	CMPL DX, $4			// have we processed the full head?
	JLT head

	// produce 16 byte aligned point to counter vector in DX
nohead:	MOVL $counts-160+31(SP), DX
	ANDL $~31, DX			// align to 32 bytes

	// initialise counters to what we have
	VPXOR Y7, Y7, Y7		// zero register
	VPUNPCKLBW Y7, Y0, Y4		// 0-7, 16-23
	VMOVDQA Y4, 0*32(DX)
	VPUNPCKHBW Y7, Y0, Y5		// 8-15, 24-31
	VMOVDQA Y5, 1*32(DX)
	VPUNPCKLBW Y7, Y1, Y6		// 32-39, 48-55
	VMOVDQA Y6, 2*32(DX)
	VPUNPCKHBW Y7, Y1, Y7		// 40-47, 56-63
	VMOVDQA Y7, 3*32(DX)

	SUBL $15*32, BP			// enough data left to process?
	JLT endvec			// also, pre-subtract

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

	// load magic constants
	VPBROADCASTD magic<>+40(SB), Y5	// 0x0000cccc for transpose
	VPBROADCASTD magic<>+44(SB), Y6	// 0x00aa00aa for transpose
	VPBROADCASTD magic<>+48(SB), Y7	// 0x0f0f0f0f for deinterleaving the nibbles

	ADDL $15*32, SI
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
	VPUNPCKHBW Y3, Y2, Y4		// Y4 = DDCCDDCC (hi)
	VPUNPCKLBW Y3, Y2, Y2		// Y2 = DDCCDDCC (lo)
	VPUNPCKHBW Y1, Y0, Y3		// Y3 = BBAABBAA (hi)
	VPUNPCKLBW Y1, Y0, Y0		// Y0 = BBAABBAA (lo)
	VPUNPCKHWD Y2, Y0, Y1		// Y1 = DDCCBBAA (1)
	VPUNPCKLWD Y2, Y0, Y0		// Y0 = DDCCBBAA (0)
	VPUNPCKLWD Y4, Y3, Y2		// Y2 = DDCCBBAA (2)
	VPUNPCKHWD Y4, Y3, Y3		// Y3 = DDCCBBAA (3)

	// pseudo-transpose the 8x4 bit matrix in each dword
	TRANSPOSE(Y0)
	TRANSPOSE(Y1)
	TRANSPOSE(Y2)
	TRANSPOSE(Y3)

	// pull out low nibbles from matrices
	VPAND Y0, Y7, Y5
	VPSRLD $4, Y0, Y0
	VPAND Y1, Y7, Y4
	VPSRLD $4, Y1, Y1
	VPAND Y2, Y7, Y6
	VPSRLD $4, Y2, Y2
	VPADDB Y5, Y6, Y5
	VPAND Y3, Y7, Y6
	VPSRLD $4, Y3, Y3
	VPADDB Y4, Y6, Y6
//	VPERM2I128 $0x20, Y6, Y5, Y4
	BYTE $0xc4
	BYTE $0xe3
	BYTE $0x55
	BYTE $0x46
	BYTE $0xe6
	BYTE $0x20
//	VPERM2I128 $0x31, Y6, Y5, Y5
	BYTE $0xc4
	BYTE $0xe3
	BYTE $0x55
	BYTE $0x46
	BYTE $0xee
	BYTE $0x31
	VPADDB Y5, Y4, Y4


	// pull out high nibbles from matrices
	VPAND Y0, Y7, Y0
	VPAND Y1, Y7, Y1
	VPAND Y2, Y7, Y2
	VPAND Y3, Y7, Y3

	// sum up high nibbles into Y5
	VPADDB Y0, Y2, Y2
	VPADDB Y1, Y3, Y3
//	VPERM2I128 $0x20, Y3, Y2, Y0
//	VPERM2I128 $0x31, Y3, Y2, Y1
	BYTE $0xc4
	BYTE $0xe3
	BYTE $0x6d
	BYTE $0x46
	BYTE $0xc3
	BYTE $0x20
	BYTE $0xc4
	BYTE $0xe3
	BYTE $0x6d
	BYTE $0x46
	BYTE $0xcb
	BYTE $0x31
	VPADDB Y1, Y0, Y5

	VPUNPCKLDQ Y5, Y4, Y2
	VPUNPCKHDQ Y5, Y4, Y3
//	VPERM2I128 $0x20, Y3, Y2, Y0
//	VPERM2I128 $0x31, Y3, Y2, Y1
	BYTE $0xc4
	BYTE $0xe3
	BYTE $0x6d
	BYTE $0x46
	BYTE $0xc3
	BYTE $0x20
	BYTE $0xc4
	BYTE $0xe3
	BYTE $0x6d
	BYTE $0x46
	BYTE $0xcb
	BYTE $0x31

	// zero-extend and add to Y8--Y11
	VPXOR Y7, Y7, Y7
	VPUNPCKLBW Y7, Y0, Y4
	VPUNPCKHBW Y7, Y0, Y5
	VPUNPCKLBW Y7, Y1, Y6
	VPUNPCKHBW Y7, Y1, Y1

	VPADDW 0*32(DX), Y4, Y4
	VPADDW 1*32(DX), Y5, Y5
	VPADDW 2*32(DX), Y6, Y6
	VPADDW 3*32(DX), Y1, Y1

	// write back to counters
	VMOVDQA Y4, 0*32(DX)
	VMOVDQA Y5, 1*32(DX)
	VMOVDQA Y6, 2*32(DX)
	VMOVDQA Y1, 3*32(DX)

	SUBL $15*4, AX			// account for possible overflow
	CMPL AX, $15*4			// enough space left in the counters?
	JGE have_space

	// flush accumulators into counters
	CALL *BX			// call accumulation function
	VPXOR Y7, Y7, Y7
	VMOVDQA Y7, 0*32(DX)
	VMOVDQA Y7, 1*32(DX)
	VMOVDQA Y7, 2*32(DX)
	VMOVDQA Y7, 3*32(DX)

	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBL $15*32, BP			// account for bytes consumed
	JGE vec

endvec:	VPBROADCASTQ magic<>+32(SB), Y2	// byte mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// process tail, 8 bytes at a time
	SUBL $8-15*32, BP		// 8 bytes left to process?
	JLT tail1

tail8:	VPBROADCASTD 0(SI), Y4
	VPBROADCASTD 4(SI), Y5
	ADDL $8, SI
	VPSHUFB Y3, Y4, Y4
	VPSHUFB Y3, Y5, Y5
	VPAND Y2, Y4, Y4
	VPAND Y2, Y5, Y5
	VPCMPEQB Y2, Y4, Y4
	VPCMPEQB Y2, Y5, Y5
	VPSUBB Y4, Y0, Y0
	VPSUBB Y5, Y1, Y1
	SUBL $8, BP
	JGE tail8

	// process remaining 0--7 byte
tail1:	SUBL $-8, BP			// anything left to process?
	JLE end

//	VMOVQ (SI), X5			// load 8 byte from buffer.  This is ok
					// as buffer is aligned to 8 byte here
	BYTE $0xc5
	BYTE $0xfa
	BYTE $0x7e
	BYTE $0x2e
	MOVL $window<>+32(SB), AX	// load window address
	SUBL BP, AX			// adjust mask pointer
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
	VPUNPCKHBW Y7, Y1, Y1

	VPADDW 0*32(DX), Y4, Y4
	VPADDW 1*32(DX), Y5, Y5
	VPADDW 2*32(DX), Y6, Y6
	VPADDW 3*32(DX), Y1, Y1

	// write back to counters
	VMOVDQA Y4, 0*32(DX)
	VMOVDQA Y5, 1*32(DX)
	VMOVDQA Y6, 2*32(DX)
	VMOVDQA Y1, 3*32(DX)

	// and perform a final accumulation
	CALL *BX
	VZEROUPPER
	RET

// Count8 accumulation function.  Accumulates words
// into 8 dword counters at (DI).  Trashes Y0--Y7.
TEXT accum8<>(SB), NOSPLIT, $0-0
	VPMOVZXWD 0*16(DX), Y0
	VPMOVZXWD 1*16(DX), Y2
	VPMOVZXWD 2*16(DX), Y1
	VPMOVZXWD 3*16(DX), Y3
	VPMOVZXWD 4*16(DX), Y4
	VPMOVZXWD 5*16(DX), Y6
	VPMOVZXWD 6*16(DX), Y5
	VPMOVZXWD 7*16(DX), Y7
	VPADDD Y0, Y4, Y0
	VPADDD Y1, Y5, Y1
	VPADDD Y2, Y6, Y2
	VPADDD Y3, Y7, Y3
	VPADDD Y0, Y2, Y0
	VPADDD Y1, Y3, Y1
	VPADDD Y1, Y0, Y0
	VPADDD 0*32(DI), Y0, Y0
	VMOVDQU Y0, 0*32(DI)
	RET

// Count16 accumulation function.  Accumulates words
// into 16 dword counters at (DI).  Trashes Y0--Y7.
TEXT accum16<>(SB), NOSPLIT, $0-0
	VPMOVZXWD 0*16(DX), Y0
	VPMOVZXWD 1*16(DX), Y2
	VPMOVZXWD 2*16(DX), Y1
	VPMOVZXWD 3*16(DX), Y3
	VPMOVZXWD 4*16(DX), Y4
	VPMOVZXWD 5*16(DX), Y6
	VPMOVZXWD 6*16(DX), Y5
	VPMOVZXWD 7*16(DX), Y7
	VPADDD Y0, Y4, Y0
	VPADDD Y1, Y5, Y1
	VPADDD Y2, Y6, Y2
	VPADDD Y3, Y7, Y3
	VPADDD Y0, Y2, Y0
	VPADDD Y1, Y3, Y1
	VPADDD 0*32(DI), Y0, Y0
	VPADDD 1*32(DI), Y1, Y1
	VMOVDQU Y0, 0*32(DI)
	VMOVDQU Y1, 1*32(DI)
	RET

// Count32 accumulation function.  Accumulates words
// into 32 dword counters at (DI).  Trashes Y0--Y7.
TEXT accum32<>(SB), NOSPLIT, $0-0
	VPMOVZXWD 0*16(DX), Y0
	VPMOVZXWD 1*16(DX), Y2
	VPMOVZXWD 2*16(DX), Y1
	VPMOVZXWD 3*16(DX), Y3
	VPMOVZXWD 4*16(DX), Y4
	VPMOVZXWD 5*16(DX), Y6
	VPMOVZXWD 6*16(DX), Y5
	VPMOVZXWD 7*16(DX), Y7
	VPADDD Y0, Y4, Y0
	VPADDD Y1, Y5, Y1
	VPADDD Y2, Y6, Y2
	VPADDD Y3, Y7, Y3
	VPADDD 0*32(DI), Y0, Y0
	VPADDD 1*32(DI), Y1, Y1
	VPADDD 2*32(DI), Y2, Y2
	VPADDD 3*32(DI), Y3, Y3
	VMOVDQU Y0, 0*32(DI)
	VMOVDQU Y1, 1*32(DI)
	VMOVDQU Y2, 2*32(DI)
	VMOVDQU Y3, 3*32(DI)
	RET

// Count64 accumulation function.  Accumulates words
// into 64 dword counters at (DI).  Trashes Y0--Y3.
TEXT accum64<>(SB), NOSPLIT, $0-0
	VPMOVZXWD 0*16(DX), Y0
	VPMOVZXWD 1*16(DX), Y2
	VPMOVZXWD 2*16(DX), Y1
	VPMOVZXWD 3*16(DX), Y3
	VPADDD 0*32(DI), Y0, Y0
	VPADDD 1*32(DI), Y1, Y1
	VPADDD 2*32(DI), Y2, Y2
	VPADDD 3*32(DI), Y3, Y3
	VMOVDQU Y0, 0*32(DI)
	VMOVDQU Y1, 1*32(DI)
	VMOVDQU Y2, 2*32(DI)
	VMOVDQU Y3, 3*32(DI)
	VPMOVZXWD 4*16(DX), Y0
	VPMOVZXWD 5*16(DX), Y2
	VPMOVZXWD 6*16(DX), Y1
	VPMOVZXWD 7*16(DX), Y3
	VPADDD 4*32(DI), Y0, Y0
	VPADDD 5*32(DI), Y1, Y1
	VPADDD 6*32(DI), Y2, Y2
	VPADDD 7*32(DI), Y3, Y3
	VMOVDQU Y0, 4*32(DI)
	VMOVDQU Y1, 5*32(DI)
	VMOVDQU Y2, 6*32(DI)
	VMOVDQU Y3, 7*32(DI)
	RET

// func count8avx2(counts *[8]int, buf []uint8)
TEXT ·count8avx2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum8<>(SB), BX
	CALL countavx<>(SB)
	RET

// func count16avx2(counts *[16]int, buf []uint16)
TEXT ·count16avx2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum16<>(SB), BX
	SHLL $1, BP			// count in bytes
	CALL countavx<>(SB)
	RET

// func count32avx2(counts *[32]int, buf []uint32)
TEXT ·count32avx2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum32<>(SB), BX
	SHLL $2, BP			// count in bytes
	CALL countavx<>(SB)
	RET

// func count64avx2(counts *[64]int, buf []uint64)
TEXT ·count64avx2(SB), 0, $0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), BP		// BP = len(buf)
	MOVL $accum64<>(SB), BX
	SHLL $3, BP			// count in bytes
	CALL countavx<>(SB)
	RET
