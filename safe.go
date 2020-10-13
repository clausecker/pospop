// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

package pospop

// count8 reference implementation for tests.  Do not alter.
func count8safe(counts *[8]int, buf []uint8) {
	for i := range buf {
		for j := 0; j < 8; j++ {
			counts[j] += int(buf[i] >> j & 1)
		}
	}
}

// count16 reference implementation for tests.  Do not alter.
func count16safe(counts *[16]int, buf []uint16) {
	for i := range buf {
		for j := 0; j < 16; j++ {
			counts[j] += int(buf[i] >> j & 1)
		}
	}
}

// count32 reference implementation for tests.  Do not alter.
func count32safe(counts *[32]int, buf []uint32) {
	for i := range buf {
		for j := 0; j < 32; j++ {
			counts[j] += int(buf[i] >> j & 1)
		}
	}
}

// count64 reference implementation for tests.  Do not alter.
func count64safe(counts *[64]int, buf []uint64) {
	for i := range buf {
		for j := 0; j < 64; j++ {
			counts[j] += int(buf[i] >> j & 1)
		}
	}
}
