// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

package pospop

func count8simd(counts *[8]int, buf []uint8)
func count16simd(counts *[16]int, buf []uint16)
func count32simd(counts *[32]int, buf []uint32)
func count64simd(counts *[64]int, buf []uint64)

var count8funcs = []count8impl{
	{count8simd, "simd", true},
	{count8generic, "generic", true},
}

var count16funcs = []count16impl{
	{count16simd, "simd", true},
	{count16generic, "generic", true},
}

var count32funcs = []count32impl{
	{count32simd, "simd", true},
	{count32generic, "generic", true},
}

var count64funcs = []count64impl{
	{count64simd, "simd", true},
	{count64generic, "generic", true},
}
