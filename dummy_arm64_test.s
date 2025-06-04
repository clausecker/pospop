#include "textflag.h"

// Generic dummy function.  This function expects a possibly
// unaligned input buffer in R1 and its length in R3.
TEXT countdummy<>(SB), NOSPLIT, $0-0
	AND $63, R1, R2		// offset of buffer start from 64 byte alignment
	AND $~63, R1, R1	// align input buffer to 64 bytes
	ADD R2, R3, R3		// add offset to buffer length

	ADD $63, R3, R3		// round up to next multiple of 64 bytes
	VEOR V8.B16, V8.B16, V8.B16
	TST $64, R3		// is there an odd number of 64 byte lanes to process?
	BEQ even

	// odd number of lanes, process first lane
	VLD1.P 4*16(R1), [V0.B16, V1.B16, V2.B16, V3.B16]
	VEOR V0.B16, V1.B16, V1.B16
	VEOR V2.B16, V3.B16, V3.B16
	VEOR V1.B16, V3.B16, V3.B16
	VEOR V3.B16, V8.B16, V8.B16
	SUB $64, R3, R3

even:	ANDS $~63, R3, R3	// truncate count to multiple of 64 bytes
	BEQ end			// if now empty, exit

loop:	VLD1.P 4*16(R1), [V0.B16, V1.B16, V2.B16, V3.B16]
	VLD1.P 4*16(R1), [V4.B16, V5.B16, V6.B16, V7.B16]
	VEOR V0.B16, V1.B16, V1.B16
	VEOR V2.B16, V3.B16, V3.B16
	VEOR V4.B16, V5.B16, V5.B16
	VEOR V6.B16, V7.B16, V7.B16
	VEOR V1.B16, V3.B16, V3.B16
	VEOR V5.B16, V7.B16, V7.B16
	VEOR V3.B16, V7.B16, V7.B16
	VEOR V7.B16, V8.B16, V8.B16
	SUBS $128, R3, R3
	BNE loop

end:	RET

TEXT ·dummyCount8(SB), 0, $0-32
	LDP buf_data+8(FP), (R1, R3)
	CALL countdummy<>(SB)
	RET

TEXT ·dummyCount16(SB), 0, $0-32
	LDP buf_data+8(FP), (R1, R3)
	LSL $1, R3, R3
	CALL countdummy<>(SB)
	RET

TEXT ·dummyCount32(SB), 0, $0-32
	LDP buf_data+8(FP), (R1, R3)
	LSL $2, R3, R3
	CALL countdummy<>(SB)
	RET

TEXT ·dummyCount64(SB), 0, $0-32
	LDP buf_data+8(FP), (R1, R3)
	LSL $3, R3, R3
	CALL countdummy<>(SB)
	RET

