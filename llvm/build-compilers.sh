#!/bin/bash

# This script assumes it is running from the llvm-project tree base.
# It also assumes that all build prerequisites are installed.

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

# Set here:
# * Targets to build. Default is AArch64.
# * Projects and runtimes. Add or remove as needed. This will build
#   clang and flang based toolchain by default.
# * Type of build. Default is "Release".
# * Installation prefix.
# * C++ standard. Default is 17.
TARGETS="AArch64"
PROJECTS="clang;flang;lld;openmp;mlir"
RUNTIMES="compiler-rt"
BUILD_TYPE="Release"
INSTALL_PREFIX="<insert_installation_path>"
CXX_STD="17"

if [ "${BUILDTC}" = "llvm" ]; then
    BUILDDIR="build"
    TCPATH="<insert_llvm_instalation_path>"
    CC="${TCPATH}/clang"
    CXX="${TCPATH}/clang++"
    LD="${TCPATH}/ld.lld"
elif [ "${BUILDTC}" = "gnu" ]; then
    BUILDDIR="build-gnu"
    TCPATH="<insert_gnu_instalation_path>"
    TRIPLE="<insert_arch_triple>"
    CC="${TCPATH}/${TRIPLE}-gcc"
    CXX="${TCPATH}/${TRIPLE}-g++"
    LD="${TCPATH}/${TRIPLE}-ld"
else
    echo "Invalid toolchain option."
    exit 1
fi

# Check if an old build exists and erase it.
if [ -d "${BUILDDIR}" ]; then
    echo "Old build found. Removing it.."
    rm -rf "${BUILDDIR}"
fi

mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

# Set any desired flags here
CFLAGS="-O2 -g3"
CXXFLAGS="${CFLAGS}"

# Execute the build. Using Ninja as default.
echo "Running cmake..."
CC="${CC}" \
CXX="${CXX}" \
LD="${LD}" \
CFLAGS="${CFLAGS}" \
CXXFLAGS="${CXXFLAGS}" \
cmake -G Ninja \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
      -DCMAKE_CXX_STANDARD="${CXX_STD}" \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DFLANG_ENABLE_WERROR=ON \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_TARGETS_TO_BUILD="${TARGETS}" \
      -DLLVM_LIT_ARGS=-v \
      -DLLVM_ENABLE_PROJECTS="${PROJECTS}" \
      -DLLVM_ENABLE_RUNTIMES="${RUNTIMES}" \
      ../llvm > _cmake_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running cmake. Check ${BUILDDIR}/_cmake_log."
    exit 1
fi

echo "Building..."
ninja > _ninja_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja. Check ${BUILDDIR}/_ninja_log."
    exit 1
fi

echo "Installing..."
ninja install > _ninja_install_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja install. Check ${BUILDDIR}/_ninja_install_log."
    exit 1
fi

echo "Installation finished in ${INSTALL_PREFIX}."
exit 0
