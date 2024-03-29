#include "textflag.h"

// An AVX2 based kernel first doing a 15-fold CSA reduction and then
// a 16-fold CSA reduction, carrying over place-value vectors between
// iterations.
// Required CPU extension: AVX2, BMI2.

// magic transposition constants, comparison constants
DATA magic<>+ 0(SB)/8, $0x0000000000000000
DATA magic<>+ 8(SB)/8, $0x0101010101010101
DATA magic<>+16(SB)/8, $0x0202020202020202
DATA magic<>+24(SB)/8, $0x0303030303030303
DATA magic<>+32(SB)/8, $0x0404040404040404
DATA magic<>+40(SB)/8, $0x0505050505050505
DATA magic<>+48(SB)/8, $0x0606060606060606
DATA magic<>+56(SB)/8, $0x0707070707070707
DATA magic<>+64(SB)/8, $0x8040201008040201
DATA magic<>+72(SB)/4, $0x55555555
DATA magic<>+76(SB)/4, $0x33333333
DATA magic<>+80(SB)/4, $0x0f0f0f0f
DATA magic<>+84(SB)/4, $0x00ff00ff
GLOBL magic<>(SB), RODATA|NOPTR, $88

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

// count 8 bytes from L into Y0 and Y1,
// using Y4, and Y5 for scratch space
#define COUNT8(L) \
	VPBROADCASTQ L, Y4 \	// Y4 = 7654:3210:7654:3210:7654:3210:7654:3210
	VPSHUFB Y7, Y4, Y5 \	// Y5 = 7777:7777:6666:6666:5555:5555:4444:4444
	VPSHUFB Y3, Y4, Y4 \	// Y4 = 3333:3333:2222:2222:1111:1111:0000:0000
	VPAND Y2, Y5, Y5 \
	VPAND Y2, Y4, Y4 \	// mask out one bit in each copy of the bytes
	VPCMPEQB Y2, Y5, Y5 \	// set bytes to -1 if the bits were set
	VPCMPEQB Y2, Y4, Y4 \	// or to 0 otherwise
	VPSUBB Y5, Y1, Y1 \
	VPSUBB Y4, Y0, Y0	// add 1/0 (subtract -1/0) to counters


// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in BX, a possibly unaligned input buffer in SI,
// counters in DI and a remaining length in CX.
TEXT countavx2<>(SB), NOSPLIT, $0-0
	CMPQ CX, $15*32			// is the CSA kernel worth using?
	JLT runt

	// load head until alignment/end is reached
	MOVL SI, DX
	ANDL $31, DX			// offset of the buffer start from 32 byte alignment
	MOVL $32, AX
	SUBL DX, AX			// number of bytes til alignment is reached (head length)
	SUBQ DX, SI			// align source to 32 bytes
	VMOVDQA (SI), Y0		// load head
	ADDQ DX, CX			// and account for head length
	LEAQ window<>(SB), DX		// load window mask base pointer
	VPAND (DX)(AX*1), Y0, Y0	// mask out bytes not in head

	VMOVDQA 1*32(SI), Y1		// load 480 (-32) bytes from buf
	VMOVDQA 2*32(SI), Y4		// and sum them into Y3:Y2:Y1:Y0
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
	VPBROADCASTD magic<>+72(SB), Y15 // 0x55555555
	VPBROADCASTD magic<>+76(SB), Y13 // 0x33333333
	CSA(Y0, Y4, Y6, Y7)
	VPXOR Y8, Y8, Y8		// initialise counters
	VPXOR Y9, Y9, Y9
	CSA(Y1, Y4, Y5, Y7)
	VPXOR Y10, Y10, Y10
	VPXOR Y11, Y11, Y11
	CSA(Y2, Y3, Y4, Y7)

	ADDQ $15*32, SI
	SUBQ $(15+16)*32, CX		// enough data left to process?
	JLT post

	MOVL $65535, AX			// space left til overflow could occur in Y8--Y11

	// load 512 bytes from buf, add them to Y0..Y3 into Y0..Y4
