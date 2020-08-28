/*-
 * Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>
 */

/* benchmark harness for the prototype */
#define _XOPEN_SOURCE 700
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

extern void
count8reference(long long counts[restrict 8], const unsigned char *restrict buf, size_t len)
{
	size_t i;
	int j;

	for (i = 0; i < len; i++)
		for (j = 0; j < 8; j++)
			counts[j] += buf[i] >> j & 1;
}

extern void count8asm15(long long [restrict 8], const unsigned char *restrict, size_t);

/*
 * Compute the difference of two struct timespec.
 */
static struct timespec
tsdiff(struct timespec a, struct timespec b)
{
	a.tv_sec -= b.tv_sec;
	a.tv_nsec -= b.tv_nsec;
	if (a.tv_nsec < 0) {
		a.tv_sec -= 1;
		a.tv_nsec += 1000000000;
	}

	return (a);
}

/* perform a benchmark */
static void benchmark(const unsigned char *buf, size_t len, const char *name,
    void (*pospopcnt)(long long[restrict 8], const unsigned char *restrict, size_t))
{
	struct timespec diff, start, end;
	double dur;
	int i, n = 1;
	long long naive_accum[8], asm_accum[8];

	memset(naive_accum, 0, sizeof naive_accum);
	memset(asm_accum, 0, sizeof asm_accum);

	count8reference(asm_accum, buf, len);
	pospopcnt(naive_accum, buf, len);

	if (memcmp(asm_accum, naive_accum, sizeof asm_accum) != 0)
		printf("%s\tmismatch\n", name);

	do {

		clock_gettime(CLOCK_REALTIME, &start);
		for (i = 0; i < n; i++)
			pospopcnt(asm_accum, buf, len);
		clock_gettime(CLOCK_REALTIME, &end);
		diff = tsdiff(end, start);
		n <<= 1;
	} while (diff.tv_sec == 0);

	n >>= 1;
	dur = diff.tv_sec + diff.tv_nsec / 1000000000.0;
	dur /= n;
	printf("%s\t%g B/s\n", name, len / dur);
}

extern int
main(int argc, char *argv[])
{
	size_t len = 8192;
	FILE *random;

	unsigned char *buf;

	if (argc > 1)
		len = atoll(argv[1]) + 31 & ~31LL;

	buf = malloc(len);
	if (buf == NULL) {
		perror("malloc");
		return (EXIT_FAILURE);
	}

	random = fopen("/dev/urandom", "rb");
	if (random == NULL) {
		perror("/dev/urandom");
		return (EXIT_FAILURE);
	}

	fread(buf, 1, len, random);

	benchmark(buf, len, "naive", count8reference);
	benchmark(buf, len, "asm15", count8asm15);
}
