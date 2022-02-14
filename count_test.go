// Copyright (c) 2020, 2021 Robert Clausecker <fuz@fuz.su>

package pospop

import (
	"math/rand"
	"testing"
)

// standard test lengths to try
var testLengths = []int{
	0, 1, 2, 3,
	4, 5, 6, 7,
	8, 9, 10, 11,
	12, 13, 14, 15,
	16, 17, 18, 19,
	31, 32, 33,
	63, 64, 65,
	95, 97, 98,
	119, 120, 121,
	239, 240, 241,
	2*240 - 1, 2 * 240, 2*240 + 1,
	4*240 - 1, 4 * 240, 4*240 + 1,
	1023, 1024, 1025,
	(15+16)*8, (15+16)*16, (15+16)*32, (15+16)*64,

	// long length to trigger counter overflow
	(255*16+15)*64,
}

// minimizing the failure causes timeout for long test cases
const minimizationThreshold = (15+16)*64

// fill counts with random integers
func randomCounts(counts []int) {
	for i := range counts {
		counts[i] = rand.Int()
	}
}

// compute the difference in length between two equally long integers slices.
func countDiff(a []int, b []int) []int {
	res := make([]int, len(a))

	for i := range a {
		res[i] = b[i] - a[i]
	}

	return res
}

// test the correctness of a count8 implementation
func testCount8(t *testing.T, count8 func(*[8]int, []uint8)) {
	for _, len := range testLengths {
		buf := make([]uint8, len+1)
		buf = buf[1 : len+1] // ensure misalignment
		for i := range buf {
			buf[i] = uint8(rand.Int63())
		}

		var counts [8]int
		randomCounts(counts[:])
		refCounts := counts

		count8(&counts, buf)
		count8safe(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match: %v\n", len, countDiff(counts[:], refCounts[:]))
		}
	}
}

// test the correctness of a count16 implementation
func testCount16(t *testing.T, count16 func(*[16]int, []uint16)) {
	for _, len := range testLengths {
		buf := make([]uint16, len+1)
		buf = buf[1 : len+1] // ensure misalignment
		for i := range buf {
			buf[i] = uint16(rand.Int63())
		}

		var counts [16]int
		randomCounts(counts[:])
		refCounts := counts

		count16(&counts, buf)
		count16safe(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match: %v\n", len, countDiff(counts[:], refCounts[:]))
		}
	}
}

// test the correctness of a count32 implementation
func testCount32(t *testing.T, count32 func(*[32]int, []uint32)) {
	for _, len := range testLengths {
		buf := make([]uint32, len+1)
		buf = buf[1 : len+1] // ensure misalignment
		for i := range buf {
			buf[i] = rand.Uint32()
		}

		var counts [32]int
		randomCounts(counts[:])
		refCounts := counts

		count32(&counts, buf)
		count32safe(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match: %v\n", len, countDiff(counts[:], refCounts[:]))
		}
	}
}

// test the correctness of a count64 implementation
func testCount64(t *testing.T, count64 func(*[64]int, []uint64)) {
	for _, len := range testLengths {
		buf := make([]uint64, len+1)
		buf = buf[1 : len+1] // ensure misalignment
		for i := range buf {
			buf[i] = rand.Uint64()
		}

		var counts [64]int
		randomCounts(counts[:])
		refCounts := counts

		count64(&counts, buf)
		count64safe(&refCounts, buf)

		if counts != refCounts {
			t.Errorf("length %d: counts don't match: %v\n", len, countDiff(counts[:], refCounts[:]))

			if len > minimizationThreshold {
				continue
			}

			min := minimizeTestcase64(count64, buf)
			tcstr := testcaseString64(min)
			if tcstr != "" {
				t.Log("minimized test case:\n", tcstr)
			}
		}
	}
}

// test the correctness of all Count8 implementations
func TestCount8(t *testing.T) {
	t.Run("dispatch", func(tt *testing.T) { testCount8(tt, Count8) })

	for i := range count8funcs {
		t.Run(count8funcs[i].name, func(tt *testing.T) {
			if !count8funcs[i].available {
				tt.SkipNow()
			}

			testCount8(tt, count8funcs[i].count8)
		})
	}
}

// test the correctness of Count16
func TestCount16(t *testing.T) {
	t.Run("dispatch", func(tt *testing.T) { testCount16(tt, Count16) })

	for i := range count16funcs {
		t.Run(count16funcs[i].name, func(tt *testing.T) {
			if !count16funcs[i].available {
				tt.SkipNow()
			}

			testCount16(tt, count16funcs[i].count16)
		})
	}
}

// test the correctness of Count32
func TestCount32(t *testing.T) {
	t.Run("dispatch", func(tt *testing.T) { testCount32(tt, Count32) })

	for i := range count32funcs {
		t.Run(count32funcs[i].name, func(tt *testing.T) {
			if !count32funcs[i].available {
				tt.SkipNow()
			}

			testCount32(tt, count32funcs[i].count32)
		})
	}
}

// test the correctness of Count64
func TestCount64(t *testing.T) {
	t.Run("dispatch", func(tt *testing.T) { testCount64(tt, Count64) })

	for i := range count64funcs {
		t.Run(count64funcs[i].name, func(tt *testing.T) {
			if !count64funcs[i].available {
				tt.SkipNow()
			}

			testCount64(tt, count64funcs[i].count64)
		})
	}
}
