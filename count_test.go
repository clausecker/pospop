package pospop

import "math/rand"
import "testing"

// standard test lengths to try
var testLengths = []int{
	0, 1,
	15, 16, 17,
	31, 32, 33,
	63, 64, 65,
	95, 97, 98,
	127, 128, 129,
	1023, 1024, 1025,
}
	

// fill counts with random integers
func randomCounts(counts []int) {
	for i := range counts {
		counts[i] = rand.Int()
	}
}

// Count8 reference implementation
func refCount8(counts *[8]int, buf []uint8) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 8; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// test the correctness of Count8
func TestCount8(t *testing.T) {
	for _, len := range testLengths {
		buf := make([]uint8, len)
		for i := range buf {
			buf[i] = uint8(rand.Int63())
		}

		var counts [8]int
		randomCounts(counts[:])
		refCounts := counts

		Count8(&counts, buf)
		refCount8(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match", len)
		}
	}
}

// Count16 reference implementation
func refCount16(counts *[16]int, buf []uint16) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 16; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// test the correctness of Count16
func TestCount16(t *testing.T) {
	for _, len := range testLengths {
		buf := make([]uint16, len)
		for i := range buf {
			buf[i] = uint16(rand.Int63())
		}

		var counts [16]int
		randomCounts(counts[:])
		refCounts := counts

		Count16(&counts, buf)
		refCount16(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match", len)
		}
	}
}

// Count32 reference implementation
func refCount32(counts *[32]int, buf []uint32) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 32; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// test the correctness of Count32
func TestCount32(t *testing.T) {
	for _, len := range testLengths {
		buf := make([]uint32, len)
		for i := range buf {
			buf[i] = rand.Uint32()
		}

		var counts [32]int
		randomCounts(counts[:])
		refCounts := counts

		Count32(&counts, buf)
		refCount32(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match", len)
		}
	}
}

// Count64 reference implementation
func refCount64(counts *[64]int, buf []uint64) {
	for i := 0; i < len(buf); i++ {
		for j := 0; j < 64; j++ {
			(*counts)[j] += int(buf[i] >> j & 1)
		}
	}
}

// test the correctness of Count8
func TestCount64(t *testing.T) {
	for _, len := range testLengths {
		buf := make([]uint64, len)
		for i := range buf {
			buf[i] = rand.Uint64()
		}

		var counts [64]int
		randomCounts(counts[:])
		refCounts := counts

		Count64(&counts, buf)
		refCount64(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match", len)
		}
	}
}
