// Copyright (c) 2021, 2022 Robert Clausecker <fuz@fuz.su>

package pospop

import "fmt"
import "strings"

const (
	// max number of entries in a test case
	maxTestcaseSize = 100
)

// Take a count64 function and a test case and return true if the
// test case is processed correctly.
func testPasses64(count64 func(*[64]int, []uint64), buf []uint64) bool {
	var counts, refCounts [64]int

	count64(&counts, buf)
	count64safe(&refCounts, buf)

	return counts == refCounts
}

// Take a failing test case for testCount64 and try to find the
// smallest possible test case to trigger the error.  This is done
// by repeatedly clearing bits that do not cause the test case to
// pass when cleared.  An attempt is also made to reduce the length
// of the test case.  This function modifies its argument and
// returns a subslice of it.
func minimizeTestcase64(count64 func(*[64]int, []uint64), tc []uint64) []uint64 {
	// sanity check
	if testPasses64(count64, tc) {
		return nil
	}

	// try to turn off bits
	for i := len(tc) - 1; i >= 0; i-- {
		for j := 63; j >= 0; j-- {
			if tc[i] & (1 << j) == 0 {
				continue
			}

			tc[i] &^= 1 << j
			if testPasses64(count64, tc) {
				tc[i] |= 1 << j
			}
		}
	}

	// try to shorten the array
	for len(tc) > 0 && !testPasses64(count64, tc[:len(tc)-1]) {
		tc = tc[:len(tc)-1]
	}

	return tc
}

// build a string representation of the minimised test case if it is
// not too long.  If it is too long, return the empty string.
func testcaseString64(tc []uint64) string {
	if len(tc) == 0 {
		return "\tvar buf [0]uint64"
	}

	var w strings.Builder
	entries := 0
	fmt.Fprintf(&w, "\tvar buf [%d]uint64 // %p\n", len(tc), &tc[0])
	for i := range tc {
		if tc[i] == 0 {
			continue
		}

		entries++
		if entries > maxTestcaseSize {
			return ""
		}

		fmt.Fprintf(&w, "\tbuf[%d] = %#016x\n", i, tc[i])
	}

	return w.String()
}
