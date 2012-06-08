CC_ARM = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc
CC_386 = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/bin/gcc

SDKROOT = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk
SDKROOTSIM = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk

all: openssl curl

openssl: lib/libssl.a lib/libcrypto.a

lib/libssl.a: deps/openssl-1.0.1c
	cd deps/openssl-1.0.1c; \
	CC=$(CC_ARM) ./config no-shared no-asm; \
	perl -i -pe 's!-arch i386!-arch armv7 -isysroot $(SDKROOT)!g' Makefile; \
	make clean && make
	mkdir -p lib/armv7 && mv deps/openssl-1.0.1c/libcrypto.a lib/armv7 && mv deps/openssl-1.0.1c/libssl.a lib/armv7
	cd deps/openssl-1.0.1c; \
	CC=$(CC_ARM) ./config no-shared no-asm; \
	perl -i -pe 's!-arch i386!-arch armv6 -isysroot $(SDKROOT)!g' Makefile; \
	make clean && make
	mkdir -p lib/armv6 && mv deps/openssl-1.0.1c/libcrypto.a lib/armv6 && mv deps/openssl-1.0.1c/libssl.a lib/armv6
	cd deps/openssl-1.0.1c; \
	CC=$(CC_386) ./config no-shared no-asm; \
	perl -i -pe 's!-arch i386!-arch i386 -isysroot $(SDKROOTSIM)!g' Makefile; \
	make clean && make
	mkdir -p lib/i386 && mv deps/openssl-1.0.1c/libcrypto.a lib/i386 && mv deps/openssl-1.0.1c/libssl.a lib/i386
	lipo -output lib/libcrypto.a -create -arch armv7 lib/armv7/libcrypto.a -arch armv6 lib/armv6/libcrypto.a -arch i386 lib/i386/libcrypto.a
	lipo -output lib/libssl.a -create -arch armv7 lib/armv7/libssl.a -arch armv6 lib/armv6/libssl.a -arch i386 lib/i386/libssl.a

deps/openssl-1.0.1c.tar.gz:
	cd deps && curl -O http://www.openssl.org/source/openssl-1.0.1c.tar.gz

deps/openssl-1.0.1c: deps/openssl-1.0.1c.tar.gz
	cd deps && tar xzf openssl-1.0.1c.tar.gz

curl: lib/libcurl.a

lib/libcurl.a: deps/curl-7.26.0
	cd deps/curl-7.26.0; \
	CC=$(CC_ARM) CFLAGS="-arch armv7 -I`pwd`/../openssl-1.0.1c/include -isysroot $(SDKROOT)" LDFLAGS=-L`pwd`/../../lib \
	./configure --with-ssl --host=arm-apple-darwin --enable-ipv6 --disable-shared; \
	find . -name Makefile | xargs -n 1 perl -i -pe 's!-isystem !-I!'; \
	make clean && make
	mkdir -p lib/armv7 && mv deps/curl-7.26.0/lib/.libs/libcurl.a lib/armv7
	cd deps/curl-7.26.0; \
	CC=$(CC_ARM) CFLAGS="-arch armv6 -I`pwd`/../openssl-1.0.1c/include -isysroot $(SDKROOT)" LDFLAGS=-L`pwd`/../../lib \
	./configure --with-ssl --host=arm-apple-darwin --enable-ipv6 --disable-shared; \
	find . -name Makefile | xargs -n 1 perl -i -pe 's!-isystem !-I!'; \
	make clean && make
	mkdir -p lib/armv6 && mv deps/curl-7.26.0/lib/.libs/libcurl.a lib/armv6
	cd deps/curl-7.26.0; \
	CC=$(CC_386) CFLAGS="-arch i386 -I`pwd`/../openssl-1.0.1c/include -isysroot $(SDKROOTSIM)" LDFLAGS=-L`pwd`/../../lib \
	./configure --with-ssl --host=arm-apple-darwin --enable-ipv6 --disable-shared; \
	find . -name Makefile | xargs -n 1 perl -i -pe 's!-isystem !-I!'; \
	make clean && make
	mkdir -p lib/i386 && mv deps/curl-7.26.0/lib/.libs/libcurl.a lib/i386
	lipo -output lib/libcurl.a -create -arch armv7 lib/armv7/libcurl.a -arch armv6 lib/armv6/libcurl.a -arch i386 lib/i386/libcurl.a

deps/curl-7.26.0.tar.bz2:
	cd deps && curl -O http://curl.haxx.se/download/curl-7.26.0.tar.bz2

deps/curl-7.26.0: deps/curl-7.26.0.tar.bz2
	cd deps && tar xjf curl-7.26.0.tar.bz2
