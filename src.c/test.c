#include <limits.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "pospop.h"
#include "internal.h"

enum { ALIGNMENT = 64 };

static bool verbose = false;

static struct countfuncs funcs[] = {
#ifdef __amd64__
	{
		.family = "sse2",
		.count8 = count8sse2,
		.count16 = count16sse2,
		.count32 = count32sse2,
		.count64 = count64sse2,
	},
	{
		.family = "avx2",
		.count8 = count8avx2,
		.count16 = count16avx2,
		.count32 = count32avx2,
		.count64 = count64avx2,
	},
	{
		.family = "avx512",
		.count8 = count8avx512,
		.count16 = count16avx512,
		.count32 = count32avx512,
		.count64 = count64avx512,
	},
#endif /* defined(__amd64__) */
#ifdef __aarch64__
	{
		.family = "neon",
		.count8 = count8neon,
		.count16 = count16neon,
		.count32 = count32neon,
		.count64 = count64neon,
	},
#endif /* defined(__arch64__) */
	{
		.family = "generic",
		.count8 = count8generic,
		.count16 = count16generic,
		.count32 = count32generic,
		.count64 = count64generic,
	},
};

static int check_count64(const uint64_t *buf, size_t nmemb);
static int check_count32(const uint32_t *buf, size_t nmemb);
static int check_count16(const uint16_t *buf, size_t nmemb);
static int check_count8(const uint8_t *buf, size_t nmemb);
static void set_single(char *buf, size_t len);

static void
usage(const char *argv0)
{
	fprintf(stderr, "usage: %s [-a misalignment] [-n size] [-v1]\n", argv0);
	exit(EXIT_FAILURE);
}

int
main(int argc, char *argv[])
{
	char *buf;
	size_t size = 1000, misalignment = 0;
	int c, res = 0, single = 0;

	while (c = getopt(argc, argv, "1a:n:v"), c != -1)
		switch (c) {
		case '1':
			single = 1;
			break;

		case 'a':
			misalignment = (size_t)strtoull(optarg, NULL, 0);
			break;

		case 'n':
			size = (size_t)strtoull(optarg, NULL, 0);
			break;

		case 'v':
			verbose = true;
			break;

		default:
			usage(argv[0]);
		}

	if (optind != argc)
		usage(argv[0]);

	if (misalignment >= ALIGNMENT) {
		fprintf(stderr, "misalignment must be in range 0 .. %d\n", ALIGNMENT);
		return (EXIT_FAILURE);
	}

	buf = aligned_alloc(ALIGNMENT, size + ALIGNMENT);
	if (buf == NULL) {
		perror("aligned_alloc");
		return (EXIT_FAILURE);
	}

	if (single)
		set_single(buf, size);
	else
		arc4random_buf(buf, size);

	if (verbose)
		printf("testing size = %zu, misalignment = %zu\n", size, misalignment);

	res |= check_count64((const uint64_t *)buf + misalignment / 8, size / 8);
	res |= check_count32((const uint32_t *)buf + misalignment / 4, size / 4);
	res |= check_count16((const uint16_t *)buf + misalignment / 2, size / 2);
	res |= check_count8((const uint8_t *)buf + misalignment, size);

	return (res);
}

static void set_single(char *buf, size_t len)
{
	size_t i;

	if (len > UINT32_MAX / CHAR_BIT)
		len = UINT32_MAX / CHAR_BIT;

	i = arc4random_uniform(len / CHAR_BIT);
	if (verbose)
		printf("byte %zu bit %zu set\n", i / 8, i % 8);

	memset(buf, 0, len);
	buf[i / 8] = 1 << i % 8;
}

static void
show_diff(const uint64_t counts[], const uint64_t ref[], size_t n)
{
	size_t i;

	printf("\nref:\n");
	for (i = 0; i < n; i++)
		printf("%7llu%c", (unsigned long long)ref[i], i % 8 == 7 ? '\n' : ' ');

	printf("\ncounts:\n");
	for (i = 0; i < n; i++)
		printf("%7llu%c", (unsigned long long)counts[i], i % 8 == 7 ? '\n' : ' ');

	printf("\ndiff:\n");
	for (i = 0; i < n; i++)
		printf("%7llu%c", (unsigned long long)counts[i] - ref[i], i % 8 == 7 ? '\n' : ' ');

	printf("\n\n");
}

static int
check_count64(const uint64_t *buf, size_t nmemb)
{
	uint64_t counts[64], ref[64];
	size_t i;
	int res = 0;

	memset(ref, 0, sizeof ref);
	count64safe(ref, buf, nmemb);

	for (i = 0; i < sizeof funcs / sizeof *funcs; i++) {
		memset(counts, 0, sizeof counts);
		funcs[i].count64(counts, buf, nmemb);

		if (memcmp(counts, ref, sizeof counts) != 0) {
			printf("count64%s: FAIL (buf = %p, len = %zu)\n", funcs[i].family, buf, nmemb);
			if (verbose)
				show_diff(counts, ref, 64);

			res = EXIT_FAILURE;
		} else if (verbose)
			printf("count64%s: ok\n", funcs[i].family);
	}

	return (res);
}

static int
check_count32(const uint32_t *buf, size_t nmemb)
{
	uint64_t counts[32], ref[32];
	size_t i;
	int res = 0;

	memset(ref, 0, sizeof ref);
	count32safe(ref, buf, nmemb);

	for (i = 0; i < sizeof funcs / sizeof *funcs; i++) {
		memset(counts, 0, sizeof counts);
		funcs[i].count32(counts, buf, nmemb);

		if (memcmp(counts, ref, sizeof counts) != 0) {
			printf("count32%s: FAIL (buf = %p, len = %zu)\n", funcs[i].family, buf, nmemb);
			if (verbose)
				show_diff(counts, ref, 32);

			res = EXIT_FAILURE;
		} else if (verbose)
			printf("count32%s: ok\n", funcs[i].family);
	}

	return (res);
}

static int
check_count16(const uint16_t *buf, size_t nmemb)
{
	uint64_t counts[16], ref[16];
	size_t i;
	int res = 0;

	memset(ref, 0, sizeof ref);
	count16safe(ref, buf, nmemb);

	for (i = 0; i < sizeof funcs / sizeof *funcs; i++) {
		memset(counts, 0, sizeof counts);
		funcs[i].count16(counts, buf, nmemb);

		if (memcmp(counts, ref, sizeof counts) != 0) {
			printf("count16%s: FAIL (buf = %p, len = %zu)\n", funcs[i].family, buf, nmemb);
			if (verbose)
				show_diff(counts, ref, 16);

			res = EXIT_FAILURE;
		} else if (verbose)
			printf("count16%s: ok\n", funcs[i].family);
	}

	return (res);
}

static int
check_count8(const uint8_t *buf, size_t nmemb)
{
	uint64_t counts[8], ref[8];
	size_t i;
	int res = 0;

	memset(ref, 0, sizeof ref);
	count8safe(ref, buf, nmemb);

	for (i = 0; i < sizeof funcs / sizeof *funcs; i++) {
		memset(counts, 0, sizeof counts);
		funcs[i].count8(counts, buf, nmemb);

		if (memcmp(counts, ref, sizeof counts) != 0) {
			printf("count8%s: FAIL (buf = %p, len = %zu)\n", funcs[i].family, buf, nmemb);
			if (verbose)
				show_diff(counts, ref, 8);

			res = EXIT_FAILURE;
		} else if (verbose)
			printf("count8%s: ok\n", funcs[i].family);
	}

	return (res);
}
