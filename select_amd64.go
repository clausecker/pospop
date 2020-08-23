package pospop

import "golang.org/x/sys/cpu"

func count8avx2(counts *[8]int, buf []byte)
func count8popcnt(counts *[8]int, buf []byte)
func count8sse2(counts *[8]int, buf []byte)

func count16avx2(counts *[16]int, buf []uint16)

var count8funcs = []count8impl{
	{count8avx2, "avx2", cpu.X86.HasAVX2 && cpu.X86.HasPOPCNT},
	{count8popcnt, "popcnt", cpu.X86.HasPOPCNT},
	{count8sse2, "sse2", true},
	{count8generic, "generic", true},
}

var count16funcs = []count16impl{
	{count16avx2, "avx2", cpu.X86.HasAVX2 && cpu.X86.HasPOPCNT},
	{count16generic, "generic", true},
}

// no specialised implementations for these so far
var count32funcs = []count32impl{{count32generic, "generic", true}}
var count64funcs = []count64impl{{count64generic, "generic", true}}
