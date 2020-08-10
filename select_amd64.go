package pospop

import "golang.org/x/sys/cpu"

func count8avx2(counts *[8]int, buf []byte)
func count8sse2(counts *[8]int, buf []byte)

func init() {
	x86 := &cpu.X86

	if x86.HasPOPCNT {
		if x86.HasAVX2 {
			count8 = count8avx2
		} else {
			count8 = count8sse2
		}
	}
}
