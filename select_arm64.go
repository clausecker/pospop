// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

//+build arm64,go1.16

package pospop

func count8neon(counts *[8]int, buf []uint8)
func count16neon(counts *[16]int, buf []uint16)
func count32neon(counts *[32]int, buf []uint32)
func count64neon(counts *[64]int, buf []uint64)

var count8funcs = []count8impl{
	{count8neon, "neon", true},
	{count8generic, "generic", true},
}

var count16funcs = []count16impl{
	{count16neon, "neon", true},
	{count16generic, "generic", true},
}

var count32funcs = []count32impl{
	{count32neon, "neon", true},
	{count32generic, "generic", true},
}

var count64funcs = []count64impl{
	{count64neon, "neon", true},
	{count64generic, "generic", true},
}
