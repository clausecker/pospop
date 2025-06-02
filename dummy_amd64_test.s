#include "textflag.h"

// Generic AVX-512 dummy function.  This function expects a
// possibly unaligned input buffer in SI and its length in CX.
TEXT countdummyavx512<>(SB), NOSPLIT, $0-0
	MOVQ SI, AX
	ANDQ $63, AX		// offset of buffer start from 64 byte alignment
	ANDQ $~63, SI		// align input buffer to 64 bytes
	MOVQ $63(CX)(AX*1), CX	// add offset and 63 to buffer length
	TESTQ $64, CX		// is there an odd number of 64 byte lanes to process?
	JEQ even64

	// odd number of 64 byte lanes, process first lane
	VMOVAPS (SI), Z0
	ADDQ $64, SI
	SUBQ $64, CX

even64:	TESTQ $128, CX		// is there an odd number of 128 byte lanes to process?
	JEQ even128

	// odd number of 128 byte lanes, process first lane
	VMOVAPS (SI), Z0
	VMOVAPS 64(SI), Z1
	ADDQ $128, SI
	SUBQ $128, CX

even128:
	ANDQ $~255, CX		// truncate count to multiple of 256 bytes
	JEQ end			// if now empty, exit

loop:	VMOVAPS 64*0(SI), Z0
	VMOVAPS 64*1(SI), Z1
	VMOVAPS 64*2(SI), Z2
	VMOVAPS 64*3(SI), Z3
	ADDQ $256, SI
	SUBQ $256, CX
	JNE loop

end:	RET

// Generic AVX dummy function.  This function expects a
// possibly unaligned input buffer in SI and its length in CX.
TEXT countdummyavx<>(SB), NOSPLIT, $0-0
	MOVQ SI, AX
	ANDQ $31, AX		// offset of buffer start from 32 byte alignment
	ANDQ $~31, SI		// align input buffer to 32 bytes
	MOVQ $31(CX)(AX*1), CX	// add offset and 31 to buffer length
	TESTQ $32, CX		// is there an odd number of 32 byte lanes to process?
	JEQ even32

	// odd number of 32 byte lanes, process first lane
	VMOVAPS (SI), Y0
	ADDQ $32, SI
	SUBQ $32, CX

even32:	TESTQ $64, CX		// is there an odd number of 64 byte lanes to process?
	JEQ even64

	// odd number of 64 byte lanes, process first lane
	VMOVAPS (SI), Y0
	VMOVAPS 32(SI), Y1
	ADDQ $64, SI
	SUBQ $64, CX

even64:	ANDQ $~127, CX		// truncate count to multiple of 128 bytes
	JEQ end			// if now empty, exit

loop:	VMOVAPS 32*0(SI), Y0
	VMOVAPS 32*1(SI), Y1
	VMOVAPS 32*2(SI), Y2
	VMOVAPS 32*3(SI), Y3
	ADDQ $128, SI
	SUBQ $128, CX
	JNE loop

end:	RET

// Generic AVX-512 dummy function.  This function expects a
// possibly unaligned input buffer in SI and its length in CX.
TEXT countdummysse<>(SB), NOSPLIT, $0-0
	MOVQ SI, AX
	ANDQ $15, AX		// offset of buffer start from 16 byte alignment
	ANDQ $~15, SI		// align input buffer to 16 bytes
	MOVQ $15(CX)(AX*1), CX	// add offset and 15 to buffer length
	TESTQ $16, CX		// is there an odd number of 16 byte lanes to process?
	JEQ even16

	// odd number of 16 byte lanes, process first lane
	MOVAPS (SI), X0
	ADDQ $16, SI
	SUBQ $16, CX

even16:	TESTQ $32, CX		// is there an odd number of 32 byte lanes to process?
	JEQ even32

	// odd number of 32 byte lanes, process first lane
	MOVAPS (SI), X0
	MOVAPS 16(SI), X1
	ADDQ $32, SI
	SUBQ $32, CX

even32:	ANDQ $~63, CX		// truncate count to multiple of 64 bytes
	JEQ end			// if now empty, exit

loop:	MOVAPS 16*0(SI), X0
	MOVAPS 16*1(SI), X1
	MOVAPS 16*2(SI), X2
	MOVAPS 16*3(SI), X3
	ADDQ $64, SI
	SUBQ $64, CX
	JNE loop

end:	RET

TEXT ·dummyCount8avx512(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	CALL countdummyavx512<>(SB)
	RET

TEXT ·dummyCount16avx512(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $1, CX
	CALL countdummyavx512<>(SB)
	RET

TEXT ·dummyCount32avx512(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $2, CX
	CALL countdummyavx512<>(SB)
	RET

TEXT ·dummyCount64avx512(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $3, CX
	CALL countdummyavx512<>(SB)
	RET

TEXT ·dummyCount8avx(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	CALL countdummyavx<>(SB)
	RET

TEXT ·dummyCount16avx(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $1, CX
	CALL countdummyavx<>(SB)
	RET

TEXT ·dummyCount32avx(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $2, CX
	CALL countdummyavx<>(SB)
	RET

TEXT ·dummyCount64avx(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $3, CX
	CALL countdummyavx<>(SB)
	RET

TEXT ·dummyCount8sse(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	CALL countdummysse<>(SB)
	RET

TEXT ·dummyCount16sse(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $1, CX
	CALL countdummysse<>(SB)
	RET

TEXT ·dummyCount32sse(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $2, CX
	CALL countdummysse<>(SB)
	RET

TEXT ·dummyCount64sse(SB), 0, $0-32
	MOVQ buf_base+8(FP), SI
	MOVQ buf_len+16(FP), CX
	SHLQ $3, CX
	CALL countdummysse<>(SB)
	RET
