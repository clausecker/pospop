package pospop

import "golang.org/x/sys/cpu"

func count8avx2(counts *[8]int, buf []byte)
func count8sse2(counts *[8]int, buf []byte)

var count8funcs = []count8impl{
	{count8avx2, "avx2", cpu.X86.HasAVX2 && cpu.X86.HasPOPCNT},
	{count8sse2, "sse2", cpu.X86.HasSSE2},
	{count8generic, "generic", true},
}

// no specialised implementations for these so far
var count16funcs = []count16impl{{count16generic, "generic", true}}
var count32funcs = []count32impl{{count32generic, "generic", true}}
var count64funcs = []count64impl{{count64generic, "generic", true}}
