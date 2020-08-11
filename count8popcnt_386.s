#include "textflag.h"

// 8 bit positional population count using POPCNT.
// Processes 240 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: SSE2, POPCNT.

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	MOVOA A, D \
	PAND B, D \
	PXOR B, A \
	MOVOA A, B \
	PAND C, B \
	PXOR C, A \
	POR  D, B

// count the number of set MSB of the bytes of X into R.
#define COUNT(X, R) \
	PMOVMSKB X, R \
	POPCNTL R, R

// same as COUNT, but shift X left afterwards.
#define COUNTS(X, R) \
	COUNT(X, R) \
	PADDB X, X

// count the number of MSB set in X4:X3:X1:X0
// and accumulate into R
#define ACCUM(R) \
	COUNT(X3, AX) \
	COUNT(X2, BX) \
	LEAL (BX)(AX*2), AX \
	COUNT(X1, BX) \
	COUNT(X0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDL AX, R

// same as ACCUM, but use COUNTS instead of COUNT
#define ACCUMS(R) \
	COUNTS(X3, AX) \
	COUNTS(X2, BX) \
	LEAL (BX)(AX*2), AX \
	COUNTS(X1, BX) \
	COUNTS(X0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDL AX, R

// func count8popcnt(counts *[8]int, buf []byte)
TEXT ·count8popcnt(SB),NOSPLIT,$0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), CX		// CX = len(buf)

	SUBL $15*16, CX			// pre-decrement CX
	JL end15

vec15:	MOVOU 0*16(SI), X0		// load 480 bytes from buf
	MOVOU 1*16(SI), X1		// and sum them into X3:X2:X1:X0
	MOVOU 2*16(SI), X2
	CSA(X0, X1, X2, X7)

	MOVOU 3*16(SI), X2
	MOVOU 4*16(SI), X3
	MOVOU 5*16(SI), X4
	CSA(X2, X3, X4, X7)

	MOVOU 6*16(SI), X4
	CSA(X0, X2, X4, X7)

	MOVOU 7*16(SI), X4
	MOVOU 8*16(SI), X5
	CSA(X0, X4, X5, X7)
	CSA(X1, X2, X3, X7)

	MOVOU 9*16(SI), X3
	MOVOU 10*16(SI), X5
	CSA(X0, X3, X5, X7)
	CSA(X1, X3, X4, X7)

	MOVOU 11*16(SI), X4
	MOVOU 12*16(SI), X5
	CSA(X0, X4, X5, X7)

	MOVOU 13*16(SI), X5
	MOVOU 14*16(SI), X6
	CSA(X0, X5, X6, X7)
	CSA(X1, X4, X5, X7)
	CSA(X2, X3, X4, X7)

	ADDL $15*16, SI
#define D	75
	PREFETCHT0 (D+ 0)*16(SI)
	PREFETCHT0 (D+ 4)*16(SI)
	PREFETCHT0 (D+ 8)*16(SI)
	PREFETCHT0 (D+12)*16(SI)

	// X4:X3:X1:X0 = X0+X1+...+X14

	ACCUMS(7*4(DI))
	ACCUMS(6*4(DI))
	ACCUMS(5*4(DI))
	ACCUMS(4*4(DI))
	ACCUMS(3*4(DI))
	ACCUMS(2*4(DI))
	ACCUMS(1*4(DI))
	ACCUM(0*4(DI))

	SUBL $15*16, CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBL $-14*16, CX		// undo last subtraction and
					// pre-subtract 16 bit from CX
	JL end1

vec1:	MOVOU (SI), X0		// load 16 bytes from buf
	ADDL $16, SI			// advance SI past them

	COUNTS(X0, AX)
	ADDL AX, 7*4(DI)

	COUNTS(X0, AX)
	ADDL AX, 6*4(DI)

	COUNTS(X0, AX)
	ADDL AX, 5*4(DI)

	COUNTS(X0, AX)
	ADDL AX, 4*4(DI)

	COUNTS(X0, AX)
	ADDL AX, 3*4(DI)

	COUNTS(X0, AX)
	ADDL AX, 2*4(DI)

	COUNTS(X0, AX)
	ADDL AX, 1*4(DI)

	COUNT(X0, AX)
	ADDL AX, 0*4(DI)

	SUBL $16, CX
	JGE vec1			// repeat as long as bytes are left

end1:	SUBL $-16, CX			// undo last subtraction
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
