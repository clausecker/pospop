#include "textflag.h"

// SIMD kernel for the positional population count operation.  All these
// kernels have the same backbone based on a 15-fold CSA reduction to
// first reduce 240 byte into 4x16 byte, followed by a bunch of shuffles
// to group the positional registers into nibbles.  These are then
// summed up using a width-specfic summation function.

// magic transposition constants, sliding window
DATA magic<>+ 0(SB)/8, $0x8040201008040201
DATA magic<>+ 8(SB)/8, $0x0000000000000000
DATA magic<>+16(SB)/8, $0x0000000000000000
DATA magic<>+24(SB)/8, $0xffffffffffffffff
DATA magic<>+32(SB)/8, $0xffffffffffffffff
GLOBL magic<>(SB), RODATA|NOPTR, $40

// B:A = A+B+C, V31 used for scratch space
#define CSA(A, B, C) \
	VEOR B.B16, A.B16, V31.B16 \
	VEOR C.B16, V31.B16, A.B16 \
	VBIT V31.B16, C.B16, B.B16

// D:A = A+B+C
#define CSAC(A, B, C, D) \
	VEOR A.B16, B.B16, D.B16 \
	VEOR D.B16, C.B16, A.B16 \
	VBSL B.B16, C.B16, D.B16

// Process 4 bytes from S.  Add low word counts to L, high to H.
// Assumes masks loaded into V28, V29, and V30.  Trashes V4, V5.
#define COUNT4(L, H, S) \
	VTBL V30.B16, [S.B16], V4.B16 \	// V4 = 0000:0000:1111:1111
	VTBL V29.B16, [S.B16], V5.B16 \	// V5 = 2222:2222:3333:3333
	VCMTST V28.B16, V4.B16, V4.B16 \
	VCMTST V28.B16, V5.B16, V5.B16 \
	VSUB V4.B16, L.B16, L.B16 \
	VSUB V5.B16, H.B16, H.B16

// Generic kernel.  This function expects a pointer to a width-specific
// accumulation function in R0, a possibly unaligned input buffer in R1,
// counters in R2 and a remaining length in R3.
TEXT count<>(SB), NOSPLIT, $0-0
	TST R3, R3			// any data to process at all?
	CSEL EQ, ZR, R1, R1		// if yes, avoid loading head

	// constant for processing the head
	MOVD $magic<>(SB), R4
	VLD1R.P 8(R4), [V28.D2]		// 80402010080402018040201008040201
	VMOVI $1, V30.B8		// 00000000000000000101010101010101
	VMOVI $2, V29.B16		// 02020202020202020202020202020202
	VADD V30.B16, V29.B16, V29.B16	// 02020202020202020303030303030303
	VMOVI $0, V7.B16		// zero register
	VMOVI $0, V8.B16		// counter registers
	VMOVI $0, V10.B16
	VMOVI $0, V12.B16
	VMOVI $0, V14.B16

	// load head until alignment/end is reached
	AND $15, R1, R5			// offset of the buffer start from 16 byte alignment
	CBZ R5, nohead			// if source buffer is aligned skip head processing
	SUB R1, R4, R6			// shifted window mask base pointer
	AND $~15, R1, R1		// align the source buffer pointer
	VLD1.P 16(R1), [V3.B16]		// load head, advance past it
//	VMOVQ 16(R6), V5		// load mask of bytes that are part of the head
	WORD $0x3dc004c5
	VAND V5.B16, V3.B16, V3.B16	// and mask out those bytes that are not
	CMP R5, R3			// is the head shorter than the buffer?
	BLT norunt

	// buffer is short and does not cross a 16 byte boundary
	SUB R5, R3, R5			// number of bytes by which we overshot the buffer
//	VMOVQ (R4)(R5), V5		// load mask of bytes that overshoot the buffer
	WORD $0x3ce56885
//	VBIC V3.B16, V5.B16, V3.B16	// and clear them
	WORD $0x4e631ca3
	MOVD R5, R3			// set up true prefix length

norunt:	SUB R3, R5, R3			// mark head as accounted for

	// process head in increments of 2 bytes
	COUNT4(V8, V10, V3)
	VMOV V3.S[1], V3.S[0]
	COUNT4(V12, V14, V3)
	VMOV V3.S[2], V3.S[0]
	COUNT4(V8, V10, V3)
	VMOV V3.S[3], V3.S[0]
	COUNT4(V12, V14, V3)

	// initialise counters in V8--V15 to what we have
