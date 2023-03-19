#!/bin/sh

# Note: this script will only work on Linux targets.

# Usage: ./build-glibc.sh [compiler] [arch]
if [ $# -ne 2 ]; then
  echo "Usage: $0 [compiler] [arch]"
  echo "Valid compilers: gcc, clang."
  echo "Valid archs: any glibc valid arch."
  exit 1
fi

# Essential dirs for the glibc build
GLIBCSRC="<path_to_glibc_src>"
BUILDDIR="<path_to_build_dir>"

# Selection of compilers. For the GNU Toolchain, we assume that the build was done
# using build-many-glibcs.py. The tools prefixes will reflect that.
GNUINSTALL="<path_to_GNU_toolchain_installation>"
LLVMINSTALL="<path_to_llvm_toolchain_installation>"

arch="$2"

if [ "$1" = "gcc" ]; then
  COMPILER="${GNUINSTALL}"
  TOOLS_PREFIX="${arch}-glibc-linux"
elif [ "$1" = "clang" ]; then
  COMPILER="${LLVMINSTALL}"
  TOOLS_PREFIX="llvm"
else
  echo "Invalid compiler: $1"
  exit 1
fi

# Select the correct toolchain prefixes
AR="${COMPILER}/bin/${TOOLS_PREFIX}-ar"
AS="${COMPILER}/bin/${TOOLS_PREFIX}-as"
NM="${COMPILER}/bin/${TOOLS_PREFIX}-nm"
OBJDUMP="${COMPILER}/bin/${TOOLS_PREFIX}-objdump"
OBJCOPY="${COMPILER}/bin/${TOOLS_PREFIX}-objcopy"
RANLIB="${COMPILER}/bin/${TOOLS_PREFIX}-ranlib"
READELF="${COMPILER}/bin/${TOOLS_PREFIX}-readelf"
STRIP="${COMPILER}/bin/${TOOLS_PREFIX}-strip"
if [ "${TOOLS_PREFIX}" = "llvm" ]; then
    CC="${COMPILER}/bin/clang -target ${arch}-linux-gnu -fuse-ld=lld -Wno-unused-command-line-argument"
    CXX="${COMPILER}/bin/clang++ -target ${arch}-linux-gnu -fuse-ld=lld -Wno-unused-command-line-argument"
    LD="${COMPILER}/bin/ld.lld"
else
    CC="${COMPILER}/bin/${TOOLS_PREFIX}-gcc"
    CXX="${COMPILER}/bin/${TOOLS_PREFIX}-g++"
    LD="${COMPILER}/bin/${TOOLS_PREFIX}-ld"
fi

if [ -d "${BUILDDIR}" ]; then
    echo "Removing old build directory..."
    rm -rf "${BUILDDIR}"
fi
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

echo "Building glibc for $2 using $1 in ${COMPILER}."

# configure
echo "Configuring glibc..."
CC="${CC}" \
CXX="${CXX}" \
AR="${AR}" \
AS="${AS}" \
LD="${LD}" \
NM="${NM}" \
OBJCOPY="${OBJCOPY}" \
OBJDUMP="${OBJDUMP}" \
RANLIB="${RANLIB}" \
READELF="${READELF}" \
STRIP="${STRIP}" \
CFLAGS="-O2 -g" \
CXXFLAGS="${CFLAGS}" \
${GLIBCSRC}/configure \
            --prefix=/usr \
            --host=${arch}-linux-gnu \
            --with-binutils="${COMPILER}/bin" \
            --enable-stack-protector=all \
            --enable-tunables=yes \
            --enable-bind-now=yes \
            --enable-profile=no > _configure 2>&1
if [ $? -ne 0 ]; then
    echo "configure failed. Check ${BUILDDIR}/_configure for details."
    exit 1
fi

echo "Building glibc..."
make -j$(nproc) > _make 2>&1
if [ $? -ne 0 ]; then
    echo "make failed. Check ${BUILDDIR}/_make for details."
    exit 1
fi

echo "Building glibc tests..."
make -j$(nproc) check run-built-tests=no > _check 2>&1
if [ $? -ne 0 ]; then
    echo "make check failed. Check ${BUILDDIR}/_check for details."
    exit 1
fi

cd "${GLIBCSRC}"
echo "Build finished successfully. If you need to run the testsuite, run 'make check' in ${BUILDDIR}."
exit 0
