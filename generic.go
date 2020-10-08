// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

package pospop

// Maximum data length for one iteration of an inner
// counting function for the generic implementations.
// Any larger and the 32 bit counters might overflow.
const genericMaxLen = 1<<16 - 1

// 8-bit full adder
func csa8(a, b, c uint8) (c_out, s uint8) {
	s_ab := a ^ b
	c_ab := a & b

	s = s_ab ^ c
	c_out = c_ab | s_ab&c

	return
}

// count8 generic implementation.  Uses the same CSA15
// kernel as the vectorised implementations.
func count8generic(counts *[8]int, buf []uint8) {
	var i int

	for i = 0; i < len(buf)-14; i += 15 {
		b0, a0 := csa8(buf[i+0], buf[i+1], buf[i+2])
		b1, a1 := csa8(buf[i+3], buf[i+4], buf[i+5])
		b2, a2 := csa8(a0, a1, buf[i+6])
		c0, b3 := csa8(b0, b1, b2)
		b4, a3 := csa8(a2, buf[i+7], buf[i+8])
		b5, a4 := csa8(a3, buf[i+9], buf[i+10])
		c1, b6 := csa8(b3, b4, b5)
		b7, a5 := csa8(a4, buf[i+11], buf[i+12])
		b8, a := csa8(a5, buf[i+13], buf[i+14])
		c2, b := csa8(b6, b7, b8)
		d, c := csa8(c0, c1, c2)

		// d:c:b:a now holds the counters

		ba0 := a&0x55 | b<<1&0xaa
		ba1 := a>>1&0x55 | b&0xaa
		dc0 := c&0x55 | d<<1&0xaa
		dc1 := c>>1&0x55 | d&0xaa

		dcba0 := ba0&0x33 | dc0<<2&0xcc
		dcba1 := ba0>>2&0x33 | dc0&0xcc
		dcba2 := ba1&0x33 | dc1<<2&0xcc
		dcba3 := ba1>>2&0x33 | dc1&0xcc

		// add to counters
		counts[0] += int(dcba0 & 0x0f)
		counts[1] += int(dcba2 & 0x0f)
		counts[2] += int(dcba1 & 0x0f)
		counts[3] += int(dcba3 & 0x0f)
		counts[4] += int(dcba0 >> 4)
		counts[5] += int(dcba2 >> 4)
		counts[6] += int(dcba1 >> 4)
		counts[7] += int(dcba3 >> 4)
	}

	count8safe(counts, buf[i:len(buf)])
}

// 16-bit full adder
func csa16(a, b, c uint16) (c_out, s uint16) {
	s_ab := a ^ b
	c_ab := a & b

	s = s_ab ^ c
	c_out = c_ab | s_ab&c

	return
}

