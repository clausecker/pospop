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
	COUNT(Y4, AX) \
	COUNT(Y3, BX) \
	LEAL (BX)(AX*2), AX \
	COUNT(Y1, BX) \
	COUNT(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDQ AX, R

// same as ACCUM, but use COUNTS instead of COUNT
#define ACCUMS(R) \
	COUNTS(Y4, AX) \
	COUNTS(Y3, BX) \
	LEAL (BX)(AX*2), AX \
	COUNTS(Y1, BX) \
	COUNTS(Y0, DX) \
	LEAL (DX)(BX*2), BX \
	LEAL (BX)(AX*4), AX \
	ADDQ AX, R

// func count8avx2(counts *[8]int, buf []byte)
TEXT ·count8avx2(SB),NOSPLIT,$0-32
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

	SUBQ $15*32, CX			// pre-decrement CX
	JL end15

vec15:	VMOVDQU 0*32(SI), Y0		// load 480 bytes from buf into Y0--Y14
	VMOVDQU 1*32(SI), Y1
	VMOVDQU 2*32(SI), Y2
	CSA(Y0, Y1, Y2, Y15)

	VMOVDQU 3*32(SI), Y3
	VMOVDQU 4*32(SI), Y4
	VMOVDQU 5*32(SI), Y5
	CSA(Y3, Y4, Y5, Y15)

	VMOVDQU 6*32(SI), Y6
	VMOVDQU 7*32(SI), Y7
	VMOVDQU 8*32(SI), Y8
	CSA(Y6, Y7, Y8, Y15)

	VMOVDQU 9*32(SI), Y9
	VMOVDQU 10*32(SI), Y10
	VMOVDQU 11*32(SI), Y11
	CSA(Y9, Y10, Y11, Y15)

	VMOVDQU 12*32(SI), Y12
	VMOVDQU 13*32(SI), Y13
	VMOVDQU 14*32(SI), Y14
	CSA(Y12, Y13, Y14, Y15)

	ADDQ $15*32, SI
#define D	75
	PREFETCHT0 (D+ 0)*32(SI)
	PREFETCHT0 (D+ 2)*32(SI)
	PREFETCHT0 (D+ 4)*32(SI)
	PREFETCHT0 (D+ 6)*32(SI)
	PREFETCHT0 (D+ 8)*32(SI)
	PREFETCHT0 (D+10)*32(SI)
	PREFETCHT0 (D+12)*32(SI)
	PREFETCHT0 (D+14)*32(SI)

	CSA(Y0, Y3, Y6, Y15)
	CSA(Y1, Y4, Y7, Y15)
	CSA(Y0, Y9, Y12, Y15)
	CSA(Y1, Y3, Y10, Y15)
	CSA(Y1, Y9, Y13, Y15)
	CSA(Y3, Y4, Y9, Y15)

	// Y4:Y3:Y1:Y0 = Y0+Y1+...+Y14

	ACCUMS(R15)
	ACCUMS(R14)
	ACCUMS(R13)
	ACCUMS(R12)
	ACCUMS(R11)
	ACCUMS(R10)
	ACCUMS(R9)
	ACCUM(R8)

	SUBQ $15*32, CX
	JGE vec15			// repeat as long as bytes are left

end15:	SUBQ $-14*32, CX		// undo last subtraction and
					// pre-subtract 32 bit from CX
	JL end1

vec1:	VMOVDQU (SI), Y0		// load 32 bytes from buf
	ADDQ $32, SI			// advance SI past them

	COUNTS(Y0, AX)
	ADDQ AX, R15

	COUNTS(Y0, AX)
	ADDQ AX, R14

	COUNTS(Y0, AX)
	ADDQ AX, R13

	COUNTS(Y0, AX)
	ADDQ AX, R12

	COUNTS(Y0, AX)
	ADDQ AX, R11

	COUNTS(Y0, AX)
	ADDQ AX, R10

	COUNTS(Y0, AX)
	ADDQ AX, R9

	COUNT(Y0, AX)
	ADDQ AX, R8

	SUBQ $32, CX
	JGE vec1			// repeat as long as bytes are left

end1:	VZEROUPPER			// restore SSE-compatibility
	ADDQ $32, CX			// undo last subtraction
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
