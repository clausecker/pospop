#ifndef POSPOP_H
#define POSPOP_H

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus) || __STDC_VERSION__ < 199901L
# define POSPOP_RESTRICT
#else
# define POSPOP_RESTRICT restrict
#endif

#ifdef __cplusplus
extern "C" {
#endif

void	pospopcount8(uint64_t[POSPOP_RESTRICT 8], const uint8_t *, size_t);
void	pospopcount16(uint64_t[POSPOP_RESTRICT 16], const uint16_t *, size_t);
void	pospopcount32(uint64_t[POSPOP_RESTRICT 32], const uint32_t *, size_t);
void	pospopcount64(uint64_t[POSPOP_RESTRICT 64], const uint64_t *, size_t);

#ifdef __cplusplis
}
#endif

#endif /* defined(POSPOP_H) */