vec:	VMOVDQA 0*32(SI), Y4
	VMOVDQA 1*32(SI), Y5
	VMOVDQA 2*32(SI), Y6
	VMOVDQA 3*32(SI), Y12
	VMOVDQA 4*32(SI), Y14
	CSA(Y0, Y4, Y5, Y7)
	VMOVDQA 5*32(SI), Y5
	CSA(Y6, Y12, Y14, Y7)
	VMOVDQA 6*32(SI), Y14
	CSA(Y1, Y4, Y12, Y7)
	VMOVDQA 7*32(SI), Y12
	CSA(Y0, Y5, Y6, Y7)
	VMOVDQA 8*32(SI), Y6
	CSA(Y6, Y12, Y14, Y7)
	VMOVDQA 9*32(SI), Y14
	CSA(Y1, Y5, Y12, Y7)
	VMOVDQA 10*32(SI), Y12
	CSA(Y0, Y12, Y14, Y7)
	VMOVDQA 11*32(SI), Y14
	CSA(Y2, Y4, Y5, Y7)
	VMOVDQA 12*32(SI), Y5
	CSA(Y0, Y6, Y14, Y7)
	VMOVDQA 13*32(SI), Y14
	CSA(Y1, Y6, Y12, Y7)
	VMOVDQA 14*32(SI), Y12
	CSA(Y5, Y12, Y14, Y7)
	VMOVDQA 15*32(SI), Y14
	CSA(Y0, Y5, Y14, Y7)
	ADDQ $16*32, SI
	PREFETCHT0 0(SI)
	PREFETCHT0 32(SI)
	CSA(Y1, Y5, Y12, Y7)
	CSA(Y2, Y5, Y6, Y7)
	CSA(Y3, Y4, Y5, Y7)


	VPBROADCASTD magic<>+84(SB), Y12 // 0x00ff00ff
	VPBROADCASTD magic<>+80(SB), Y14 // 0x0f0f0f0f

	// now Y0..Y4 hold counters; preserve Y0..Y4 for the next round
	// and add Y4 to the counters.

	// split into even/odd and reduce into crumbs
	VPAND Y4, Y15, Y5		// Y5 = 02468ace x16
	VPANDN Y4, Y15, Y6		// Y6 = 13579bdf x16
	VPSRLD $1, Y6, Y6
	VPERM2I128 $0x20, Y6, Y5, Y4
	VPERM2I128 $0x31, Y6, Y5, Y5
	VPADDD Y5, Y4, Y4		// Y4 = 02468ace x8 13579bdf x8

	// split again and reduce into nibbles
	VPAND Y4, Y13, Y5		// Y5 = 048c x8 159d x8
	VPANDN Y4, Y13, Y6		// Y6 = 26ae x8 37bf x8
	VPSRLD $2, Y6, Y6
	VPUNPCKLQDQ Y6, Y5, Y4
	VPUNPCKHQDQ Y6, Y5, Y5
	VPADDD Y5, Y4, Y4		// Y4 = 048c x4 26ae x4 159d x4 37bf x4

	// split again into bytes and shuffle into order
	VPAND Y4, Y14, Y5		// Y5 = 08 x4 2a x4 19 x4 3b x4
	VPANDN Y4, Y14, Y6		// Y4 = 4c x4 6e x4 5d x4 7f x4
	VPSLLD $4, Y5, Y5
	VPERM2I128 $0x20, Y6, Y5, Y4	// Y4 = 08 x4 2a x4 4c x4 6e x4
	VPERM2I128 $0x31, Y6, Y5, Y5	// Y5 = 19 x4 3b x4 5d x4 7f x4
	VPUNPCKLWD Y5, Y4, Y6		// Y6 = 0819 x4 4c5d x4
	VPUNPCKHWD Y5, Y4, Y7		// Y7 = 2a3b x4 6e7f x4
	VPUNPCKLDQ Y7, Y6, Y4		// Y4 = 08192a3b[0:1] 4c5d6e7f[0:1]
	VPUNPCKHDQ Y7, Y6, Y5		// Y5 = 08192a3b[2:3] 4c5d6e7f[2:3]
	VPERMQ $0xd8, Y4, Y4		// Y4 = 08192a3b4c5d6e7f[0:1]
	VPERMQ $0xd8, Y5, Y5		// Y5 = 08192a3b4c5d6e7f[2:3]

	// split again into words and add to counters
	VPAND Y4, Y12, Y6		// Y6 = 01234567[0:1]
	VPAND Y5, Y12, Y7		// Y7 = 01234567[2:3]
	VPADDW Y6, Y8, Y8
	VPADDW Y7, Y10, Y10
	VPSRLW $8, Y4, Y4		// Y4 = 89abcdef[0:1]
	VPSRLW $8, Y5, Y5		// Y5 = 89abcdef[2:3]
	VPADDW Y4, Y9, Y9
	VPADDW Y5, Y11, Y11

	SUBL $16*4, AX			// account for possible overflow
	CMPL AX, $(15+15)*4		// enough space left in the counters?
	JGE have_space

	// flush accumulators into counters
	VPXOR Y7, Y7, Y7
	CALL *BX			// call accumulation function
	VPXOR Y8, Y8, Y8		// clear accumulators for next round
	VPXOR Y9, Y9, Y9
	VPXOR Y10, Y10, Y10
	VPXOR Y11, Y11, Y11

	MOVL $65535, AX			// space left til overflow could occur

