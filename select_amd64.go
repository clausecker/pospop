package pospop

import "golang.org/x/sys/cpu"

func count8avx2(counts *[8]int, buf []byte)

func init() {
	x86 := &cpu.X86

	if x86.HasAVX2 && x86.HasPOPCNT {
		count8 = count8avx2
	}
}
