package pospop

import "fmt"

// This example illustrates the positional population count operation.
// For each number in the input, Count8() checks which of its bits are
// set and increments the corresponding counters.  In this example,
// four numbers (1, 3, 5, 9) have bit 0 set; three numbers (2, 3, 6)
// have bit 1 set, two numbers (5, 6) have bit 2 set and only the number
// 9 has bit 3 set.
func ExampleCount8() {
	var counts [8]int
	numbers := []uint8{
		1, // bit 0 set
		2, // bit 1 set
		3, // bits 0 and 1 set
		5, // bits 0 and 2 set
		6, // bits 1 and 2 set
		9, // bits 0 and 3 set
	}

	Count8(&counts, numbers)
	fmt.Println(counts)
	// Output: [4 3 2 1 0 0 0 0]
}