have_space:
	SUBQ $16*32, CX			// account for bytes consumed
	JGE vec

	// group nibbles in Y0, Y1, Y2, and Y3 into Y4, Y5, Y6, and Y7
post:	VPBROADCASTD magic<>+80(SB), Y14 // 0x0f0f0f0f

	VPAND Y1, Y15, Y5
	VPADDD Y5, Y5, Y5
	VPAND Y3, Y15, Y7
	VPADDD Y7, Y7, Y7
	VPAND Y0, Y15, Y4
	VPAND Y2, Y15, Y6
	VPOR Y4, Y5, Y4			// Y4 = eca86420 (low crumbs)
	VPOR Y6, Y7, Y5			// Y5 = eca86420 (high crumbs)

	VPANDN Y0, Y15, Y0
	VPSRLD $1, Y0, Y0
	VPANDN Y2, Y15, Y2
	VPSRLD $1, Y2, Y2
	VPANDN Y1, Y15, Y1
	VPANDN Y3, Y15, Y3
	VPOR Y0, Y1, Y6			// Y6 = fdb97531 (low crumbs)
	VPOR Y2, Y3, Y7			// Y7 = fdb97531 (high crumbs)

	VPAND Y5, Y13, Y1
	VPSLLD $2, Y1, Y1
	VPAND Y7, Y13, Y3
	VPSLLD $2, Y3, Y3
	VPAND Y4, Y13, Y0
	VPAND Y6, Y13, Y2
	VPOR Y0, Y1, Y0			// Y0 = c840
	VPOR Y2, Y3, Y1			// Y1 = d951

	VPANDN Y4, Y13, Y4
	VPSRLD $2, Y4, Y4
	VPANDN Y6, Y13, Y6
	VPSRLD $2, Y6, Y6
	VPANDN Y5, Y13, Y5
	VPANDN Y7, Y13, Y7
	VPOR Y4, Y5, Y2			// Y2 = ea62
	VPOR Y6, Y7, Y3			// Y3 = fb73

	// pre-shuffle nibbles
	VPUNPCKLBW Y1, Y0, Y5		// Y5 = d9c85140         (3:2:1:0)
	VPUNPCKHBW Y1, Y0, Y0		// Y0 = d9c85140         (7:6:5:4)
	VPUNPCKLBW Y3, Y2, Y6		// Y6 = fbea7362         (3:2:1:0)
	VPUNPCKHBW Y3, Y2, Y1		// Y1 = fbea7362         (3:2:1:0)
	VPUNPCKLWD Y6, Y5, Y4		// Y4 = fbead9c873625140 (1:0)
	VPUNPCKHWD Y6, Y5, Y5		// Y5 = fbead9c873625140 (3:2)
	VPUNPCKLWD Y1, Y0, Y6		// Y6 = fbead9c873624150 (5:4)
	VPUNPCKHWD Y1, Y0, Y7		// Y7 = fbead9c873624150 (7:6)

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

