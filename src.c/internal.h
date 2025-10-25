typedef void count8func(uint64_t[restrict 8], const uint8_t *, size_t);
typedef void count16func(uint64_t[restrict 16], const uint16_t *, size_t);
typedef void count32func(uint64_t[restrict 32], const uint32_t *, size_t);
typedef void count64func(uint64_t[restrict 64], const uint64_t *, size_t);

struct countfuncs {
	count8func	*count8;
	count16func	*count16;
	count32func	*count32;
	count64func	*count64;
};

count8func count8generic;
count16func count16generic;
count32func count32generic;
count64func count64generic;

#ifdef __amd64__
count8func count8sse2, count8avx2, count8avx512;
count16func count16sse2, count16avx2, count16avx512;
count32func count32sse2, count32avx2, count32avx512;
count64func count64sse2, count64avx2, count64avx512;
#endif

#ifdef __aarch64__
count8func count8neon;
count16func count16neon;
count32func count32neon;
count64func count64neon;
#endif

static inline void
count8safe(uint64_t counts[restrict 8], const uint8_t *buf, size_t len)
{
	size_t i, j;

	for (i = 0; i < len; i++)
		for (j = 0; j < 8; j++)
			counts[j] += buf[i] >> j & 1;
}

static inline void
count16safe(uint64_t counts[restrict 16], const uint16_t *buf, size_t len)
{
	size_t i, j;

	for (i = 0; i < len; i++)
		for (j = 0; j < 16; j++)
			counts[j] += buf[i] >> j & 1;
}

static inline void
count32safe(uint64_t counts[restrict 32], const uint32_t *buf, size_t len)
{
	size_t i, j;

	for (i = 0; i < len; i++)
		for (j = 0; j < 32; j++)
			counts[j] += buf[i] >> j & 1;
}

static inline void
count64safe(uint64_t counts[restrict 64], const uint64_t *buf, size_t len)
{
	size_t i, j;

	for (i = 0; i < len; i++)
		for (j = 0; j < 64; j++)
			counts[j] += buf[i] >> j & 1;
}
