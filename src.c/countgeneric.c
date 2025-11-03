#include <endian.h>
#include <stdint.h>
#include <string.h>

#include "internal.h"

typedef uint64_t word;
typedef uint8_t counter;
#define COUNT_MAX UINT8_MAX

typedef void accum_func(uint64_t *restrict, const counter *);

/* carry:sum = a + b + c */
static inline void
csa(word *carry, word *sum, word a, word b, word c)
{
	word sum1, carry1;

	sum1 = a ^ b;
	carry1 = a & b;

	*sum = sum1 ^ c;
	*carry = carry1 | sum1 & c;
}

/*
 * Generic kernel.  Follows the code in the paper, but implemented
 * in a generic manner with a word width of 64 bits.  Length is given
 * in bytes.  Return the amount of bytes not processed.
 */
static size_t
countgeneric(accum_func *accum, uint64_t *restrict counts, const uint64_t *buf, size_t len)
{
	counter counters[64];
	word headmask = ~(word)0;
	word a, b, c, d, e;
	word a0, a1, a2, a3, a4, a5, a6;
	word b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10;
	word c0, c1, c2, c3, c4;
	word d0, d1;
	word ba0, ba1, dc0, dc1, dcba0, dcba1, dcba2, dcba3;
	size_t misalignment, countcap = COUNT_MAX, i, origlen;

	memset(counters, 0, sizeof counters);

	misalignment = (uintptr_t)buf & 7;
#if BYTE_ORDER == LITTLE_ENDIAN
	headmask <<= 8 * misalignment;
#elif BYTE_ORDER == BIG_ENDIAN
	headmask >>= 8 * misalignment;
#else
# error unknown byte order
#endif

	origlen = len;
	len += misalignment;
	buf = (uint64_t *)((uintptr_t)buf - misalignment);

	if (len < 15 * 8)
		return (origlen);

	/* process head */
	csa(&b0, &a0, buf[0] & headmask, buf[1], buf[2]);
	csa(&b1, &a1, buf[3], buf[4], buf[5]);
	csa(&b2, &a2, buf[6], buf[7], buf[8]);
	csa(&b3, &a3, buf[9], buf[10], buf[11]);
	csa(&b4, &a4, buf[12], buf[13], buf[14]);

	csa(&b5, &a5, a0, a1, a2);
	csa(&c0, &b6, b0, b1, b2);
	csa(&b7, &a, a3, a4, a5);
	csa(&c1, &b8, b3, b4, b5);
	csa(&c2, &b, b6, b7, b8);
	csa(&d, &c, c0, c1, c2);

	buf += 15;
	len -= 8 * 15;

	while (len >= 16 * 8) {
		if (countcap < 16) {
			accum(counts, counters);
			countcap = COUNT_MAX;
		}

		/* process input chunk */
		csa(&b0, &a0, a, buf[0], buf[1]);
		csa(&b1, &a1, buf[2], buf[3], buf[4]);
		csa(&b2, &a2, buf[5], buf[6], buf[7]);
		csa(&b3, &a3, buf[8], buf[9], buf[10]);
		csa(&b4, &a4, buf[11], buf[12], buf[13]);

		csa(&b5, &a5, a0, a1, a2);
		csa(&c0, &b6, b, b0, b1);
		csa(&b7, &a6, a3, a4, buf[14]);
		csa(&c1, &b8, b2, b3, b4);

		csa(&b9, &a, a5, a6, buf[15]);
		csa(&c2, &b10, b5, b7, b8);
		csa(&d0, &c3, c, c0, c1);

		csa(&c4, &b, b6, b9, b10);
		csa(&d1, &c, c2, c3, c4);
		csa(&e, &d, d, d0, d1);

		/* add to counts */
		for (i = 0; i < 64; i++)
			counters[i] += 16 * (e >> i & 1);

		countcap -= 16;
		buf += 16;
		len -= 16 * 8;
	}

	/* transpose and process d:b:c:a */
	ba0 = a & 0x5555555555555555 | b << 1 & 0xaaaaaaaaaaaaaaaa;
	ba1 = a >> 1 & 0x5555555555555555 | b & 0xaaaaaaaaaaaaaaaa;
	dc0 = c & 0x5555555555555555 | d << 1 & 0xaaaaaaaaaaaaaaaa;
	dc1 = c >> 1 & 0x5555555555555555 | d & 0xaaaaaaaaaaaaaaaa;

	dcba0 = ba0 & 0x3333333333333333 | dc0 << 2 & 0xcccccccccccccccc;
	dcba1 = ba0 >> 2 & 0x3333333333333333 | dc0 & 0xcccccccccccccccc;
	dcba2 = ba1 & 0x3333333333333333 | dc1 << 2 & 0xcccccccccccccccc;
	dcba3 = ba1 >> 2 & 0x3333333333333333 | dc1 & 0xcccccccccccccccc;

	for (i = 0; i < 64; i += 4) {
		counters[i + 0] += dcba0 >> i & 0xf;
		counters[i + 1] += dcba2 >> i & 0xf;
		counters[i + 2] += dcba1 >> i & 0xf;
		counters[i + 3] += dcba3 >> i & 0xf;
	}

	accum(counts, counters);

	return (len);
}

static void
accum8(uint64_t counts[restrict 8], const counter counters[64])
{
	size_t i;
	for (i = 0; i < 64; i++)
		counts[i % 8] += counters[i];
}

static void
accum16(uint64_t counts[restrict 16], const counter counters[64])
{
	size_t i;
	for (i = 0; i < 64; i++)
		counts[i % 16] += counters[i];
}

static void
accum32(uint64_t counts[restrict 32], const counter counters[64])
{
	size_t i;
	for (i = 0; i < 64; i++)
		counts[i % 32] += counters[i];
}

static void
accum64(uint64_t counts[restrict 64], const counter counters[64])
{
	size_t i;
	for (i = 0; i < 64; i++)
		counts[i] += counters[i];
}

void
count8generic(uint64_t counts[restrict 8], const uint8_t *buf, size_t len)
{
	size_t rest;

	rest = countgeneric(accum8, counts, (const uint64_t *)buf, len);
	count8safe(counts, buf + (len - rest), rest);
}

void
count16generic(uint64_t counts[restrict 16], const uint16_t *buf, size_t len)
{
	size_t rest;

	rest = countgeneric(accum16, counts, (const uint64_t *)buf, len * 2) / 2;
	count16safe(counts, buf + (len - rest), rest);
}

void
count32generic(uint64_t counts[restrict 32], const uint32_t *buf, size_t len)
{
	size_t rest;

	rest = countgeneric(accum32, counts, (const uint64_t *)buf, len * 4) / 4;
	count32safe(counts, buf + (len - rest), rest);
}

void
count64generic(uint64_t counts[restrict 64], const uint64_t *buf, size_t len)
{
	size_t rest;

	rest = countgeneric(accum64, counts, (const uint64_t *)buf, len * 8) / 8;
	count64safe(counts, buf + (len - rest), rest);
}
