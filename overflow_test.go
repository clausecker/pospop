// Copyright (c) 2024 Robert Clausecker <fuz@fuz.su>

package pospop

import "testing"

// Check if we can get the accumulators to overflow
func TestOverflow(t *testing.T) {
	for i := range count64funcs {
		t.Run(count64funcs[i].name, func(tt *testing.T) {
			if !count64funcs[i].available {
				tt.SkipNow()
			}

			testOverflow(tt, count64funcs[i].count64)
		})
	}
}

func testOverflow(t *testing.T, count64 func(*[64]int, []uint64)) {
	const imax = 16
	const jmax = 16
	var buf [imax*65536 + jmax]uint64

	for i := range buf {
		buf[i] = ^uint64(0)
	}

	for i := 1; i <= imax; i++ {
		for j := -jmax; j <= jmax; j++ {
			testOverflowBuf(t, count64, buf[:i * 65536 + j])
		}
	}
}

func testOverflowBuf(t *testing.T, count64 func(*[64]int, []uint64), buf []uint64) {
	var counts, refCounts [64]int

	for i := range refCounts {
		refCounts[i] = len(buf)
	}

	count64(&counts, buf)
	if counts != refCounts {
		t.Errorf("length %d: counts don't match: %v", len(buf), countDiff(counts[:], refCounts[:]))
	}
}
