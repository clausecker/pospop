// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

package pospop

func count64simd(counts *[64]int, buf []uint64)

var count64funcs = []count64impl{
	{count64simd, "simd", true},
	{count64generic, "generic", true},
}

// generic variants only
var count8funcs = []count8impl{{count8generic, "generic", true}}
var count16funcs = []count16impl{{count16generic, "generic", true}}
var count32funcs = []count32impl{{count32generic, "generic", true}}

