#include "textflag.h"

// 8 bit positional population count without any
// instruction set extensions.  This "scalar" implementation
// is a best effort for very old computers.

// func count8scalar(counts *[8]int, buf []byte)
TEXT ·count8scalar(SB),NOSPLIT,$0-16
	MOVL counts+0(FP), DI
	MOVL buf_base+4(FP), SI		// SI = &buf[0]
	MOVL buf_len+8(FP), CX		// CX = len(buf)

	TESTL CX, CX			// anything to process?
	JLE ret

	MOVL 0*4(DI), BX		// keep at least some counters in memory
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
