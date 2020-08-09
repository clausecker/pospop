// Positional population count.
package pospop

// Count the number of corresponding set bits of the bytes in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x01, counts[1] for 0x02, and so on to
// counts[7] for 0x80.
func Count8(counts *[8]int, buf []uint8) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 8; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x001, counts[1] for 0x0002, and so on
// to counts[15] for 0x8000.
func Count16(counts *[16]int, buf []uint16) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 16; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x0000001, counts[1] for 0x00000002,
// and so on to counts[31] for 0x80000000.
func Count32(counts *[32]int, buf []uint32) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 32; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x000000000000001, counts[1] for
// 0x0000000000000002, and so on to counts[31] for 0x8000000000000000.
func Count64(counts *[64]int, buf []uint64) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 64; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}