nohead:	VUXTL V8.B8, V9.H8		//  8--15
	VUXTL2 V8.B16, V8.H8		//  0-- 7
	VUXTL V10.B8, V11.H8		// 24--31
	VUXTL2 V10.B16, V10.H8		// 16--23
	VUXTL V12.B8, V13.H8		// 40--47
	VUXTL2 V12.B16, V12.H8		// 32--39
	VUXTL V14.B8, V15.H8		// 56--63
	VUXTL2 V14.B16, V14.H8		// 48--55

	SUBS $15*16, R3, R3		// enough data to process?
	BLT endvec

	MOVD $65535-4, R6		// space left til overflow could occur in V8--V15

	VMOVI $0x55, V27.B16		// 55555555 for transposition
	VMOVI $0x33, V26.B16		// 33333333 for transposition
	VMOVI $0x0f, V25.B16		// 0f0f0f0f for extracting nibbles

vec:	VLD1.P 3*16(R1), [V0.B16, V1.B16, V2.B16]
	VLD1.P 4*16(R1), [V3.B16, V4.B16, V5.B16, V6.B16]
	VLD1.P 4*16(R1), [V16.B16, V17.B16, V18.B16, V19.B16]
	CSA(V0, V1, V2)
	CSAC(V0, V3, V4, V2)
	CSAC(V0, V5, V6, V3)
	VLD1.P 4*16(R1), [V4.B16, V5.B16, V6.B16, V7.B16]
	CSA(V1, V2, V3)
	CSA(V0, V16, V17)
	CSA(V0, V18, V19)
	CSAC(V1, V16, V18, V3)
	CSA(V0, V4, V5)
	CSA(V0, V6, V7)
	CSA(V1, V4, V6)
	CSA(V2, V3, V4)

	// group V0--V3 into nibbles in the same register
	VUSHR $1, V1.B16, V5.B16
	VADD V0.B16, V0.B16, V4.B16
	VUSHR $1, V3.B16, V7.B16
	VADD V2.B16, V2.B16, V6.B16
	VBIF V27.B16, V5.B16, V0.B16	// V0 = eca86420 (low crumbs)
	VBIT V27.B16, V4.B16, V1.B16	// V1 = fdb97531 (high crumbs)
	VBIF V27.B16, V7.B16, V2.B16	// V2 = eca86420 (low crumbs)
	VBIT V27.B16, V6.B16, V3.B16	// V3 = fdb97531 (high crumbs)

	VSHL $2, V0.B16, V4.B16
	VSHL $2, V1.B16, V6.B16
	VUSHR $2, V2.B16, V5.B16
	VUSHR $2, V3.B16, V7.B16
	VBIT V26.B16, V4.B16, V2.B16	// V2 = ea62
	VBIT V26.B16, V6.B16, V3.B16	// V3 = fb73
	VBIF V26.B16, V5.B16, V0.B16	// V0 = c840
	VBIF V26.B16, V7.B16, V1.B16	// V1 = d951

	// pre-shuffle nibbles
	VZIP1 V3.B16, V2.B16, V6.B16	// V6 = fbea7362 (3:2:1:0)
	VZIP2 V3.B16, V2.B16, V3.B16	// V1 = fbea7362 (7:6:5:4)
	VZIP1 V1.B16, V0.B16, V5.B16	// V5 = d9c85140 (3:2:1:0)
	VZIP2 V1.B16, V0.B16, V2.B16	// V0 = d9c85140 (7:6:5:4)
	VZIP1 V6.H8, V5.H8, V4.H8	// V4 = fbead9c873625140 (1:0)
	VZIP2 V6.H8, V5.H8, V5.H8	// V5 = fbead9c873625140 (3:2)
	VZIP1 V3.H8, V2.H8, V6.H8	// V6 = fbead9c873625150 (5:4)
	VZIP2 V3.H8, V2.H8, V7.H8	// V7 = fbead9c873625150 (7:6)

	// pull out high and low nibbles and reduce once
	VAND V4.B16, V25.B16, V0.B16
	VUSHR $4, V4.B16, V4.B16
	VAND V5.B16, V25.B16, V1.B16
	VUSHR $4, V5.B16, V5.B16
	VAND V6.B16, V25.B16, V2.B16
	VADD V0.B16, V2.B16, V0.B16	// V0 = ba983210 (1:0)
