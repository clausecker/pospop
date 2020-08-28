package pospop

// count8 generic implementation
func count8generic(counts *[8]int, buf []uint8) {
	if uint64(len(buf)) >= 1<<(64-8) {
		// Use fallback if we risk overflowing
		count8safe(counts, buf)
		return
	}
	var tmp [8]uint64
	for _, v := range buf {
		tmp[0] += uint64(v & 1)
		tmp[1] += uint64(v & (1 << 1))
		tmp[2] += uint64(v & (1 << 2))
		tmp[3] += uint64(v & (1 << 3))
		tmp[4] += uint64(v & (1 << 4))
		tmp[5] += uint64(v & (1 << 5))
		tmp[6] += uint64(v & (1 << 6))
		tmp[7] += uint64(v & (1 << 7))
	}
	for i, v := range tmp[:] {
		(*counts)[i] += int(v >> i)
	}
}

func count8safe(counts *[8]int, buf []uint8) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 8; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// count16 generic implementation
func count16generic(counts *[16]int, buf []uint16) {
	if uint64(len(buf)) >= 1<<(64-16) {
		// Use fallback if we risk overflowing
		count16safe(counts, buf)
		return
	}
	var tmp [16]uint64
	for _, v := range buf {
		tmp[0] += uint64(v & 1)
		tmp[1] += uint64(v & (1 << 1))
		tmp[2] += uint64(v & (1 << 2))
		tmp[3] += uint64(v & (1 << 3))
		tmp[4] += uint64(v & (1 << 4))
		tmp[5] += uint64(v & (1 << 5))
		tmp[6] += uint64(v & (1 << 6))
		tmp[7] += uint64(v & (1 << 7))

		tmp[8] += uint64(v & (1 << 8))
		tmp[9] += uint64(v & (1 << 9))
		tmp[10] += uint64(v & (1 << 10))
		tmp[11] += uint64(v & (1 << 11))
		tmp[12] += uint64(v & (1 << 12))
		tmp[13] += uint64(v & (1 << 13))
		tmp[14] += uint64(v & (1 << 14))
		tmp[15] += uint64(v & (1 << 15))
	}
	for i, v := range tmp[:] {
		(*counts)[i] += int(v >> i)
	}
}

func count16safe(counts *[16]int, buf []uint16) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 16; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

func count32generic(counts *[32]int, buf []uint32) {
	if uint64(len(buf)) >= 1<<(64-16) {
		// Use fallback if we risk overflowing
		count32safe(counts, buf)
		return
	}
	var tmp [32]uint64
	for _, v := range buf {
		tmp[0] += uint64(v & 1)
		tmp[1] += uint64(v & (1 << 1))
		tmp[2] += uint64(v & (1 << 2))
		tmp[3] += uint64(v & (1 << 3))
		tmp[4] += uint64(v & (1 << 4))
		tmp[5] += uint64(v & (1 << 5))
		tmp[6] += uint64(v & (1 << 6))
		tmp[7] += uint64(v & (1 << 7))

		tmp[8] += uint64(v & (1 << 8))
		tmp[9] += uint64(v & (1 << 9))
		tmp[10] += uint64(v & (1 << 10))
		tmp[11] += uint64(v & (1 << 11))
		tmp[12] += uint64(v & (1 << 12))
		tmp[13] += uint64(v & (1 << 13))
		tmp[14] += uint64(v & (1 << 14))
		tmp[15] += uint64(v & (1 << 15))

		v >>= 16
		const off = 16
		tmp[0+off] += uint64(v & 1)
		tmp[1+off] += uint64(v & (1 << 1))
		tmp[2+off] += uint64(v & (1 << 2))
		tmp[3+off] += uint64(v & (1 << 3))
		tmp[4+off] += uint64(v & (1 << 4))
		tmp[5+off] += uint64(v & (1 << 5))
		tmp[6+off] += uint64(v & (1 << 6))
		tmp[7+off] += uint64(v & (1 << 7))

		tmp[8+off] += uint64(v & (1 << 8))
		tmp[9+off] += uint64(v & (1 << 9))
		tmp[10+off] += uint64(v & (1 << 10))
		tmp[11+off] += uint64(v & (1 << 11))
		tmp[12+off] += uint64(v & (1 << 12))
		tmp[13+off] += uint64(v & (1 << 13))
		tmp[14+off] += uint64(v & (1 << 14))
		tmp[15+off] += uint64(v & (1 << 15))
	}
	for i, v := range tmp[:] {
		(*counts)[i] += int(v >> (i & 15))
	}
}

// count32 generic implementation
func count32safe(counts *[32]int, buf []uint32) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 32; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

func count64generic(counts *[64]int, buf []uint64) {
	if uint64(len(buf)) >= 1<<(64-16) {
		// Use fallback if we risk overflowing
		count64safe(counts, buf)
		return
	}
	var tmpAll [4][16]uint64
	for _, v := range buf {
		for i := 0; i < 4; i++ {
			tmp := tmpAll[i][:]
			tmp[0] += v & 1
			tmp[1] += v & (1 << 1)
			tmp[2] += v & (1 << 2)
			tmp[3] += v & (1 << 3)
			tmp[4] += v & (1 << 4)
			tmp[5] += v & (1 << 5)
			tmp[6] += v & (1 << 6)
			tmp[7] += v & (1 << 7)

			tmp[8] += v & (1 << 8)
			tmp[9] += v & (1 << 9)
			tmp[10] += v & (1 << 10)
			tmp[11] += v & (1 << 11)
			tmp[12] += v & (1 << 12)
			tmp[13] += v & (1 << 13)
			tmp[14] += v & (1 << 14)
			tmp[15] += v & (1 << 15)
			v >>= 16
		}
	}
	for i, tmp := range tmpAll[:] {
		for j, v := range tmp[:] {
			(*counts)[i*16+j] += int(v >> j)
		}
	}
}

// count64 generic implementation
func count64safe(counts *[64]int, buf []uint64) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 64; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}
