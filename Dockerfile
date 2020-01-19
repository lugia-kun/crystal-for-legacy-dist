FROM barebuild/sles:11 AS crystal-env
WORKDIR /work
ARG CRYSTAL_VERSION=0.32.1
ARG CRYSTAL_RELEASE=1
ENV CRYSTAL_VERSION=${CRYSTAL_VERSION} \
    CRYSTAL_RELEASE=${CRYSTAL_RELEASE} \
    INSTALL_DIR=/opt/crystal-${CRYSTAL_VERSION}-${CRYSTAL_RELEASE}

FROM crystal-env AS crystal-build
# 9.0.0 is the last version that they provide prebuilt binaries for SLES 11.3
ARG LLVM_VERSION=9.0.0
ARG GC_VERSION=8.0.4
ARG LIBEVENT_VERSION=2.1.11
ARG LIBATOMIC_OPS_VERSION=7.6.10
ARG PCRE_VERSION=8.43
ARG CRYSTAL_BINARY_VERSION=0.31.1
ARG CRYSTAL_BINARY_RELEASE=2
ARG SMP_FLAGS

ADD http://releases.llvm.org/${LLVM_VERSION}/clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3.tar.xz \
    https://github.com/ivmai/bdwgc/releases/download/v${GC_VERSION}/gc-${GC_VERSION}.tar.gz \
    https://github.com/ivmai/libatomic_ops/releases/download/v${LIBATOMIC_OPS_VERSION}/libatomic_ops-${LIBATOMIC_OPS_VERSION}.tar.gz \
    https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz \
    https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.bz2 \
    https://github.com/lugia-kun/crystal-for-legacy-dist/releases/download/${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE}/crystal-${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE}.sles11.x86_64.tar.xz \
    https://github.com/crystal-lang/crystal/archive/${CRYSTAL_VERSION}/crystal-${CRYSTAL_VERSION}.tar.gz \
    /work/

RUN zypper in -y xz chrpath

ENV PATH=${INSTALL_DIR}/bin:/work/clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3/bin:${PATH} \
    LD_LIBRARY_PATH=${INSTALL_DIR}/lib:/work/clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11/lib:${LD_LIBRARY_PATH} \
    LD_RUN_PATH=${INSTALL_DIR}/lib \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig

RUN set -x && \
    tar xf libatomic_ops-${LIBATOMIC_OPS_VERSION}.tar.gz && \
    cd libatomic_ops-${LIBATOMIC_OPS_VERSION} && \
    CC=gcc CXX=n/a ./configure --prefix=${INSTALL_DIR} --enable-static --enable-shared && \
    make ${SMP_FLAGS} && \
    make install

# GC does not use pkg-config for looking up the location of libatomic_ops
ADD feature-thread-stackbottom-upstream.patch /work
RUN set -x && \
    export CPATH=${INSTALL_DIR}/include && \
    tar xf gc-${GC_VERSION}.tar.gz && \
    cd gc-${GC_VERSION} && \
    patch -p1 < ../feature-thread-stackbottom-upstream.patch && \
    CC=gcc CXX=n/a ./configure --prefix=${INSTALL_DIR} --enable-static --enable-shared && \
    make ${SMP_FLAGS} && \
    make install

RUN set -x && \
    tar xf libevent-${LIBEVENT_VERSION}-stable.tar.gz && \
    cd libevent-${LIBEVENT_VERSION}-stable && \
    CC=gcc CXX=n/a ./configure --prefix=${INSTALL_DIR} --enable-static --enable-shared && \
    make ${SMP_FLAGS} && \
    make install

RUN set -x && \
    tar xf pcre-${PCRE_VERSION}.tar.bz2 && \
    cd pcre-${PCRE_VERSION} && \
    CC=gcc CXX=n/a ./configure --prefix=${INSTALL_DIR} --disable-cpp --enable-utf8 --enable-static --enable-shared --enable-unicode-properties && \
    make ${SMP_FLAGS} && \
    make install

ADD crystal-0.31.0-static-llvm.patch /work
RUN set -x && \
    tar xf clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3.tar.xz && \
    tar xf crystal-${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE}.sles11.x86_64.tar.xz && \
    tar xf crystal-${CRYSTAL_VERSION}.tar.gz && \
    export CRYSTAL_DIR=/work/crystal-${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE} && \
    export PATH=${CRYSTAL_DIR}/bin:${PATH} && \
    crystal version && \
    rm -f ${CRYSTAL_DIR}/lib/crystal/lib/*.a && \
    cd crystal-${CRYSTAL_VERSION} && \
    patch -p1 < ../crystal-0.31.0-static-llvm.patch && \
    env \
    CC="gcc" \
    CXX="clang++ -stdlib=libc++" \
    CRYSTAL_LIBRARY_PATH=${INSTALL_DIR}/lib \
    make stats=1 release=1 \
    EXPORTS= \
    LLVM_CONFIG="/work/clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3/bin/llvm-config"

ADD distribution-scripts/linux/files/crystal-wrapper crystal-wrapper.patch /work/
RUN set -x && \
    patch -p3 <crystal-wrapper.patch && \
    cp crystal-wrapper ${INSTALL_DIR}/bin/crystal && \
    cd crystal-${CRYSTAL_VERSION} && \
    mkdir -p ${INSTALL_DIR}/lib/crystal/bin && \
    mkdir -p ${INSTALL_DIR}/share/crystal && \
    mkdir -p ${INSTALL_DIR}/share/man/man1 && \
    cp .build/crystal ${INSTALL_DIR}/lib/crystal/bin && \
    cp -R src ${INSTALL_DIR}/share/crystal && \
    cp man/crystal.1 ${INSTALL_DIR}/share/man/man1 && \
    chrpath -r \$ORIGIN/../lib ${INSTALL_DIR}/lib/*.so* && \
    chrpath -r \$ORIGIN/../../../lib ${INSTALL_DIR}/lib/crystal/bin/*

FROM crystal-build
RUN set -x && \
    export PATH=${INSTALL_DIR}/bin:$PATH && \
    cd /tmp && \
    echo "puts \"Hallo, World\".sub(/a/, 'e')" > test.cr && \
    crystal build test.cr && ./test && objdump -x test && rm test && \
    crystal build --static test.cr && ./test && rm test

FROM crystal-env
COPY --from=crystal-build ${INSTALL_DIR}/ ${INSTALL_DIR}/