// count16 generic implementation.  Uses the same CSA15
// kernel as the vectorised implementations.
func count16generic(counts *[16]int, buf []uint16) {
	var i int

	for i = 0; i < len(buf)-14; i += 15 {
		b0, a0 := csa16(buf[i+0], buf[i+1], buf[i+2])
		b1, a1 := csa16(buf[i+3], buf[i+4], buf[i+5])
		b2, a2 := csa16(a0, a1, buf[i+6])
		c0, b3 := csa16(b0, b1, b2)
		b4, a3 := csa16(a2, buf[i+7], buf[i+8])
		b5, a4 := csa16(a3, buf[i+9], buf[i+10])
		c1, b6 := csa16(b3, b4, b5)
		b7, a5 := csa16(a4, buf[i+11], buf[i+12])
		b8, a := csa16(a5, buf[i+13], buf[i+14])
		c2, b := csa16(b6, b7, b8)
		d, c := csa16(c0, c1, c2)

		// d:c:b:a now holds the counters

		ba0 := a&0x5555 | b<<1&0xaaaa
		ba1 := a>>1&0x5555 | b&0xaaaa
		dc0 := c&0x5555 | d<<1&0xaaaa
		dc1 := c>>1&0x5555 | d&0xaaaa

		dcba0 := ba0&0x3333 | dc0<<2&0xcccc
		dcba1 := ba0>>2&0x3333 | dc0&0xcccc
		dcba2 := ba1&0x3333 | dc1<<2&0xcccc
		dcba3 := ba1>>2&0x3333 | dc1&0xcccc

		// add to counters
		counts[0] += int(dcba0 & 0x0f)
		counts[1] += int(dcba2 & 0x0f)
		counts[2] += int(dcba1 & 0x0f)
		counts[3] += int(dcba3 & 0x0f)
		counts[4] += int(dcba0 >> 4 & 0x0f)
		counts[5] += int(dcba2 >> 4 & 0x0f)
		counts[6] += int(dcba1 >> 4 & 0x0f)
		counts[7] += int(dcba3 >> 4 & 0x0f)
		counts[8] += int(dcba0 >> 8 & 0x0f)
		counts[9] += int(dcba2 >> 8 & 0x0f)
		counts[10] += int(dcba1 >> 8 & 0x0f)
		counts[11] += int(dcba3 >> 8 & 0x0f)
		counts[12] += int(dcba0 >> 12)
		counts[13] += int(dcba2 >> 12)
		counts[14] += int(dcba1 >> 12)
		counts[15] += int(dcba3 >> 12)
	}

	count16safe(counts, buf[i:len(buf)])
}

// 32-bit full adder
func csa32(a, b, c uint32) (c_out, s uint32) {
	s_ab := a ^ b
	c_ab := a & b

	s = s_ab ^ c
	c_out = c_ab | s_ab&c

	return
}

// count32 generic implementation.  Uses the same CSA15
// kernel as the vectorised implementations.
func count32generic(counts *[32]int, buf []uint32) {
	var i int

	for i = 0; i < len(buf)-14; i += 15 {
		b0, a0 := csa32(buf[i+0], buf[i+1], buf[i+2])
		b1, a1 := csa32(buf[i+3], buf[i+4], buf[i+5])
		b2, a2 := csa32(a0, a1, buf[i+6])
		c0, b3 := csa32(b0, b1, b2)
		b4, a3 := csa32(a2, buf[i+7], buf[i+8])
		b5, a4 := csa32(a3, buf[i+9], buf[i+10])
		c1, b6 := csa32(b3, b4, b5)
		b7, a5 := csa32(a4, buf[i+11], buf[i+12])
		b8, a := csa32(a5, buf[i+13], buf[i+14])
		c2, b := csa32(b6, b7, b8)
		d, c := csa32(c0, c1, c2)

		// d:c:b:a now holds the counters

		ba0 := a&0x55555555 | b<<1&0xaaaaaaaa
		ba1 := a>>1&0x55555555 | b&0xaaaaaaaa
		dc0 := c&0x55555555 | d<<1&0xaaaaaaaa
		dc1 := c>>1&0x55555555 | d&0xaaaaaaaa

		dcba0 := ba0&0x33333333 | dc0<<2&0xcccccccc
		dcba1 := ba0>>2&0x33333333 | dc0&0xcccccccc
		dcba2 := ba1&0x33333333 | dc1<<2&0xcccccccc
		dcba3 := ba1>>2&0x33333333 | dc1&0xcccccccc

		// add to counters
		counts[0] += int(dcba0 & 0x0f)
		counts[1] += int(dcba2 & 0x0f)
		counts[2] += int(dcba1 & 0x0f)
		counts[3] += int(dcba3 & 0x0f)
		counts[4] += int(dcba0 >> 4 & 0x0f)
		counts[5] += int(dcba2 >> 4 & 0x0f)
		counts[6] += int(dcba1 >> 4 & 0x0f)
		counts[7] += int(dcba3 >> 4 & 0x0f)
		counts[8] += int(dcba0 >> 8 & 0x0f)
		counts[9] += int(dcba2 >> 8 & 0x0f)
		counts[10] += int(dcba1 >> 8 & 0x0f)
		counts[11] += int(dcba3 >> 8 & 0x0f)
		counts[12] += int(dcba0 >> 12 & 0x0f)
		counts[13] += int(dcba2 >> 12 & 0x0f)
		counts[14] += int(dcba1 >> 12 & 0x0f)
		counts[15] += int(dcba3 >> 12 & 0x0f)
		counts[16] += int(dcba0 >> 16 & 0x0f)
		counts[17] += int(dcba2 >> 16 & 0x0f)
		counts[18] += int(dcba1 >> 16 & 0x0f)
		counts[19] += int(dcba3 >> 16 & 0x0f)
		counts[20] += int(dcba0 >> 20 & 0x0f)
		counts[21] += int(dcba2 >> 20 & 0x0f)
		counts[22] += int(dcba1 >> 20 & 0x0f)
		counts[23] += int(dcba3 >> 20 & 0x0f)
		counts[24] += int(dcba0 >> 24 & 0x0f)
		counts[25] += int(dcba2 >> 24 & 0x0f)
		counts[26] += int(dcba1 >> 24 & 0x0f)
		counts[27] += int(dcba3 >> 24 & 0x0f)
		counts[28] += int(dcba0 >> 28)
		counts[29] += int(dcba2 >> 28)
		counts[30] += int(dcba1 >> 28)
		counts[31] += int(dcba3 >> 28)
	}

	count32safe(counts, buf[i:len(buf)])
}

