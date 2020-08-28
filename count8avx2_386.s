// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

#include "textflag.h"

// 8 bit positional population count using AVX-2.
// Processes 480 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: POPCNT, AVX2

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	VPAND A, B, D \
	VPXOR A, B, A \
	VPAND A, C, B \
	VPXOR A, C, A \
	VPOR  B, D, B

// count the number of set MSB of the bytes of Y into R.
#define COUNT(Y, R) \
	VPMOVMSKB Y, R \
	POPCNTL R, R

// same as COUNT, but shift Y left afterwards.
#define COUNTS(Y, R) \
	COUNT(Y, R) \
	VPADDB Y, Y, Y

// count the number of MSB set in Y4:Y3:Y1:Y0
// and accumulate into R
#define ACCUM(R) \
	COUNT(Y3, AX) \
	COUNT(Y2, BX) \
	LEAL (BX)(AX*2), AX \
	COUNT(Y1, BX) \
	COUNT(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDL AX, R

// same as ACCUM, but use COUNTS instead of COUNT
#define ACCUMS(R) \
	COUNTS(Y3, AX) \
	COUNTS(Y2, BX) \
	LEAL (BX)(AX*2), AX \
	COUNTS(Y1, BX) \
	COUNTS(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDL AX, R

// func count8avx2(counts *[8]int, buf []byte)
TEXT ·count8avx2(SB),NOSPLIT,$0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), CX		// CX = len(buf)

	SUBL $15*32, CX			// pre-decrement CX
	JL end15

vec15:	VMOVDQU 0*32(SI), Y0		// load 480 bytes from buf
	VMOVDQU 1*32(SI), Y1		// and sum them into Y3:Y2:Y1:Y0
	VMOVDQU 2*32(SI), Y2
	CSA(Y0, Y1, Y2, Y7)

	VMOVDQU 3*32(SI), Y2
	VMOVDQU 4*32(SI), Y3
	VMOVDQU 5*32(SI), Y4
	CSA(Y2, Y3, Y4, Y7)

	VMOVDQU 6*32(SI), Y4
	CSA(Y0, Y2, Y4, Y7)

	VMOVDQU 7*32(SI), Y4
	VMOVDQU 8*32(SI), Y5
	CSA(Y0, Y4, Y5, Y7)
	CSA(Y1, Y2, Y3, Y7)

	VMOVDQU 9*32(SI), Y3
	VMOVDQU 10*32(SI), Y5
	CSA(Y0, Y3, Y5, Y7)
	CSA(Y1, Y3, Y4, Y7)

	VMOVDQU 11*32(SI), Y4
	VMOVDQU 12*32(SI), Y5
	CSA(Y0, Y4, Y5, Y7)

	VMOVDQU 13*32(SI), Y5
	VMOVDQU 14*32(SI), Y6
	CSA(Y0, Y5, Y6, Y7)
	CSA(Y1, Y4, Y5, Y7)
	CSA(Y2, Y3, Y4, Y7)

	ADDL $15*32, SI
#define D	75
	PREFETCHT0 (D+ 0)*32(SI)
	PREFETCHT0 (D+ 2)*32(SI)
	PREFETCHT0 (D+ 4)*32(SI)
	PREFETCHT0 (D+ 6)*32(SI)
	PREFETCHT0 (D+ 8)*32(SI)
	PREFETCHT0 (D+10)*32(SI)
	PREFETCHT0 (D+12)*32(SI)
	PREFETCHT0 (D+14)*32(SI)

	// Y4:Y3:Y1:Y0 = Y0+Y1+...+Y14

	ACCUMS(7*4(DI))
	ACCUMS(6*4(DI))
	ACCUMS(5*4(DI))
	ACCUMS(4*4(DI))
	ACCUMS(3*4(DI))
	ACCUMS(2*4(DI))
	ACCUMS(1*4(DI))
	ACCUM(0*4(DI))

	SUBL $15*32, CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBL $-14*32, CX		// undo last subtraction and
					// pre-subtract 32 bit from CX
	JL end1

vec1:	VMOVDQU (SI), Y0		// load 32 bytes from buf
	ADDL $32, SI			// advance SI past them

	COUNTS(Y0, AX)
	ADDL AX, 7*4(DI)

	COUNTS(Y0, AX)
	ADDL AX, 6*4(DI)

	COUNTS(Y0, AX)
	ADDL AX, 5*4(DI)

	COUNTS(Y0, AX)
	ADDL AX, 4*4(DI)

	COUNTS(Y0, AX)
	ADDL AX, 3*4(DI)

	COUNTS(Y0, AX)
	ADDL AX, 2*4(DI)

	COUNTS(Y0, AX)
	ADDL AX, 1*4(DI)

	COUNT(Y0, AX)
	ADDL AX, 0*4(DI)

	SUBL $32, CX
	JGE vec1			// repeat as long as bytes are left

end1:	VZEROUPPER			// restore SSE-compatibility
	SUBL $-32, CX			// undo last subtraction
	JLE ret				// if CX<=0, there's nothing left

	MOVL 0*4(DI), BX		// keep some counters in register
	MOVL 4*4(DI), DX

scalar:	MOVBLZX (SI), AX		// load a byte from buf
	INCL SI				// advance past it

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, BX			// add it to counts[0]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, 1*4(DI)		// add it to counts[1]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, 2*4(DI)		// add it to counts[2]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, 3*4(DI)		// add it to counts[3]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, DX			// add it to counts[4]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, 5*4(DI)		// add it to counts[5]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, 6*4(DI)		// add it to counts[6]

	SHRL $1, AX			// is bit 0 set?
	ADCL $0, 7*4(DI)		// add it to counts[7]

	DECL CX				// mark this byte as done
	JNE scalar			// and proceed if any bytes are left

end:	MOVL BX, 0*4(DI)		// restore counters
	MOVL DX, 4*4(DI)
ret:	RET
