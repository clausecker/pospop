LIBNAME=	pospop
SOMAJOR=	0
SOMINOR=	1

AR?=		ar
CC?=		cc
INSTALL?=	install
LN?=		ln
RM?=		rm -f
SH?=		sh

CFLAGS+=	-fpic -g -Wall -Wextra -Wno-parentheses

PREFIX?=	/usr/local

LIBOBJ=		countavx2_64.o countavx512_64.o countgeneric.o countneon_64.o \
		countsse2_64.o dispatch.o

all: lib${LIBNAME}.so lib${LIBNAME}.a

lib${LIBNAME}.so: ${LIBOBJ} libpospop.map
	${CC} -shared -o $@ -Wl,--version-script=libpospop.map -Wl,-soname=lib${LIBNAME}.so.${SOMAJOR} ${LIBOBJ}

lib${LIBNAME}.a: ${LIBOBJ}
	${AR} crs $@ ${LIBOBJ}

test: test.o lib${LIBNAME}.a
	${CC} -o $@ test.o lib${LIBNAME}.a

.PHONY: check
check: test
	${SH} dotest.sh

.PHONY: install
install: lib${LIBNAME}.so lib${LIBNAME}.a
	${INSTALL} -d ${PREFIX}/lib ${PREFIX}/include
	${INSTALL} -m 0644 pospop.h ${PREFIX}/include/
	${INSTALL} -m 0755 lib${LIBNAME}.a ${PREFIX}/lib/
	${INSTALL} -m 0755 lib${LIBNAME}.so ${PREFIX}/lib/lib${LIBNAME}.so.${SOMAJOR}.${SOMINOR}
	${LN} -s -f lib${LIBNAME}.so.${SOMAJOR}.${SOMINOR} ${PREFIX}/lib/lib${LIBNAME}.so.${SOMAJOR}
	${LN} -s -f lib${LIBNAME}.so.${SOMAJOR}.${SOMINOR} ${PREFIX}/lib/lib${LIBNAME}.so

.PHONY: clean
clean:
	${RM} *.a *.so *.o test
