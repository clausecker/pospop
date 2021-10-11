// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

package pospop

import "golang.org/x/sys/cpu"

func count8avx512carry(counts *[8]int, buf []byte)
func count8avx512(counts *[8]int, buf []byte)
func count8avx2(counts *[8]int, buf []byte)
func count8sse2(counts *[8]int, buf []byte)

func count16avx512carry(counts *[16]int, buf []uint16)
func count16avx512(counts *[16]int, buf []uint16)
func count16avx2(counts *[16]int, buf []uint16)
func count16sse2(counts *[16]int, buf []uint16)

func count32avx512carry(counts *[32]int, buf []uint32)
func count32avx512(counts *[32]int, buf []uint32)
func count32avx2(counts *[32]int, buf []uint32)
func count32sse2(counts *[32]int, buf []uint32)

func count64avx512carry(counts *[64]int, buf []uint64)
func count64avx512(counts *[64]int, buf []uint64)
func count64avx2(counts *[64]int, buf []uint64)
func count64sse2(counts *[64]int, buf []uint64)

// AVX-512 implementations placed last as a temporary hack until
// AVX-512 detection has landed into the cpu package

var count8funcs = []count8impl{
	{count8avx512carry, "avx512carry", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count8avx512, "avx512", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count8avx2, "avx2", cpu.X86.HasAVX2},
	{count8sse2, "sse2", cpu.X86.HasSSE2},
	{count8generic, "generic", true},
}

var count16funcs = []count16impl{
	{count16avx512carry, "avx512carry", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count16avx512, "avx512", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count16avx2, "avx2", cpu.X86.HasAVX2},
	{count16sse2, "sse2", cpu.X86.HasSSE2},
	{count16generic, "generic", true},
}

var count32funcs = []count32impl{
	{count32avx512carry, "avx512carry", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count32avx512, "avx512", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count32avx2, "avx2", cpu.X86.HasAVX2},
	{count32sse2, "sse2", cpu.X86.HasSSE2},
	{count32generic, "generic", true},
}

var count64funcs = []count64impl{
	{count64avx512carry, "avx512carry", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count64avx512, "avx512", cpu.X86.HasBMI2 && cpu.X86.HasAVX512BW},
	{count64avx2, "avx2", cpu.X86.HasAVX2},
	{count64sse2, "sse2", cpu.X86.HasSSE2},
	{count64generic, "generic", true},
}
