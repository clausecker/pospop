#ifndef POSPOP_H
#define POSPOP_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Each of these functions takes an array of counters, an input buffer,
 * and a buffer length.  The positional population counts of the input
 * buffer are added to the counters array.  Make sure to clear it before
 * if it is uninitialised.
 */

extern	void	count8avx512(uint64_t[8], uint8_t[], size_t);
extern	void	count16avx512(uint64_t[16], uint16_t[], size_t);
extern	void	count32avx512(uint64_t[32], uint32_t[], size_t);
extern	void	count64avx512(uint64_t[64], uint64_t[], size_t);

#ifdef __cplusplus
}
#endif

#endif /* POSPOP_H */
