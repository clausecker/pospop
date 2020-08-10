#include "textflag.h"

// 8 bit positional population count using just SSE2.
// Processes 240 bytes at a time using a 15-fold
// carry-save-adder reduction.
// Required feature flags: SSE2 (default).

// B:A = A+B+C, D used for scratch space
#define CSA(A, B, C, D) \
	MOVOA A, D \
	PAND B, D \
	PXOR B, A \
	MOVOA A, B \
	PAND C, B \
	PXOR C, A \
	POR  D, B

// count the number of set MSB of the bytes of X into AX.
#define COUNT(X) \
	PMOVMSKB X, AX \
	MOVL AX, DX \
	SHRL $1, DX \
	ANDL $0x5555, DX \
	SUBL DX, AX \
	MOVL AX, DX \
	ANDL BX, AX \
	SHRL $2, DX \
	ANDL BX, DX \
	ADDL DX, AX \
	MOVL AX, DX \
	SHRL $4, DX \
	ADDL DX, AX \
	ANDL $0x0f0f, AX \
	ADDB AH, AL \
	MOVBLZX AL, AX

// same as COUNT, but shift X left afterwards.
#define COUNTS(X) \
	COUNT(X) \
	PADDB X, X

// magic constants for ACCUM and ACCUMS
// 0x3333333333333333 is in BX.
DATA magic<>+ 0(SB)/8, $0x5555555555555555
DATA magic<>+ 8(SB)/8, $0x0f0f0f0f0f0f0f0f
DATA magic<>+16(SB)/8, $0x0101020204040808
GLOBL magic<>(SB), RODATA|NOPTR, $24

// count the number of MSB set in X4:X3:X1:X0
// and accumulate into R
// uses a modified (!) "parallel popcount" algorithm.
// The MSBs of X4, X4, X1, and X0 are concatenated into AX.
// Then, the population count is taken using a modified
// "parallel popcount" algorithm.  The modification pertains
// the final step which has been changed such that the place
// value of X0, X1, X3, and X4 are accounted for.
// It is assumed that BX holds 0x3333333333333333.
#define ACCUM(R) \
	PMOVMSKB X4, AX \
	SHLL $16, AX \
	PMOVMSKB X3, DX \
	ORL DX, AX \
	SHLQ $16, AX \
	PMOVMSKB X1, DX \
	ORQ DX, AX \
	SHLQ $16, AX \
	PMOVMSKB X0, DX \
	ORQ DX, AX \
	MOVQ AX, DX \
	SHRQ $1, DX \
	ANDQ magic<>(SB), DX \
	SUBQ DX, AX \
	MOVQ AX, DX \
	ANDQ BX, AX \
	SHRQ $2, DX \
	ANDQ BX, DX \
	ADDQ DX, AX \
	MOVQ AX, DX \
	SHRQ $4, DX \
	ADDQ DX, AX \
	ANDQ magic<>+8(SB), AX \
	IMULQ magic<>+16(SB), AX \
	SHRQ $56, AX \
	ADDQ AX, R

// same as ACCUM, but use COUNTS instead of COUNT
#define ACCUMS(R) \
	PMOVMSKB X4, AX \
	PADDB X4, X4 \
	SHLL $16, AX \
	PMOVMSKB X3, DX \
	PADDB X3, X3 \
	ORL DX, AX \
	SHLQ $16, AX \
	PMOVMSKB X1, DX \
	PADDB X1, X1 \
	ORQ DX, AX \
	SHLQ $16, AX \
	PMOVMSKB X0, DX \
	PADDB X0, X0 \
	ORQ DX, AX \
	MOVQ AX, DX \
	SHRQ $1, DX \
	ANDQ magic<>(SB), DX \
	SUBQ DX, AX \
	MOVQ AX, DX \
	ANDQ BX, AX \
	SHRQ $2, DX \
	ANDQ BX, DX \
	ADDQ DX, AX \
	MOVQ AX, DX \
	SHRQ $4, DX \
	ADDQ DX, AX \
	ANDQ magic<>+8(SB), AX \
	IMULQ magic<>+16(SB), AX \
	SHRQ $56, AX \
	ADDQ AX, R

