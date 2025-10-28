LIBNAME=	pospop
SOMAJOR=	0
SOMINOR=	0

CC?=		cc
AR?=		ar
RM?=		rm -f
CFLAGS+=	-fpic -g

LIBOBJ=		countavx2_64.o countavx512_64.o countgeneric.o countneon_64.o \
		countsse2_64.o dispatch.o

all: lib${LIBNAME}.so lib${LIBNAME}.a

lib${LIBNAME}.so: ${LIBOBJ}
	${CC} -shared -o $@ -Wl,-soname=lib${LIBNAME}.so.${SOMAJOR} ${LIBOBJ}

lib${LIBNAME}.a: ${LIBOBJ}
	${AR} crs $@ ${LIBOBJ}

test: test.o lib${LIBNAME}.a
	${CC} -o $@ test.o lib${LIBNAME}.a

.PHONY: clean
clean:
	${RM} *.a *.so *.o test
