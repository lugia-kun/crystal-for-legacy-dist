Crystal for Legacy Linux Distributions
======================================

This repository provides a Dockerfile to build [Crystal][^1] for legecy
Linux distributions, such as SLES 11, RHEL 6 and CentOS 6.

The bundled `libgc.a` with the official distribution of Crystal 0.31.0
or later needs GNU ld version 2.26 or later
(ref. [^2]). So,
the main purpose of this repository is the building bdwgc under older
GCC. But, this build process includes full installation of Crystal.

I have not confirmed the source code of Crystal, but Crystal does not
seem to use that feature (relocation `R_X86_64_(REX_)GOTPCRELX`) in
code generation currently, so linking with GNU ld version 2.24 seems
to be OK.

LLVM supports this relocation, and so Clang supports to use this
feature with passing argument `-fno-plt` [^3]. Crystal may also move to
use this relocation in the future releases.

Notes
-----

* The binaries are built under SLES 11.4, acknowledgement to the
  Docker image provided by [barebuild][^4].
* The built binary is statically linked with LLVM, but other libraries
  are shared linked. Required external libraries are glibc, libgcc,
  ncurses and zlib.
* The package includes the full installation of bdwgc, libevent and
  pcre, with both of shared and static libraries. But these libraies
  are not fully configured. For example, pcre does not built with C++
  support.
  - To link your program statically, you also need the static version
    of glibc, which may be avaiable from the OS repository.

* You should NOT report any issues with using the package provided
  here, to the upstream directly. Only if you can confirm your problem
  with the official binary too, please refer upstream
  [CONTRIBUTING][^5] and [ISSUE TEMPLATE][^6].

Limitations
-----------

* Multithreading is not tested, and considered not to work.
* Shards is (currently) not included. Shards won't run on SLES 11,
  RHEL 6 and CentOS 6 because Shards uses new features which is not
  implemented in vendor-provided Git. But you may be able to build the
  newer version of Git which is supported by Shards.
* The `make spec` has not been run. Some specs will definitely fail,
  such as OpenSSL (ex. TLS is not supported), and other library matter
  features.
* Built shared linked executable (and crystal compiler itself too)
  cannot be run with setuid bit set (ref. [^7]).

[^1]: http://crystal-lang.org
[^2]: https://stackoverflow.com/questions/52737698/unable-to-compile-unrecognized-relocation-0x2a-in-section-text
[^3]: https://reviews.llvm.org/D39079
[^4]: https://hub.docker.com/r/barebuild/sles
[^5]: https://github.com/crystal-lang/crystal/blob/master/CONTRIBUTING.md
[^6]: https://github.com/crystal-lang/crystal/blob/master/ISSUE_TEMPLATE.md
[^7]: https://amir.rachum.com/blog/2016/09/17/shared-libraries/#runtime-search-path-security
