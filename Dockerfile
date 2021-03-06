FROM barebuild/sles:11 AS crystal-env
WORKDIR /work
ARG CRYSTAL_VERSION=0.35.1
ARG CRYSTAL_RELEASE=2
ENV CRYSTAL_VERSION=${CRYSTAL_VERSION} \
    CRYSTAL_RELEASE=${CRYSTAL_RELEASE} \
    INSTALL_DIR=/opt/crystal-${CRYSTAL_VERSION}-${CRYSTAL_RELEASE}

FROM crystal-env AS crystal-build
ARG LLVM_VERSION=10.0.0
ARG GC_VERSION=8.0.4
ARG LIBEVENT_VERSION=2.1.12
ARG LIBATOMIC_OPS_VERSION=7.6.10
ARG PCRE_VERSION=8.44
ARG YAML_VERSION=0.2.5
ARG SHARDS_VERSION=0.12.0
ARG MOLINILLO_VERSION=0.1.0
ARG CRYSTAL_BINARY_VERSION=0.35.1
ARG CRYSTAL_BINARY_RELEASE=1
ARG SMP_FLAGS

ADD https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3.tar.xz /work/
ADD https://github.com/ivmai/bdwgc/releases/download/v${GC_VERSION}/gc-${GC_VERSION}.tar.gz /work/
ADD https://github.com/ivmai/libatomic_ops/releases/download/v${LIBATOMIC_OPS_VERSION}/libatomic_ops-${LIBATOMIC_OPS_VERSION}.tar.gz /work/
ADD https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz /work/
ADD https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.bz2 /work/
ADD https://github.com/yaml/libyaml/releases/download/${YAML_VERSION}/yaml-${YAML_VERSION}.tar.gz /work/
ADD https://github.com/lugia-kun/crystal-for-legacy-dist/releases/download/${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE}/crystal-${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE}.sles11.x86_64.tar.xz /work/
ADD https://github.com/crystal-lang/crystal/archive/${CRYSTAL_VERSION}/crystal-${CRYSTAL_VERSION}.tar.gz /work/
ADD https://github.com/crystal-lang/shards/archive/v${SHARDS_VERSION}/shards-${SHARDS_VERSION}.tar.gz /work/
ADD https://github.com/crystal-lang/crystal-molinillo/archive/v${MOLINILLO_VERSION}/crystal-molinillo-${MOLINILLO_VERSION}.tar.gz /work/

RUN zypper in -y xz chrpath git

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

RUN set -x && \
    tar xf yaml-${YAML_VERSION}.tar.gz && \
    cd yaml-${YAML_VERSION} && \
    CC=gcc CXX=n/a ./configure --prefix=${INSTALL_DIR} --enable-static --enable-shared && \
    make ${SMP_FLAGS} && \
    make install

ADD crystal-0.35.1-llvm-libc++.patch /work
RUN set -x && \
    tar xf clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3.tar.xz && \
    tar xf crystal-${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE}.sles11.x86_64.tar.xz && \
    tar xf crystal-${CRYSTAL_VERSION}.tar.gz && \
    export CRYSTAL_DIR=/work/crystal-${CRYSTAL_BINARY_VERSION}-${CRYSTAL_BINARY_RELEASE} && \
    export PATH=${CRYSTAL_DIR}/bin:${PATH} && \
    crystal version && \
    rm -f ${CRYSTAL_DIR}/lib/crystal/lib/*.a && \
    cd crystal-${CRYSTAL_VERSION} && \
    patch -p1 < ../crystal-0.35.1-llvm-libc++.patch && \
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
    chrpath -r \$ORIGIN/../../../lib ${INSTALL_DIR}/lib/crystal/bin/* && \
    LLVM_DIR=/work/clang+llvm-${LLVM_VERSION}-x86_64-linux-sles11.3 && \
    cp -p $LLVM_DIR/lib/libc++.so* $LLVM_DIR/lib/libc++abi.so* ${INSTALL_DIR}/lib

ADD shards-0.12.0-local-molinillo.patch /work/
RUN set -x && \
    tar xf shards-${SHARDS_VERSION}.tar.gz && \
    cd shards-${SHARDS_VERSION} && \
    patch </work/shards-0.12.0-local-molinillo.patch && \
    export PATH=${INSTALL_DIR}/bin:$PATH && \
    make MOLINILLO_ARCHIVE=/work/crystal-molinillo-${MOLINILLO_VERSION}.tar.gz && \
    mkdir -p ${INSTALL_DIR}/bin && \
    mkdir -p ${INSTALL_DIR}/share/man/man1 && \
    mkdir -p ${INSTALL_DIR}/share/man/man5 && \
    cp bin/shards ${INSTALL_DIR}/bin && \
    cp man/shards.1 ${INSTALL_DIR}/share/man/man1 && \
    cp man/shard.yml.5 ${INSTALL_DIR}/share/man/man5

FROM crystal-build
RUN set -x && \
    export PATH=${INSTALL_DIR}/bin:$PATH && \
    cd /tmp && \
    echo "puts \"Hallo, World\".sub(/a/, 'e')" > test.cr && \
    crystal build test.cr && ./test && objdump -x test && rm test && \
    crystal build --static test.cr && ./test && rm test

FROM crystal-env
COPY --from=crystal-build ${INSTALL_DIR}/ ${INSTALL_DIR}/
