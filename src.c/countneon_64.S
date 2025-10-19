#include "kernelneon.S"

accum8:
	ld1	{v4.2d-v7.2d}, [x2]
	uaddl	v16.4s, v10.4h, v8.4h
	uaddl2	v17.4s, v10.8h, v8.8h
	uaddl	v18.4s, v11.4h, v9.4h
	uaddl2	v19.4s, v11.8h, v9.8h
	uaddl	v20.4s, v14.4h, v12.4h
	uaddl2	v21.4s, v14.8h, v12.8h
	uaddl	v22.4s, v15.4h, v13.4h
	uaddl2	v23.4s, v15.8h, v13.8h
	add	v16.4s, v16.4s, v18.4s
	add	v17.4s, v17.4s, v19.4s
	add	v20.4s, v20.4s, v22.4s
	add	v21.4s, v21.4s, v23.4s
	add	v16.4s, v16.4s, v20.4s
	add	v17.4s, v17.4s, v21.4s
	uaddw	v4.2d, v4.2d, v16.2s
	uaddw2	v5.2d, v5.2d, v16.4s
	uaddw	v6.2d, v6.2d, v17.2s
	uaddw2	v7.2d, v7.2d, v17.4s
	st1	{v4.2d-v7.2d}, [x2]
	ret

accum16:
	ld1	{v4.2d-v7.2d}, [x2], #64
	uaddl	v16.4s, v10.4h, v8.4h
	uaddl2	v17.4s, v10.8h, v8.8h
	uaddl	v18.4s, v11.4h, v9.4h
	uaddl2	v19.4s, v11.8h, v9.8h
	uaddl	v20.4s, v14.4h, v12.4h
	uaddl2	v21.4s, v14.8h, v12.8h
	uaddl	v22.4s, v15.4h, v13.4h
	uaddl2	v23.4s, v15.8h, v13.8h
	add	v16.4s, v16.4s, v20.4s
	add	v17.4s, v17.4s, v21.4s
	add	v18.4s, v18.4s, v22.4s
	add	v19.4s, v19.4s, v23.4s
	ld1	{v20.2d-v23.2d}, [x2]
	sub	x2, x2, #0x40
	uaddw	v4.2d, v4.2d, v16.2s
	uaddw2	v5.2d, v5.2d, v16.4s
	uaddw	v6.2d, v6.2d, v17.2s
	uaddw2	v7.2d, v7.2d, v17.4s
	uaddw	v20.2d, v20.2d, v18.2s
	uaddw2	v21.2d, v21.2d, v18.4s
	uaddw	v22.2d, v22.2d, v19.2s
	uaddw2	v23.2d, v23.2d, v19.4s
	st1	{v4.2d-v7.2d}, [x2], #64
	st1	{v20.2d-v23.2d}, [x2]
	sub	x2, x2, #0x40
	ret

accum32:
	mov	x7, x2
	mov	x8, x2
	mov	x9, #2

0:	ld1	{v20.2d-v23.2d}, [x7], #64
	ld1	{v4.2d-v7.2d}, [x7], #64
	sub	x9, x9, #0x1
	uaddl	v16.4s, v12.4h, v8.4h
	uaddl2	v17.4s, v12.8h, v8.8h
	uaddl	v18.4s, v13.4h, v9.4h
	uaddl2	v19.4s, v13.8h, v9.8h
	mov	v8.16b, v10.16b
	mov	v9.16b, v11.16b
	mov	v12.16b, v14.16b
	mov	v13.16b, v15.16b
	uaddw	v20.2d, v20.2d, v16.2s
	uaddw2	v21.2d, v21.2d, v16.4s
	uaddw	v22.2d, v22.2d, v17.2s
	uaddw2	v23.2d, v23.2d, v17.4s
	uaddw	v4.2d, v4.2d, v18.2s
	uaddw2	v5.2d, v5.2d, v18.4s
	uaddw	v6.2d, v6.2d, v19.2s
	uaddw2	v7.2d, v7.2d, v19.4s
	st1	{v20.2d-v23.2d}, [x8], #64
	st1	{v4.2d-v7.2d}, [x8], #64
	cbnz	x9, 0b
	ret

accum64:
	mov	x7, x2
	mov	x8, x2
	mov	x9, #4

0:	ld1	{v20.2d-v23.2d}, [x7], #64
	ld1	{v4.2d-v7.2d}, [x7], #64
	sub	x9, x9, #0x1
	uxtl	v16.4s, v8.4h
	uxtl2	v17.4s, v8.8h
	uxtl	v18.4s, v9.4h
	uxtl2	v19.4s, v9.8h
	mov	v8.16b, v10.16b
	mov	v9.16b, v11.16b
	mov	v10.16b, v12.16b
	mov	v11.16b, v13.16b
	mov	v12.16b, v14.16b
	mov	v13.16b, v15.16b
	uaddw	v20.2d, v20.2d, v16.2s
	uaddw2	v21.2d, v21.2d, v16.4s
	uaddw	v22.2d, v22.2d, v17.2s
	uaddw2	v23.2d, v23.2d, v17.4s
	uaddw	v4.2d, v4.2d, v18.2s
	uaddw2	v5.2d, v5.2d, v18.4s
	uaddw	v6.2d, v6.2d, v19.2s
	uaddw2	v7.2d, v7.2d, v19.4s
	st1	{v20.2d-v23.2d}, [x8], #64
	st1	{v4.2d-v7.2d}, [x8], #64
	cbnz	x9, 0b
	ret