endvec:	CMPL CX, $-16*32		// no bytes left to process?
	JE end

	VPBROADCASTQ magic<>+64(SB), Y2	// byte mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VMOVDQU magic<>+32(SB), Y7
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register

	// process tail, 8 bytes at a time
	SUBL $8-16*32, CX		// 8 bytes left to process?
	JLE tail1

tail8:	COUNT8((SI))
	ADDQ $8, SI
	SUBL $8, CX
	JGT tail8

	// process remaining 1--8 bytes
tail1:	MOVL $8*8(CX*8), CX
	BZHIQ CX, (SI), AX		// load tail into AX (will never fault)
	VMOVQ AX, X6
	COUNT8(X6)

	// add tail to counters
	VPXOR Y7, Y7, Y7
	VPUNPCKLBW Y7, Y0, Y4
	VPUNPCKHBW Y7, Y0, Y5
	VPUNPCKLBW Y7, Y1, Y6
	VPUNPCKHBW Y7, Y1, Y7

	VPADDW Y4, Y8, Y8
	VPADDW Y5, Y9, Y9
	VPADDW Y6, Y10, Y10
	VPADDW Y7, Y11, Y11

	// and perform a final accumulation
end:	VPXOR Y7, Y7, Y7
	CALL *BX
	VZEROUPPER
	RET

	// buffer is short, do just head/tail processing
runt:	VPBROADCASTQ magic<>+64(SB), Y2	// bit position mask
	VMOVDQU magic<>+0(SB), Y3	// permutation mask
	VMOVDQU magic<>+32(SB), Y7
	VPXOR Y0, Y0, Y0		// lower counter register
	VPXOR Y1, Y1, Y1		// upper counter register
	SUBL $8, CX			// 8 byte left to process?
	JLT runt1

	// process runt, 8 bytes at a time
runt8:	COUNT8((SI))
	ADDQ $8, SI
	SUBL $8, CX
	JGE runt8

	// process remaining 0--7 byte
	// while making sure we don't get a page fault
runt1:	CMPL CX, $-8			// anything left to process?
	JLE runt_accum

	LEAL 7(SI)(CX*1), DX		// last address of buffer
	XORL SI, DX			// which bits changed?
	LEAL 8*8(CX*8), CX		// CX scaled to a bit length
	TESTL $8, DX			// did we cross an alignment boundary?
	JNE crossrunt1			// if yes, we can safely load directly

	LEAL (SI*8), AX
	ANDQ $~7, SI			// align buffer to 8 bytes
	MOVQ (SI), R8			// and load 8 bytes from buffer
	SHRXQ AX, R8, R8		// buffer starting at the beginning
	BZHIQ CX, R8, R8		// mask out bytes past the buffer
	JMP dorunt1

crossrunt1:
	BZHIQ CX, (SI), R8		// load 8 bytes from unaligned buffer

dorunt1:VMOVQ R8, X6
	COUNT8(X6)

	// move tail to counters and perform final accumulation
runt_accum:
	VPXOR Y7, Y7, Y7
	VPUNPCKLBW Y7, Y0, Y8
	VPUNPCKHBW Y7, Y0, Y9
	VPUNPCKLBW Y7, Y1, Y10
	VPUNPCKHBW Y7, Y1, Y11
	CALL *BX
	VZEROUPPER
	RET

