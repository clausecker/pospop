// Copyright (c) 2020--2022, 2025 Robert Clausecker <fuz@fuz.su>

package pospop

import "math/rand"
import "testing"
import "strconv"

// sizes to benchmark
var benchmarkLengths = []int{
	1, 10, 100, 1000, 10 * 1000, 100 * 1000, 1000 * 1000, 10 * 1000 * 1000, 100 * 1000 * 1000,
}

// sizes to benchmark in a short benchmark
var benchmarkLengthsShort = []int{100 * 1000}

// benchmark a count8 implementation
func benchmarkCount8(b *testing.B, buf []uint8, lengths []int, count8 func(*[8]int, []uint8)) {
	for _, l := range lengths {
		b.Run(strconv.Itoa(l)+"B", func(b *testing.B) {
			var counts [8]int
			testbuf := buf[:l]
			b.SetBytes(int64(l) * 1)
			for i := 0; i < b.N; i++ {
				count8(&counts, testbuf)
			}
		})
	}
}

// benchmark all Count8 implementations
func BenchmarkCount8(b *testing.B) {
	funcs := append(count8funcs, count8dummy...)
	lengths := benchmarkLengths

	// short benchmark: only test the implementation
	// actually used and keep it to one size
	if testing.Short() {
		funcs = []count8impl{{Count8, "dispatch", true}}
		lengths = benchmarkLengthsShort
	}

	maxlen := lengths[len(lengths)-1]
	buf := make([]uint8, maxlen)
	rand.Read(buf)

	for _, impl := range funcs {
		b.Run(impl.name, func(bb *testing.B) {
			if !impl.available {
				bb.SkipNow()
			}

			benchmarkCount8(bb, buf, lengths, impl.count8)
		})
	}
}

// benchmark a count16 implementation
func benchmarkCount16(b *testing.B, buf []uint16, lengths []int, count16 func(*[16]int, []uint16)) {
	for _, l := range lengths {
		b.Run(strconv.Itoa(l), func(b *testing.B) {
			var counts [16]int
			testbuf := buf[:l/2]
			b.SetBytes(int64(l))
			for i := 0; i < b.N; i++ {
				count16(&counts, testbuf)
			}
		})
	}
}

// benchmark all Count16 implementations
func BenchmarkCount16(b *testing.B) {
	funcs := append(count16funcs, count16dummy...)
	lengths := benchmarkLengths

	// short benchmark: only test the implementation
	// actually used and keep it to one size
	if testing.Short() {
		funcs = []count16impl{{Count16, "dispatch", true}}
		lengths = benchmarkLengthsShort
	}

	maxlen := lengths[len(lengths)-1] / 2
	buf := make([]uint16, maxlen)
	for i := range buf {
		buf[i] = uint16(rand.Int63())
	}

	for _, impl := range funcs {
		b.Run(impl.name, func(bb *testing.B) {
			if !impl.available {
				bb.SkipNow()
			}

			benchmarkCount16(bb, buf, lengths, impl.count16)
		})
	}
}

// benchmark a count32 implementation
func benchmarkCount32(b *testing.B, buf []uint32, lengths []int, count32 func(*[32]int, []uint32)) {
	for _, l := range lengths {
		b.Run(strconv.Itoa(l), func(b *testing.B) {
			var counts [32]int
			testbuf := buf[:l/4]
			b.SetBytes(int64(l))
			for i := 0; i < b.N; i++ {
				count32(&counts, testbuf)
			}
		})
	}
}

// benchmark all Count32 implementations
func BenchmarkCount32(b *testing.B) {
	funcs := append(count32funcs, count32dummy...)
	lengths := benchmarkLengths

	// short benchmark: only test the implementation
	// actually used and keep it to one size
	if testing.Short() {
		funcs = []count32impl{{Count32, "dispatch", true}}
		lengths = benchmarkLengthsShort
	}

	maxlen := lengths[len(lengths)-1] / 4
	buf := make([]uint32, maxlen)
	for i := range buf {
		buf[i] = uint32(rand.Int63())
	}

	for _, impl := range funcs {
		b.Run(impl.name, func(bb *testing.B) {
			if !impl.available {
				bb.SkipNow()
			}

			benchmarkCount32(bb, buf, lengths, impl.count32)
		})
	}
}

// benchmark a count64 implementation
func benchmarkCount64(b *testing.B, buf []uint64, lengths []int, count64 func(*[64]int, []uint64)) {
	for _, l := range lengths {
		b.Run(strconv.Itoa(l), func(b *testing.B) {
			var counts [64]int
			testbuf := buf[:l/8]
			b.SetBytes(int64(l))
			for i := 0; i < b.N; i++ {
				count64(&counts, testbuf)
			}
		})
	}
}

// benchmark all Count64 implementations
func BenchmarkCount64(b *testing.B) {
	funcs := append(count64funcs, count64dummy...)
	lengths := benchmarkLengths

	// short benchmark: only test the implementation
	// actually used and keep it to one size
	if testing.Short() {
		funcs = []count64impl{{Count64, "dispatch", true}}
		lengths = benchmarkLengthsShort
	}

	maxlen := lengths[len(lengths)-1] / 8
	buf := make([]uint64, maxlen)
	for i := range buf {
		buf[i] = rand.Uint64()
	}

	for _, impl := range funcs {
		b.Run(impl.name, func(bb *testing.B) {
			if !impl.available {
				bb.SkipNow()
			}

			benchmarkCount64(bb, buf, lengths, impl.count64)
		})
	}
}
