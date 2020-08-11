// +build 386

package pospop

import "golang.org/x/sys/cpu"
import "testing"

// test count8avx2
func TestCount8AVX2(t *testing.T) {
	if !cpu.X86.HasAVX2 || !cpu.X86.HasPOPCNT {
		t.SkipNow()
	}

	testCount8(t, count8avx2)
}


// benchmark count8avx2
func BenchmarkCount8AVX2(b *testing.B) {
	if !cpu.X86.HasAVX2 || !cpu.X86.HasPOPCNT {
		b.SkipNow()
	}

	benchmarkCount8(b, count8avx2)
}


// test count8popcnt
func TestCount8POPCNT(t *testing.T) {
	if !cpu.X86.HasSSE2 || !cpu.X86.HasPOPCNT {
		t.SkipNow()
	}

	testCount8(t, count8popcnt)
}

// benchmark count8popcnt
func BenchmarkCount8POPCNT(b *testing.B) {
	if !cpu.X86.HasSSE2 || !cpu.X86.HasPOPCNT {
		b.SkipNow()
	}

	benchmarkCount8(b, count8popcnt)
}

// test count8sse2
func TestCount8SSE2(t *testing.T) {
	if !cpu.X86.HasSSE2 {
		t.SkipNow()
	}

	testCount8(t, count8sse2)
}

// benchmark count8sse2
func BenchmarkCount8SSE2(b *testing.B) {
	if !cpu.X86.HasSSE2 {
		b.SkipNow()
	}

	benchmarkCount8(b, count8sse2)
}

// test count8scalar
func TestCount8Scalar(t *testing.T) {
	testCount8(t, count8scalar)
}

// benchmark count8scalar
func BenchmarkCount8Scalar(b *testing.B) {
	benchmarkCount8(b, count8scalar)
}