// zero extend Y8--Y11 into dwords and fold the upper 32 counters
// over the lower 32 counters, leaving the registers with
// Y12 contains  0- 3, 16-19
// Y8  contains  4- 7, 20-23
// Y14 contains  8-11, 24-27
// Y9  contains 12-15, 28-31
// Assumes Y7 == 0.
#define FOLD32 \
	VPUNPCKLWD Y7, Y8, Y12	\
	VPUNPCKHWD Y7, Y8, Y8	\
	VPUNPCKLWD Y7, Y9, Y14	\
	VPUNPCKHWD Y7, Y9, Y9	\
	VPUNPCKLWD Y7, Y10, Y4	\
	VPUNPCKHWD Y7, Y10, Y10	\
	VPUNPCKLWD Y7, Y11, Y5	\
	VPUNPCKHWD Y7, Y11, Y11	\
	VPADDD Y12, Y4, Y12	\
	VPADDD Y8, Y10, Y8	\
	VPADDD Y14, Y5, Y14	\
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

	VPADDD Y14, Y12, Y12		// 0- 3,  0- 3
	VPADDD Y9, Y8, Y8		// 4- 7,  4- 7
	VPERM2I128 $0x20, Y8, Y12, Y14
	VPERM2I128 $0x31, Y8, Y12, Y4
	VPADDD Y4, Y14, Y12		// 0- 3,  4- 7
	ACCUM(0, 4, Y12, Y14)
	RET

// Count16 accumulation function.  Accumulates words Y8--Y11
// into 16 qword counters at (DI).  Trashes Y0--Y12.
TEXT accum16<>(SB), NOSPLIT, $0-0
	FOLD32

	// fold over upper 16 bit over lower 32 counters
	VPERM2I128 $0x20, Y8, Y12, Y4	//  0- 3,  4- 7
	VPERM2I128 $0x31, Y8, Y12, Y10	// 16-19, 20-23
	VPADDD Y4, Y10, Y12		//  0- 7
	VPERM2I128 $0x20, Y9, Y14, Y5	//  8-11, 12-15
	VPERM2I128 $0x31, Y9, Y14, Y11	// 24-27, 29-31
	VPADDD Y5, Y11, Y4		//  8-15

	// zero extend into qwords and add to counters
	ACCUM(0, 4, Y12, Y14)
	ACCUM(8, 12, Y4, Y5)

	RET

// Count32 accumulation function.  Accumulates words Y8--Y11
// int 32 qword counters at (DI).  Trashes Y0--Y12
TEXT accum32<>(SB), NOSPLIT, $0-0
	FOLD32

	ACCUM( 0, 16, Y12, Y4)
	ACCUM( 4, 20, Y8, Y4)
	ACCUM( 8, 24, Y14, Y4)
	ACCUM(12, 28, Y9, Y4)

	RET

// accumulate the 16 counters in Y into k*8(DI) to (k+15)*8(DI)
// trashes Y0--Y3.  Assumes Y12 == 0
#define ACCUM64(k, Y) \
	VPUNPCKLWD Y7, Y, Y12 \
	VPUNPCKHWD Y7, Y, Y14 \
	ACCUM(k, k+16, Y12, Y4) \
	ACCUM(k+4, k+20, Y14, Y4)

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
	CALL countavx2<>(SB)
	RET

// func count16avx2(counts *[16]int, buf []uint16)
TEXT ·count16avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum16<>(SB), BX
	SHLQ $1, CX			// count in bytes
	CALL countavx2<>(SB)
	RET

// func count32avx2(counts *[32]int, buf []uint32)
TEXT ·count32avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum32<>(SB), BX
	SHLQ $2, CX			// count in bytes
	CALL countavx2<>(SB)
	RET

// func count64avx2(counts *[64]int, buf []uint64)
TEXT ·count64avx2(SB), 0, $0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)
	MOVQ $accum64<>(SB), BX
	SHLQ $3, CX			// count in bytes
	CALL countavx2<>(SB)
	RET
