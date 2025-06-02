// Copyright (c) 2025 Robert Clausecker <fuz@fuz.su>

package pospop

import "golang.org/x/sys/cpu"

var count8dummy = []count8impl{
	{dummyCount8avx512, "dummyAvx512", cpu.X86.HasAVX512},
	{dummyCount8avx, "dummyAvx", cpu.X86.HasAVX && !cpu.X86.HasAVX512},
	{dummyCount8sse, "dummySse", !cpu.X86.HasAVX},
}
var count16dummy = []count16impl{
	{dummyCount16avx512, "dummyAvx512", cpu.X86.HasAVX512},
	{dummyCount16avx, "dummyAvx", cpu.X86.HasAVX && !cpu.X86.HasAVX512},
	{dummyCount16sse, "dummySse", !cpu.X86.HasAVX}, 
}
var count32dummy = []count32impl{
	{dummyCount32avx512, "dummyAvx512", cpu.X86.HasAVX512},
	{dummyCount32avx, "dummyAvx", cpu.X86.HasAVX && !cpu.X86.HasAVX512},
	{dummyCount32sse, "dummySse", !cpu.X86.HasAVX}, 
}
var count64dummy = []count64impl{
	{dummyCount64avx512, "dummyAvx512", cpu.X86.HasAVX512},
	{dummyCount64avx, "dummyAvx", cpu.X86.HasAVX && !cpu.X86.HasAVX512},
	{dummyCount64sse, "dummySse", !cpu.X86.HasAVX}, 
}

// dummy Count8 implementation that performs no work
func dummyCount8avx512(counts *[8]int, buf []uint8)
func dummyCount8avx(counts *[8]int, buf []uint8)
func dummyCount8sse(counts *[8]int, buf []uint8)

// dummy Count16 implementation that performs no work
func dummyCount16avx512(counts *[16]int, buf []uint16)
func dummyCount16avx(counts *[16]int, buf []uint16)
func dummyCount16sse(counts *[16]int, buf []uint16)

// dummy Count32 implementation that performs no work
func dummyCount32avx512(counts *[32]int, buf []uint32)
func dummyCount32avx(counts *[32]int, buf []uint32)
func dummyCount32sse(counts *[32]int, buf []uint32)

// dummy Count64 implementation that performs no work
func dummyCount64avx512(counts *[64]int, buf []uint64)
func dummyCount64avx(counts *[64]int, buf []uint64)
func dummyCount64sse(counts *[64]int, buf []uint64)
