package pospop

import "math/rand"
import "testing"
import "strconv"

// sizes to benchmark
var benchmarkLengths = []int{
	1000, 10*1000, 100*1000, 1000*1000, 10*1000*1000, 100*1000*1000,
}

// benchmark a count8 implementation
func benchmarkCount8(b *testing.B, count8 func(*[8]int, []uint8)) {
	maxlen := benchmarkLengths[len(benchmarkLengths) - 1]
	buf := make([]uint8, maxlen)
	rand.Read(buf)

	for _, l := range benchmarkLengths {
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

// benchmark the reference implementation
func BenchmarkCount8Generic(b *testing.B) {
	benchmarkCount8(b, count8generic)
}
