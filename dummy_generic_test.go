// Copyright (c) 2025 Robert Clausecker <fuz@fuz.su>

//go:build !arm64

package pospop

var count8dummy = []count8impl{{dummyCount8, "dummy", true}}
var count16dummy = []count16impl{{dummyCount16, "dummy", true}}
var count32dummy = []count32impl{{dummyCount32, "dummy", true}}
var count64dummy = []count64impl{{dummyCount64, "dummy", true}}

var sink8 uint8
var sink16 uint16
var sink32 uint32
var sink64 uint64

// dummy Count8 implementation that performs no work
func dummyCount8(counts *[8]int, buf []uint8) {
	var sum uint8

	for _, x := range buf {
		sum += x
	}

	sink8 = sum
}

// dummy Count16 implementation that performs no work
func dummyCount16(counts *[16]int, buf []uint16) {
	var sum uint16

	for _, x := range buf {
		sum += x
	}

	sink16 = sum
}

// dummy Count32 implementation that performs no work
func dummyCount32(counts *[32]int, buf []uint32) {
	var sum uint32

	for _, x := range buf {
		sum += x
	}

	sink32 = sum
}

// dummy Count64 implementation that performs no work
func dummyCount64(counts *[64]int, buf []uint64) {
	var sum uint64

	for _, x := range buf {
		sum += x
	}

	sink64 = sum
}
