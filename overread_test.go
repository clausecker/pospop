//go:build unix

// Copyright (c) 2024 Robert Clausecker <fuz@fuz.su>

package pospop

import (
	"golang.org/x/sys/unix"
	"testing"
)

// Allocate three pages of memory.  Make the first and last page
// inaccessible.  Return the full array as well as just the part
// in the middle (which is accessible).
func mapGuarded() (mapping []byte, slice []byte, err error) {
	pagesize := unix.Getpagesize()
	mapping, err = unix.Mmap(-1, 0, 3*pagesize, unix.PROT_NONE, unix.MAP_ANON|unix.MAP_PRIVATE)
	if err != nil {
		return nil, nil, err
	}

	slice = mapping[pagesize : 2*pagesize : 2*pagesize]
	err = unix.Mprotect(slice, unix.PROT_READ|unix.PROT_WRITE)
	if err != nil {
		unix.Munmap(mapping)
		return nil, nil, err
	}

	return
}

// Verify that our count functions only overread memory in benign ways,
// i.e. such that we never cross a page size boundary.
func TestOverread(t *testing.T) {
	for i := range count8funcs {
		t.Run(count8funcs[i].name, func(tt *testing.T) {
			if !count8funcs[i].available {
				tt.SkipNow()
			}

			testOverread(tt, count8funcs[i].count8)
		})
	}
}

func testOverread(t *testing.T, count8 func(*[8]int, []uint8)) {
	var counters [8]int

	mapping, slice, err := mapGuarded()
	defer unix.Munmap(mapping)
	if err != nil {
		t.Log("Cannot allocate memory:", err)
		t.SkipNow()
	}

	// test large slices that start/end right at the page boundary
	for i := 0; i < 64; i++ {
		for j := len(slice) - 64; j <= len(slice); j++ {
			count8(&counters, slice[i:j])
		}
	}

	// test small slices that start right after the page boundary
	for i := 0; i < 64; i++ {
		for j := i; j <= 64; j++ {
			count8(&counters, slice[i:j])
		}
	}

	// test small slices that end right before the page boundary
	for i := len(slice) - 64; i <= len(slice); i++ {
		for j := i; j <= len(slice); j++ {
			count8(&counters, slice[i:j])
		}
	}
}
