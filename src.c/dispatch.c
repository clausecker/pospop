#include "pospop.h"
#include "internal.h"

#ifdef __amd64__
static const struct countfuncs sse2funcs = {
	.family = "sse2",
	.count8 = count8sse2,
	.count16 = count16sse2,
	.count32 = count32sse2,
	.count64 = count64sse2,
};

static const struct countfuncs avx2funcs = {
	.family = "avx2",
	.count8 = count8avx2,
	.count16 = count16avx2,
	.count32 = count32avx2,
	.count64 = count64avx2,
};

static const struct countfuncs avx512funcs = {
	.family = "avx512",
	.count8 = count8avx512,
	.count16 = count16avx512,
	.count32 = count32avx512,
	.count64 = count64avx512,
};

enum {
	EAX, ECX, EDX, EBX
};

static inline void
cpuid(int leaf, uint32_t regs[4])
{
	asm ("cpuid" : "=a"(regs[EAX]), "=c"(regs[ECX]), "=d"(regs[EDX]), "=b"(regs[EBX]) : "0"(leaf));
}

static inline void
cpuidx(int leaf, int subleaf, uint32_t regs[4])
{
	asm ("cpuid" : "=a"(regs[EAX]), "=c"(regs[ECX]), "=d"(regs[EDX]), "=b"(regs[EBX]) : "0"(leaf), "1"(subleaf));
}

static const struct countfuncs *
find_pospop_impl(void)
{
	uint32_t regs[4];
	uint32_t max_leaf;
	uint32_t eax7_ecx0_ebx = 0;

	cpuid(0, regs);
	max_leaf = regs[EAX];

	if (max_leaf >= 7) {
		cpuidx(7, 0, regs);

		eax7_ecx0_ebx = regs[EBX];
	}

	/* BMI2, AVX512-F, and AVX512-BW supported? */
	if ((eax7_ecx0_ebx & 0x40010100) == 0x40010100)
		return (&avx512funcs);

	/* BMI2 and AVX2 supported? */
	if ((eax7_ecx0_ebx & 0x120) == 0x120)
		return (&avx2funcs);

	/* fallback */
	return (&sse2funcs);
}

count8func pospopcount8 __attribute__((ifunc("count8resolver")));
count16func pospopcount16 __attribute__((ifunc("count16resolver")));
count32func pospopcount32 __attribute__((ifunc("count32resolver")));
count64func pospopcount64 __attribute__((ifunc("count64resolver")));

static count8func *
count8resolver(void)
{
	return (find_pospop_impl()->count8);
}

static count16func *
count16resolver(void)
{
	return (find_pospop_impl()->count16);
}

static count32func *
count32resolver(void)
{
	return (find_pospop_impl()->count32);
}

static count64func *
count64resolver(void)
{
	return (find_pospop_impl()->count64);
}
#elif defined(__aarch64__)
void
pospopcount8(uint64_t counts[restrict 8], const uint8_t *buf, size_t len)
{
	count8neon(counts, buf, len);
}

void
pospopcount16(uint64_t counts[restrict 16], const uint16_t *buf, size_t len)
{
	count16neon(counts, buf, len);
}

void
pospopcount32(uint64_t counts[restrict 32], const uint32_t *buf, size_t len)
{
	count32neon(counts, buf, len);
}

void
pospopcount64(uint64_t counts[restrict 64], const uint64_t *buf, size_t len)
{
	count64neon(counts, buf, len);
}
#else
void
pospopcount8(uint64_t counts[restrict 8], const uint8_t *buf, size_t len)
{
	count8generic(counts, buf, len);
}

void
pospopcount16(uint64_t counts[restrict 16], const uint16_t *buf, size_t len)
{
	count16generic(counts, buf, len);
}

void
pospopcount32(uint64_t counts[restrict 32], const uint32_t *buf, size_t len)
{
	count32generic(counts, buf, len);
}

void
pospopcount64(uint64_t counts[restrict 64], const uint64_t *buf, size_t len)
{
	count64generic(counts, buf, len);
}
#endif