//	VUSRA $4, V6.B16, V4.B16	// V4 = fedc7654 (1:0)
	WORD $0x6f0c14c4
	VAND V7.B16, V25.B16, V3.B16
	VADD V1.B16, V3.B16, V1.B16	// V1 = ba983210 (3:2)
//	VUSRA $4, V7.B16, V5.B16	// V5 = fedc7654 (3:2)
	WORD $0x6f0c14e5

	// shuffle one last time
	VZIP1 V4.S4, V0.S4, V2.S4	// V2 = fedcba987654 (0)
	VZIP2 V4.S4, V0.S4, V3.S4	// V3 = fedcba987654 (1)
	VZIP1 V5.S4, V1.S4, V6.S4	// V6 = fedcba987654 (2)
	VZIP2 V5.S4, V1.S4, V7.S4	// V7 = fedcba987654 (3)

	SUB $15*2, R6, R6		// account for possible overflow
	CMP $15*2, R6			// enough space left in the counters?

	// add to counters
//	VUADDW V2.B8, V8.H8, V8.H8
//	VUADDW2 V2.B16, V9.H8. V9.H8
//	VUADDW V3.B8, V10.H8, V10.H8
//	VUADDW2 V3.B16, V11.H8, V11.H8
//	VUADDW V6.B8, V12.H8, V12.H8
//	VUADDW2 V6.B16, V13.H8. V12.H8
//	VUADDW V7.B8, V14.H8, V14.H8
//	VUADDW2 V7.B8, V15.H8, V15.H8
	WORD $0x2e221108
	WORD $0x6e221129
	WORD $0x2e23114a
	WORD $0x6e23116b
	WORD $0x2e26118c
	WORD $0x6e2611ad
	WORD $0x2e2711ce
	WORD $0x6e2711ef

	BGE have_space

	CALL *R0			// call accumulation function
	VMOVI $0, V8.B16		// clear counters for next round
	VMOVI $0, V9.B16
	VMOVI $0, V10.B16
	VMOVI $0, V11.B16
	VMOVI $0, V12.B16
	VMOVI $0, V13.B16
	VMOVI $0, V14.B16
	VMOVI $0, V15.B16

	MOVD $65535, R6			// space left til overflow could occur

have_space:
	SUBS $15*16, R3			// account for bytes consumed
	BGE vec	

endvec:	VMOVI $0, V0.B16		// counter registers
	VMOVI $0, V1.B16
	VMOVI $0, V2.B16
	VMOVI $0, V3.B16

	// process tail, 4 bytes at a time
	SUBS $8-15*16, R3		// 8 bytes left to process?
	BLT tail1

//	VMOVQ (R1), V6
	WORD $0x3dc00026

tail8:	VEXT $4, V6.B16, V6.B16, V7.B16
	SUBS $8, R3
	COUNT4(V0, V1, V6)
	VEXT $8, V6.B16, V6.B16, V6.B16
	COUNT4(V2, V3, V7)
	BGE tail8

	// process remaining 0--7 byte
tail1:	SUBS $-8, R3			// anything left to process?
	BLE end

	SUB R3, R4, R6			// shifted window address
//	VMOVQ 16(R6), V5		// load window mask
	WORD $0x3dc004c5
//	VBIC V6.B16, V5.B16, V6.B16	// mask out the desired bytes
	WORD $0x4e661ca6

	// process tail
	VEXT $4, V6.B16, V6.B16, V7.B16
	COUNT4(V0, V1, V6)
	COUNT4(V2, V3, V7)

	// add tail to counters
end:
//	VUADDW V0.B8, V9.H8, V9.H8
//	VUADDW2 V0.B16, V8.H8, V8.H8
//	VUADDW V1.B8, V11.H8, V11.H8
//	VUADDW2 V1.B16, V10.H8, V10.H8
//	VUADDW V2.B8, V13.H8, V13.H8
//	VUADDW2 V2.B16, V12.H8, V12.H8
//	VUADDW V3.B8, V15.H8, V15.H8
//	VUADDW2 V3.B16, V14.H8, V14.H8
	// TODO: add WORD directives

	CALL *R0
	RET
