package pospop

import "math/rand"
import "testing"
import "strconv"

// sizes to benchmark
var benchmarkLengths = []int{
	1000, 10 * 1000, 100 * 1000, 1000 * 1000, 10 * 1000 * 1000, 100 * 1000 * 1000,
}

// sizes to benchmark in a short benchmark
var benchmarkLengthsShort = []int{100 * 1000}

// benchmark a count8 implementation
func benchmarkCount8(b *testing.B, lengths []int, count8 func(*[8]int, []uint8)) {
	maxlen := lengths[len(lengths)-1]
	buf := make([]uint8, maxlen)
	rand.Read(buf)

	for _, l := range lengths {
		b.Run(strconv.Itoa(l), func(b *testing.B) {
			var counts [8]int
			testbuf := buf[:l]
			b.SetBytes(int64(l))
			for i := 0; i < b.N; i++ {
				count8(&counts, testbuf)
			}
		})
	}
}

// benchmark all Count8 implementations
func BenchmarkCount8(b *testing.B) {
	funcs := count8funcs
	lengths := benchmarkLengths

	// short benchmark: only test the implementation
	// actually used and keep it to one size
	if testing.Short() {
		funcs = []count8impl{{Count8, "dispatch", true}}
		lengths = benchmarkLengthsShort
	}

	for _, impl := range funcs {
		b.Run(impl.name, func(bb *testing.B) {
			if !impl.available {
				bb.SkipNow()
			}

			benchmarkCount8(bb, lengths, impl.count8)
		})
	}
}