// 64-bit full adder
func csa64(a, b, c uint64) (c_out, s uint64) {
	s_ab := a ^ b
	c_ab := a & b

	s = s_ab ^ c
	c_out = c_ab | s_ab&c

	return
}

// count64 generic implementation.  Uses the same CSA15
// kernel as the vectorised implementations.
func count64generic(counts *[64]int, buf []uint64) {
	var i int

	for i = 0; i < len(buf)-14; i += 15 {
		b0, a0 := csa64(buf[i+0], buf[i+1], buf[i+2])
		b1, a1 := csa64(buf[i+3], buf[i+4], buf[i+5])
		b2, a2 := csa64(a0, a1, buf[i+6])
		c0, b3 := csa64(b0, b1, b2)
		b4, a3 := csa64(a2, buf[i+7], buf[i+8])
		b5, a4 := csa64(a3, buf[i+9], buf[i+10])
		c1, b6 := csa64(b3, b4, b5)
		b7, a5 := csa64(a4, buf[i+11], buf[i+12])
		b8, a := csa64(a5, buf[i+13], buf[i+14])
		c2, b := csa64(b6, b7, b8)
		d, c := csa64(c0, c1, c2)

		// d:c:b:a now holds the counters

		ba0 := a&0x5555555555555555 | b<<1&0xaaaaaaaaaaaaaaaa
		ba1 := a>>1&0x5555555555555555 | b&0xaaaaaaaaaaaaaaaa
		dc0 := c&0x5555555555555555 | d<<1&0xaaaaaaaaaaaaaaaa
		dc1 := c>>1&0x5555555555555555 | d&0xaaaaaaaaaaaaaaaa

		dcba0 := ba0&0x3333333333333333 | dc0<<2&0xcccccccccccccccc
		dcba1 := ba0>>2&0x3333333333333333 | dc0&0xcccccccccccccccc
		dcba2 := ba1&0x3333333333333333 | dc1<<2&0xcccccccccccccccc
		dcba3 := ba1>>2&0x3333333333333333 | dc1&0xcccccccccccccccc

		// add to counters
		counts[0] += int(dcba0 & 0x0f)
		counts[1] += int(dcba2 & 0x0f)
		counts[2] += int(dcba1 & 0x0f)
		counts[3] += int(dcba3 & 0x0f)
		counts[4] += int(dcba0 >> 4 & 0x0f)
		counts[5] += int(dcba2 >> 4 & 0x0f)
		counts[6] += int(dcba1 >> 4 & 0x0f)
		counts[7] += int(dcba3 >> 4 & 0x0f)
		counts[8] += int(dcba0 >> 8 & 0x0f)
		counts[9] += int(dcba2 >> 8 & 0x0f)
		counts[10] += int(dcba1 >> 8 & 0x0f)
		counts[11] += int(dcba3 >> 8 & 0x0f)
		counts[12] += int(dcba0 >> 12 & 0x0f)
		counts[13] += int(dcba2 >> 12 & 0x0f)
		counts[14] += int(dcba1 >> 12 & 0x0f)
		counts[15] += int(dcba3 >> 12 & 0x0f)
		counts[16] += int(dcba0 >> 16 & 0x0f)
		counts[17] += int(dcba2 >> 16 & 0x0f)
		counts[18] += int(dcba1 >> 16 & 0x0f)
		counts[19] += int(dcba3 >> 16 & 0x0f)
		counts[20] += int(dcba0 >> 20 & 0x0f)
		counts[21] += int(dcba2 >> 20 & 0x0f)
		counts[22] += int(dcba1 >> 20 & 0x0f)
		counts[23] += int(dcba3 >> 20 & 0x0f)
		counts[24] += int(dcba0 >> 24 & 0x0f)
		counts[25] += int(dcba2 >> 24 & 0x0f)
		counts[26] += int(dcba1 >> 24 & 0x0f)
		counts[27] += int(dcba3 >> 24 & 0x0f)
		counts[28] += int(dcba0 >> 28 & 0x0f)
		counts[29] += int(dcba2 >> 28 & 0x0f)
		counts[30] += int(dcba1 >> 28 & 0x0f)
		counts[31] += int(dcba3 >> 28 & 0x0f)
		counts[32] += int(dcba0 >> 32 & 0x0f)
		counts[33] += int(dcba2 >> 32 & 0x0f)
		counts[34] += int(dcba1 >> 32 & 0x0f)
		counts[35] += int(dcba3 >> 32 & 0x0f)
		counts[36] += int(dcba0 >> 36 & 0x0f)
		counts[37] += int(dcba2 >> 36 & 0x0f)
		counts[38] += int(dcba1 >> 36 & 0x0f)
		counts[39] += int(dcba3 >> 36 & 0x0f)
		counts[40] += int(dcba0 >> 40 & 0x0f)
		counts[41] += int(dcba2 >> 40 & 0x0f)
		counts[42] += int(dcba1 >> 40 & 0x0f)
		counts[43] += int(dcba3 >> 40 & 0x0f)
		counts[44] += int(dcba0 >> 44 & 0x0f)
		counts[45] += int(dcba2 >> 44 & 0x0f)
		counts[46] += int(dcba1 >> 44 & 0x0f)
		counts[47] += int(dcba3 >> 44 & 0x0f)
		counts[48] += int(dcba0 >> 48 & 0x0f)
		counts[49] += int(dcba2 >> 48 & 0x0f)
		counts[50] += int(dcba1 >> 48 & 0x0f)
		counts[51] += int(dcba3 >> 48 & 0x0f)
		counts[52] += int(dcba0 >> 52 & 0x0f)
		counts[53] += int(dcba2 >> 52 & 0x0f)
		counts[54] += int(dcba1 >> 52 & 0x0f)
		counts[55] += int(dcba3 >> 52 & 0x0f)
		counts[56] += int(dcba0 >> 56 & 0x0f)
		counts[57] += int(dcba2 >> 56 & 0x0f)
		counts[58] += int(dcba1 >> 56 & 0x0f)
		counts[59] += int(dcba3 >> 56 & 0x0f)
		counts[60] += int(dcba0 >> 60)
		counts[61] += int(dcba2 >> 60)
		counts[62] += int(dcba1 >> 60)
		counts[63] += int(dcba3 >> 60)
	}

	count64safe(counts, buf[i:len(buf)])
}
