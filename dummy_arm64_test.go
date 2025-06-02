// Copyright (c) 2025 Robert Clausecker <fuz@fuz.su>

package pospop

import "golang.org/x/sys/cpu"

var count8dummy = []count8impl{
	{dummyCount8avx512, "dummyAvx512", cpu.X86.HasAVX512},
	{dummyCount8avx, "dummyAvx", cpu.X86.HasAVX && !cpu.X86.HasAVX512},
	{dummyCount8sse, "dummySse", !cpu.X86.HasAVX}, 
}
var count16dummy = []count16impl{{dummyCount16, "dummy", true}}
var count32dummy = []count32impl{{dummyCount32, "dummy", true}}
var count64dummy = []count64impl{{dummyCount64, "dummy", true}}

// dummy Count8 implementation that performs no work
func dummyCount8(counts *[8]int, buf []uint8)

// dummy Count16 implementation that performs no work
func dummyCount16(counts *[16]int, buf []uint16)

// dummy Count32 implementation that performs no work
func dummyCount32(counts *[32]int, buf []uint32)

// dummy Count64 implementation that performs no work
func dummyCount64(counts *[64]int, buf []uint64)
