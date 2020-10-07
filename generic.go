// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>
// Copyright (c) 2020 Klaus Post <klauspost@gmail.com>

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
	c_out = c_ab | s_ab & c

	return
}

// count8 generic implementation.  Uses the same CSA15
// kernel as the vectorised implementations.
func count8generic(counts *[8]int, buf []uint8) {
	var i int

	for i = 0; i < len(buf) - 14; i += 15 {
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

		ba0 := a & 0x55 | b << 1 & 0xaa
		ba1 := a >> 1 & 0x55 | b & 0xaa
		dc0 := c & 0x55 | d << 1 & 0xaa
		dc1 := c >> 1 & 0x55 | d & 0xaa

		dcba0 := ba0 & 0x33 | dc0 << 2 & 0xcc
		dcba1 := ba0 >> 2 & 0x33 | dc0 & 0xcc
		dcba2 := ba1 & 0x33 | dc1 << 2 & 0xcc
		dcba3 := ba1 >> 2 & 0x33 | dc1 & 0xcc

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


// count16 generic implementation
func count16generic(counts *[16]int, buf []uint16) {
	for i := 0; i < len(buf); i += genericMaxLen {
		n := genericMaxLen
		if n > len(buf)-i {
			n = len(buf) - i
		}

		roundCounts := count16genericRound(buf[i : i+n])

		for j := range roundCounts {
			counts[j] += int(roundCounts[j] >> (j & 0xf))
		}
	}
}

// A single count16 round, accumulating into 32 bit counters.
func count16genericRound(buf []uint16) (counts [16]uint32) {
	for i := range buf {
		v := uint32(buf[i])
		counts[0] += v & 1
		counts[1] += v & (1 << 1)
		counts[2] += v & (1 << 2)
		counts[3] += v & (1 << 3)
		counts[4] += v & (1 << 4)
		counts[5] += v & (1 << 5)
		counts[6] += v & (1 << 6)
		counts[7] += v & (1 << 7)

		counts[8] += v & (1 << 8)
		counts[9] += v & (1 << 9)
		counts[10] += v & (1 << 10)
		counts[11] += v & (1 << 11)
		counts[12] += v & (1 << 12)
		counts[13] += v & (1 << 13)
		counts[14] += v & (1 << 14)
		counts[15] += v & (1 << 15)
	}

	return
}

// count32 generic implementation
func count32generic(counts *[32]int, buf []uint32) {
	for i := 0; i < len(buf); i += genericMaxLen {
		n := genericMaxLen
		if n > len(buf)-i {
			n = len(buf) - i
		}

		roundCounts := count32genericRound(buf[i : i+n])

		for j := range roundCounts {
			counts[j] += int(roundCounts[j] >> (j & 0xf))
		}
	}
}

// A single count32 round, accumulating into 32 bit counters.
func count32genericRound(buf []uint32) (counts [32]uint32) {
	for i := range buf {
		v := uint32(buf[i])
		counts[0] += v & 1
		counts[1] += v & (1 << 1)
		counts[2] += v & (1 << 2)
		counts[3] += v & (1 << 3)
		counts[4] += v & (1 << 4)
		counts[5] += v & (1 << 5)
		counts[6] += v & (1 << 6)
		counts[7] += v & (1 << 7)

		counts[8] += v & (1 << 8)
		counts[9] += v & (1 << 9)
		counts[10] += v & (1 << 10)
		counts[11] += v & (1 << 11)
		counts[12] += v & (1 << 12)
		counts[13] += v & (1 << 13)
		counts[14] += v & (1 << 14)
		counts[15] += v & (1 << 15)

		v >>= 16
		const off = 16
		counts[0+off] += v & 1
		counts[1+off] += v & (1 << 1)
		counts[2+off] += v & (1 << 2)
		counts[3+off] += v & (1 << 3)
		counts[4+off] += v & (1 << 4)
		counts[5+off] += v & (1 << 5)
		counts[6+off] += v & (1 << 6)
		counts[7+off] += v & (1 << 7)

		counts[8+off] += v & (1 << 8)
		counts[9+off] += v & (1 << 9)
		counts[10+off] += v & (1 << 10)
		counts[11+off] += v & (1 << 11)
		counts[12+off] += v & (1 << 12)
		counts[13+off] += v & (1 << 13)
		counts[14+off] += v & (1 << 14)
		counts[15+off] += v & (1 << 15)
	}

	return
}

// count64 generic implementation
func count64generic(counts *[64]int, buf []uint64) {
	for i := 0; i < len(buf); i += genericMaxLen {
		n := genericMaxLen
		if n > len(buf)-i {
			n = len(buf) - i
		}

		roundCounts := count64genericRound(buf[i : i+n])

		for j := range roundCounts {
			counts[j] += int(roundCounts[j] >> (j & 0xf))
		}
	}
}

// A single count64 round, accumulating into 32 bit counters.
func count64genericRound(buf []uint64) (counts [64]uint32) {
	for i := range buf {
		v := uint32(buf[i])
		counts[0] += v & 1
		counts[1] += v & (1 << 1)
		counts[2] += v & (1 << 2)
		counts[3] += v & (1 << 3)
		counts[4] += v & (1 << 4)
		counts[5] += v & (1 << 5)
		counts[6] += v & (1 << 6)
		counts[7] += v & (1 << 7)

		counts[8] += v & (1 << 8)
		counts[9] += v & (1 << 9)
		counts[10] += v & (1 << 10)
		counts[11] += v & (1 << 11)
		counts[12] += v & (1 << 12)
		counts[13] += v & (1 << 13)
		counts[14] += v & (1 << 14)
		counts[15] += v & (1 << 15)

		v >>= 16
		off := 16
		counts[0+off] += v & 1
		counts[1+off] += v & (1 << 1)
		counts[2+off] += v & (1 << 2)
		counts[3+off] += v & (1 << 3)
		counts[4+off] += v & (1 << 4)
		counts[5+off] += v & (1 << 5)
		counts[6+off] += v & (1 << 6)
		counts[7+off] += v & (1 << 7)

		counts[8+off] += v & (1 << 8)
		counts[9+off] += v & (1 << 9)
		counts[10+off] += v & (1 << 10)
		counts[11+off] += v & (1 << 11)
		counts[12+off] += v & (1 << 12)
		counts[13+off] += v & (1 << 13)
		counts[14+off] += v & (1 << 14)
		counts[15+off] += v & (1 << 15)

		v = uint32(buf[i] >> 32)
		off = 32
		counts[0+off] += v & 1
		counts[1+off] += v & (1 << 1)
		counts[2+off] += v & (1 << 2)
		counts[3+off] += v & (1 << 3)
		counts[4+off] += v & (1 << 4)
		counts[5+off] += v & (1 << 5)
		counts[6+off] += v & (1 << 6)
		counts[7+off] += v & (1 << 7)

		counts[8+off] += v & (1 << 8)
		counts[9+off] += v & (1 << 9)
		counts[10+off] += v & (1 << 10)
		counts[11+off] += v & (1 << 11)
		counts[12+off] += v & (1 << 12)
		counts[13+off] += v & (1 << 13)
		counts[14+off] += v & (1 << 14)
		counts[15+off] += v & (1 << 15)

		v >>= 16
		off += 16
		counts[0+off] += v & 1
		counts[1+off] += v & (1 << 1)
		counts[2+off] += v & (1 << 2)
		counts[3+off] += v & (1 << 3)
		counts[4+off] += v & (1 << 4)
		counts[5+off] += v & (1 << 5)
		counts[6+off] += v & (1 << 6)
		counts[7+off] += v & (1 << 7)

		counts[8+off] += v & (1 << 8)
		counts[9+off] += v & (1 << 9)
		counts[10+off] += v & (1 << 10)
		counts[11+off] += v & (1 << 11)
		counts[12+off] += v & (1 << 12)
		counts[13+off] += v & (1 << 13)
		counts[14+off] += v & (1 << 14)
		counts[15+off] += v & (1 << 15)
	}

	return
}