// func count8sse2(counts *[8]int, buf []byte)
TEXT ·count8sse2(SB),NOSPLIT,$0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)

	// load counts into register R8--R15
	MOVQ 8*0(DI), R8
	MOVQ 8*1(DI), R9
	MOVQ 8*2(DI), R10
	MOVQ 8*3(DI), R11
	MOVQ 8*4(DI), R12
	MOVQ 8*5(DI), R13
	MOVQ 8*6(DI), R14
	MOVQ 8*7(DI), R15

	MOVQ $0x3333333333333333, BX	// magic constant for popcount

	SUBQ $15*16, CX			// pre-decrement CX
	JL end15


vec15:	MOVOU 0*16(SI), X0		// load 240 bytes from buf into X0--X14
	MOVOU 1*16(SI), X1
	MOVOU 2*16(SI), X2
	CSA(X0, X1, X2, X15)

	MOVOU 3*16(SI), X3
	MOVOU 4*16(SI), X4
	MOVOU 5*16(SI), X5
	CSA(X3, X4, X5, X15)

	MOVOU 6*16(SI), X6
	MOVOU 7*16(SI), X7
	MOVOU 8*16(SI), X8
	CSA(X6, X7, X8, X15)

	MOVOU 9*16(SI), X9
	MOVOU 10*16(SI), X10
	MOVOU 11*16(SI), X11
	CSA(X9, X10, X11, X15)

	MOVOU 12*16(SI), X12
	MOVOU 13*16(SI), X13
	MOVOU 14*16(SI), X14
	CSA(X12, X13, X14, X15)

	ADDQ $15*16, SI
#define D	30
	PREFETCHT0 (D+ 0)*16(SI)
	PREFETCHT0 (D+ 4)*16(SI)
	PREFETCHT0 (D+ 8)*16(SI)
	PREFETCHT0 (D+12)*16(SI)

	CSA(X0, X3, X6, X15)
	CSA(X1, X4, X7, X15)
	CSA(X0, X9, X12, X15)
	CSA(X1, X3, X10, X15)
	CSA(X1, X9, X13, X15)
	CSA(X3, X4, X9, X15)

	// X4:X3:X1:X0 = X0+X1+...+X14

	ACCUMS(R15)
	ACCUMS(R14)
	ACCUMS(R13)
	ACCUMS(R12)
	ACCUMS(R11)
	ACCUMS(R10)
	ACCUMS(R9)
	ACCUM(R8)

	SUBQ $15*16, CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBQ $-14*16, CX		// undo last subtraction and
					// pre-subtract 16 bit from CX
	JL end1

vec1:	MOVOU (SI), X0			// load 16 bytes from buf
	ADDQ $16, SI			// advance SI past them

	COUNTS(X0)
	ADDQ AX, R15

	COUNTS(X0)
	ADDQ AX, R14

	COUNTS(X0)
	ADDQ AX, R13

	COUNTS(X0)
	ADDQ AX, R12

	COUNTS(X0)
	ADDQ AX, R11

	COUNTS(X0)
	ADDQ AX, R10

	COUNTS(X0)
	ADDQ AX, R9

	COUNT(X0)
	ADDQ AX, R8

	SUBQ $16, CX
	JGE vec1			// repeat as long as bytes are left

end1:	ADDQ $16, CX			// undo last subtraction
	JE end				// if CX=0, there's nothing left

scalar:	MOVBLZX (SI), AX		// load a byte from buf
	INCQ SI				// advance past it

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R8			// add it to R8

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R9			// add it to R9

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R10			// add it to R10

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R11			// add it to R11

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R12			// add it to R12

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R13			// add it to R13

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R14			// add it to R14

	SHRL $1, AX			// is bit 0 set?
	ADCQ $0, R15			// add it to R15

	DECQ CX				// mark this byte as done
	JNE scalar			// and proceed if any bytes are left

	// write R8--R15 back to counts
end:	MOVQ R8, 8*0(DI)
	MOVQ R9, 8*1(DI)
	MOVQ R10, 8*2(DI)
	MOVQ R11, 8*3(DI)
	MOVQ R12, 8*4(DI)
	MOVQ R13, 8*5(DI)
	MOVQ R14, 8*6(DI)
	MOVQ R15, 8*7(DI)

	RET
