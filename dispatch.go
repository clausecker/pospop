// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

// Copyright ©2020 Robert Clausecker <fuz@fuz.su>.  All rights reserved.

// Positional population counts.
//
// The kernels works on a block size of 240 or 480 bytes (depending on
// whether AVX2 is available or not).  A buffer size that is a multiple
// of 480 bytes and at least 10 kB in size is recommended.
//
// Right now, kernels exist for Count8 and Count16 on both 386 and amd64
// with SSE2 or AVX2.  An appropriate implementation is chosen at
// runtime.  If no kernel is present, a portable (but slow) fallback
// implementation will be used.
//
// Further kernels and architectures may be implemented in future
// versions of this library.  The interface is expected to remain stable.

package pospop

// each platform must provide arrays count8funcs, coun16funcs,
// count32funcs, and count64funcs of type count8impl, ... listing
// the available implementations.  The member available indicates that
// the function would run on this machine.  The dispatch code picks the
// lowest-numbered function in the array which is available.  The
// generic implementation should be available under all circumstances.
// The name should not repeat the "count#" prefix.

type count8impl struct {
	count8    func(*[8]int, []uint8)
	name      string
	available bool
}

type count16impl struct {
	count16   func(*[16]int, []uint16)
	name      string
	available bool
}

type count32impl struct {
	count32   func(*[32]int, []uint32)
	name      string
	available bool
}

type count64impl struct {
	count64   func(*[64]int, []uint64)
	name      string
	available bool
}

// dispatch ids
var count8id = func() int {
	for i := range count8funcs {
		if count8funcs[i].available {
			return i
		}
	}

	panic("no implementation of count8 available")
}()

var count16id = func() int {
	for i := range count16funcs {
		if count16funcs[i].available {
			return i
		}
	}

	panic("no implementation of count16 available")
}()

var count32id = func() int {
	for i := range count32funcs {
		if count32funcs[i].available {
			return i
		}
	}

	panic("no implementation of count32 available")
}()

var count64id = func() int {
	for i := range count64funcs {
		if count64funcs[i].available {
			return i
		}
	}

	panic("no implementation of count64 available")
}()

// Count the number of corresponding set bits of the bytes in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x01, counts[1] for 0x02, and so on to
// counts[7] for 0x80.
func Count8(counts *[8]int, buf []uint8) {
	count8funcs[count8id].count8(counts, buf)
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x001, counts[1] for 0x0002, and so on
// to counts[15] for 0x8000.
func Count16(counts *[16]int, buf []uint16) {
	count16funcs[count16id].count16(counts, buf)
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x0000001, counts[1] for 0x00000002,
// and so on to counts[31] for 0x80000000.
func Count32(counts *[32]int, buf []uint32) {
	count32funcs[count32id].count32(counts, buf)
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x000000000000001, counts[1] for
// 0x0000000000000002, and so on to counts[31] for 0x8000000000000000.
func Count64(counts *[64]int, buf []uint64) {
	count64funcs[count64id].count64(counts, buf)
}
