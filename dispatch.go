// Positional population count.
package pospop

// positional population count dispatch functions
// these can be overwritten by platform specific code as needed
var count8 = count8generic
var count16 = count16generic
var count32 = count32generic
var count64 = count64generic

// Count the number of corresponding set bits of the bytes in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x01, counts[1] for 0x02, and so on to
// counts[7] for 0x80.
func Count8(counts *[8]int, buf []uint8) {
	count8(counts, buf)
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x001, counts[1] for 0x0002, and so on
// to counts[15] for 0x8000.
func Count16(counts *[16]int, buf []uint16) {
	count16(counts, buf)
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x0000001, counts[1] for 0x00000002,
// and so on to counts[31] for 0x80000000.
func Count32(counts *[32]int, buf []uint32) {
	count32(counts, buf)
}

// Count the number of corresponding set bits of the values in buf and
// add the results to counts.  Each element of counts keeps track of a
// different place; counts[0] for 0x000000000000001, counts[1] for
// 0x0000000000000002, and so on to counts[31] for 0x8000000000000000.
func Count64(counts *[64]int, buf []uint64) {
	count64(counts, buf)
}
