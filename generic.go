// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>
// Copyright (c) 2020 Klaus Post <klauspost@gmail.com>

package pospop

// Maximum data length for one iteration of an inner
// counting function for the generic implementations.
// Any larger and the 32 bit counters might overflow.
const genericMaxLen = 1<<16 - 1

// count8 generic implementation
func count8generic(counts *[8]int, buf []uint8) {
	for i := 0; i < len(buf); i += genericMaxLen {
		n := genericMaxLen
		if n > len(buf)-i {
			n = len(buf) - i
		}

		roundCounts := count8genericRound(buf[i : i+n])

		for j := range roundCounts {
			counts[j] += int(roundCounts[j] >> (j & 0xf))
		}
	}
}

// A single count8 round, accumulating into 32 bit counters.
func count8genericRound(buf []uint8) (counts [8]uint32) {
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
	}

	return
}

// count8 reference implementation for tests.  Do not alter.
func count8safe(counts *[8]int, buf []uint8) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 8; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
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

// count16 reference implementation for tests.  Do not alter.
func count16safe(counts *[16]int, buf []uint16) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 16; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
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

// count32 reference implementation for tests.  Do not alter.
func count32safe(counts *[32]int, buf []uint32) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 32; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
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

// count64 reference implementation for tests.  Do not alter.
func count64safe(counts *[64]int, buf []uint64) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 64; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}
