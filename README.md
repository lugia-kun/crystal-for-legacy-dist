Crystal for Legacy Linux Distributions
======================================

This repository provides a Dockerfile to build [Crystal][^1] for legecy
Linux distributions, such as SLES 11, RHEL 6 and CentOS 6.

The bundled `libgc.a` with the official distribution of Crystal 0.31.0
or later needs GNU ld version 2.26 or later (ref. [^2] and [^3], and
note that this problem has been solved). So, the main purpose of this
repository is the building bdwgc under older GCC.

This build also includes all mandatory libraries to run any Crystal
programs, which is not included by the official distribution.

Requirements
------------

* The built binary is statically linked with LLVM, but other libraries
  are shared linked. Required external libraries are:
  - glibc (>= 2.10),
  - libgcc (>= 3.3),
  - ncurses (libncurses.so.5), and
  - zlib (>= 1.2).
* You need a C compiler and development files of glibc to build a
  crystal application.
* You need to install Git to use shards.
* You may need to build libraries or install development files of them
  if your program depends on some parts of Crystal standard libraries,
  for example, OpenSSL (OpenSSL, LibreSSL, etc), XML (libxml), etc.

Notes
-----

* The binaries are built under SLES 11.4, acknowledgement to the
  Docker image provided by [barebuild][^5].
* The package includes the full installation of bdwgc, libevent, pcre
  and libyaml, with both of shared and static libraries. But these
  libraies are not fully configured. For example, pcre does not built
  with C++ support.
  - To link your program statically, you also need the static version
    of glibc, which may be available from the OS repository.
* An application built by this compiler is considered to be for
  **your** environment.  It is not guaranteed to work on other
  environments.
  - For example, if you build an application with installed glibc
    2.17, it is considered to need glibc 2.17 must be installed, not
    2.10 (of the compiler's dependency).
* You should NOT report any issues with using the package provided
  here, to the upstream directly. Only if you can confirm your problem
  with the official binary too, please refer upstream's
  [CONTRIBUTING][^7] and [ISSUE TEMPLATE][^8].

Limitations
-----------

* Multithreading is not tested, and considered not to work (#1).
* The `make spec` has not been run (#2).
* Shards may use some new features which is not implemented in
  vendor-provided Git. But you can build the newer version of Git
  which is supported by Shards. Git is not included.
* Built shared linked executable (and crystal compiler itself too)
  cannot be run with setuid bit set (ref. [^9]).
  - You have to remove RUNPATH (or RPATH) with `chrpath` command and
    use `LD_LIBRARY_PATH` to do this.
* The compiler may not generate Position Independent Executable.

[^1]: http://crystal-lang.org
[^2]: https://stackoverflow.com/questions/52737698/unable-to-compile-unrecognized-relocation-0x2a-in-section-text
[^3]: https://github.com/crystal-lang/crystal/issues/8653
[^4]: https://reviews.llvm.org/D39079
[^5]: https://hub.docker.com/r/barebuild/sles
[^6]: http://llvm.org/
[^7]: https://github.com/crystal-lang/crystal/blob/master/CONTRIBUTING.md
[^8]: https://github.com/crystal-lang/crystal/blob/master/ISSUE_TEMPLATE.md
[^9]: https://amir.rachum.com/blog/2016/09/17/shared-libraries/#runtime-search-path-security
