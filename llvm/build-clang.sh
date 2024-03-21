#!/bin/bash

# This script builds llvm from the base of the source tree.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [toolchain]"
    echo "Valid options are: gnu or llvm."
    exit 1
fi

CHECK_SRC=`grep "The LLVM Compiler Infrastructure" README.md 2>/dev/null`
if [ -z "${CHECK_SRC}" ]; then
    echo "Not in the llvm-project tree base."
    exit 1
fi

BUILDTC="$1"

# Currently supported in Linux and macOS
ARCH="`uname -m`"
OS="`uname -o`"
HOST="${ARCH} ${OS}"
if [ "${OS}" = "GNU/Linux" ];then
    HOST_CPU="`lscpu | grep "Model name" | sed "s/^.* //"`, $(nproc) cores"
elif [ "${OS}" = "Darwin" ];then
    HOST_CPU="`sysctl -n machdep.cpu.brand_string`, `sysctl -n hw.ncpu` cores"
else
    echo "OS not supported. Exiting..."
fi

# Set target architecture and projects/runtimes to build
TARGETS="AArch64;X86;PowerPC"
PROJECTS="lld;flang;mlir;clang;llvm;clang-tools-extra;openmp"
RUNTIMES="compiler-rt"

# Build type: Release, Debug (with asserts) or RelWithDebInfo
BUILD_TYPE="RelWithDebInfo"

# C++ standard
CXX_STD="17"

# Installation prefix
INSTALL_PREFIX=""

# GNU Toolchain and LLVM Toolchain executables path
GNUTC=""
LLVMTC=""

# Optional: ninja parallelism — i.e. -jX. Blank will use all available CPUs.
MAKEPARALLEL=""

# Set test targets here
declare -a TEST_TARGETS=("clang" "flang" "compiler-rt" "openmp")




if [ "${BUILDTC}" = "llvm" ]; then
    BUILDDIR="build"
    TCPATH="${LLVMTC}"
    CC="${TCPATH}/clang"
    CXX="${TCPATH}/clang++"
    LD="${TCPATH}/ld.lld"
elif [ "${BUILDTC}" = "gnu" ]; then
    BUILDDIR="build-gnu"
    TCPATH="${GNUTC}"
    TRIPLE="aarch64-linux-gnu"
    CC="${TCPATH}/${TRIPLE}-gcc"
    CXX="${TCPATH}/${TRIPLE}-g++"
    LD="${TCPATH}/${TRIPLE}-ld"
else
    echo "Invalid toolchain option."
    exit 1
fi

# Check if an old build exists and erase it.
if [ -d "${BUILDDIR}" ]; then
    echo "Old build found in ${BUILDDIR}. Removing it.."
    rm -rf "${BUILDDIR}"
fi

# Check if an old installation exists and erase it.
if [ -d "${INSTALL_PREFIX}" ]; then
    echo "Old installation found in ${INSTALL_PREFIX}. Removing it.."
    rm -rf "${INSTALL_PREFIX}"
fi
mkdir "${INSTALL_PREFIX}"

# Set any desired flags here
CFLAGS="-O2 -g3 -I/usr/include"
CXXFLAGS="${CFLAGS}"

mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

# Execute the build. Using Ninja as default.
echo "--------------------------------------------------"
echo "Starting llvm build..."
echo "--------------------------------------------------"
echo "Build type: ${BUILD_TYPE}"
echo "Build directory: ${BUILDDIR}"
echo "Install directory: ${INSTALL_PREFIX}"
echo "Toolchain: ${BUILDTC} in ${TCPATH}"
echo "Targets: ${TARGETS}"
echo "Projects: ${PROJECTS}"
echo "Runtimes: ${RUNTIMES}"
echo "Host architecture: ${HOST}"
echo "Host CPU: ${HOST_CPU}"
echo "--------------------------------------------------"
echo "Running cmake..."
CC="${CC}" \
CXX="${CXX}" \
LD="${LD}" \
CFLAGS="${CFLAGS}" \
CXXFLAGS="${CXXFLAGS}" \
cmake -G Ninja \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_CXX_FLAGS=-gmlt \
      -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
      -DLLVM_TARGETS_TO_BUILD="${TARGETS}" \
      -DLLVM_ENABLE_PROJECTS="${PROJECTS}" \
      -DLLVM_ENABLE_RUNTIMES="${RUNTIMES}" \
      -DLLVM_ENABLE_WERROR=OFF \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_ENABLE_LLD=ON \
      -DLLVM_LIT_ARGS="-v --xunit-xml-output test-results.xml" \
      -DLLVM_BUILD_EXAMPLES=ON \
      -DFLANG_ENABLE_WERROR=ON \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DBUILD_SHARED_LIBS=ON \
      -DBOLT_CLANG_EXE="${CC}" \
      ../llvm > _cmake_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running cmake. Check ${BUILDDIR}/_cmake_log."
    exit 1
fi

echo "Building..."
ninja ${MAKEPARALLEL} > _ninja_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja. Check ${BUILDDIR}/_ninja_log for more information."
    exit 1
fi

echo "Installing..."
ninja install > _ninja_install_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja install. Check ${BUILDDIR}/_ninja_install_log for more information."
    exit 1
fi

echo "Installation finished in ${INSTALL_PREFIX}."

echo "Testing..."
for i in "${TEST_TARGETS[@]}"; do
    echo "Running check-${i}..."
    ninja check-${i} > _check_${i}_log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error running check-${i} tests. Check ${BUILDDIR}/_check_${i}_log for more information."
        exit 1
    fi
done

exit 0
