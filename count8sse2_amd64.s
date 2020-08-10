#include "textflag.h"

// 8 bit positiona population count using SSE.
// Processes 16 bytes in one iteration, flushing the
// buffer every 15 iterations.
// Required feature flag: SSE2 (default).

// http://0x80.pl/articles/avx512-pospopcnt-8bit.html

// mask of 0x01 repeated 16 times
DATA ones<>+0(SB)/8, $0x0101010101010101
DATA ones<>+8(SB)/8, $0x0101010101010101
GLOBL ones<>(SB), RODATA|NOPTR, $16

// add the LSBs of X' bytes into S
#define ACCUM(X, S) \
	MOVOA X7, X3 \
	PAND X, X3 \
	PADDB X3, S

// same as ACCUM, but also shift X left by 1
#define ACCUMS(X, S) \
	ACCUM(X, S) \
	PSRLL $1, X0

// horizontally sum bytes in X and add to counter R.
// Then clear counter R.
#define	COUNT(X, R) \
	PSADBW X6, X \
	PSHUFD $0xfe, X0, X1 \
	PADDD X1, X0 \
	MOVL X0, DX \
	ADDQ DX, R

// func count8sse2(counts *[8]int, buf []byte)
TEXT ·count8sse2(SB),NOSPLIT,$0-32
	MOVQ counts+0(FP), DI
	MOVQ buf_base+8(FP), SI		// SI = &buf[0]
	MOVQ buf_len+16(FP), CX		// CX = len(buf)

	// load counts into registers R8--R15
	MOVQ 8*0(DI), R8
	MOVQ 8*1(DI), R9
	MOVQ 8*2(DI), R10
	MOVQ 8*3(DI), R11
	MOVQ 8*4(DI), R12
	MOVQ 8*5(DI), R13
	MOVQ 8*6(DI), R14
	MOVQ 8*7(DI), R15

	SUBQ $16*2, CX			// pre-decrement CX
	JL ssefin			// nothing left to do?

	MOVOU ones<>(SB), X7		// bit mask of all ones
	PXOR X6, X6			// zeroed-out register

loop:	MOVL $126, AX			// remaining space in buffer
	PXOR X8, X8			// X8..X15: partial counts
	PXOR X9, X9
	PXOR X10, X10
	PXOR X11, X11
	PXOR X12, X12
	PXOR X13, X13
	PXOR X14, X14
	PXOR X15, X15

accum:	MOVOU 16*0(SI), X0		// load 32 bytes into X0 and X2
	MOVOU 16*1(SI), X1
	ADDQ $16*2, SI			// advance SI
	PREFETCHT0 16*16(SI)

	ACCUMS(X0, X8)
	ACCUMS(X1, X8)

	ACCUMS(X0, X9)
	ACCUMS(X1, X9)

	ACCUMS(X0, X10)
	ACCUMS(X1, X10)

	ACCUMS(X0, X11)
	ACCUMS(X1, X11)

	ACCUMS(X0, X12)
	ACCUMS(X1, X12)

	ACCUMS(X0, X13)
	ACCUMS(X1, X13)

	ACCUMS(X0, X14)
	ACCUMS(X1, X14)

	ACCUM(X0, X15)
	ACCUM(X1, X15)

	SUBQ $16*2, CX			// account for the data we loaded
	JL full				// if out of data, accumulate rest

	SUBL $1, AX			// account buffer fill
	JNZ accum

	// buffers full: process X8...X15 into R8..R15
full:	COUNT(X8, R8)
	COUNT(X9, R9)
	COUNT(X10, R10)
	COUNT(X11, R11)
	COUNT(X12, R12)
	COUNT(X13, R13)
	COUNT(X14, R14)
	COUNT(X15, R15)

	TESTQ CX, CX			// any data left to process?
	JNS loop

ssefin:	ADDQ $2*16, CX			// undo last subtraction
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
