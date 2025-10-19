void	count8generic(uint64_t[restrict 8], const uint8_t *, size_t);
void	count16generic(uint64_t[restrict 16], const uint16_t *, size_t);
void	count32generic(uint64_t[restrict 32], const uint32_t *, size_t);
void	count64generic(uint64_t[restrict 64], const uint64_t *, size_t);

#ifdef __amd64__
void	count8sse2(uint64_t[restrict 8], const uint8_t *, size_t);
void	count16sse2(uint64_t[restrict 16], const uint16_t *, size_t);
void	count32sse2(uint64_t[restrict 32], const uint32_t *, size_t);
void	count64sse2(uint64_t[restrict 64], const uint64_t *, size_t);

void	count8avx2(uint64_t[restrict 8], const uint8_t *, size_t);
void	count16avx2(uint64_t[restrict 16], const uint16_t *, size_t);
void	count32avx2(uint64_t[restrict 32], const uint32_t *, size_t);
void	count64avx2(uint64_t[restrict 64], const uint64_t *, size_t);

void	count8avx512(uint64_t[restrict 8], const uint8_t *, size_t);
void	count16avx512(uint64_t[restrict 16], const uint16_t *, size_t);
void	count32avx512(uint64_t[restrict 32], const uint32_t *, size_t);
void	count64avx512(uint64_t[restrict 64], const uint64_t *, size_t);
#endif

#ifdef __aarch64__
void	count8neon(uint64_t[restrict 8], const uint8_t *, size_t);
void	count16neon(uint64_t[restrict 16], const uint16_t *, size_t);
void	count32neon(uint64_t[restrict 32], const uint32_t *, size_t);
void	count64neon(uint64_t[restrict 64], const uint64_t *, size_t);
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
