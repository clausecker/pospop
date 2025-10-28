#!/bin/sh

for len in `seq 0 64` `seq 128 64 2048`
do
	for align in `seq 0 63`
	do
		./test -n $len -a $align
	done
done
