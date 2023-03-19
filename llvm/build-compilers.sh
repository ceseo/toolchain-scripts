#!/bin/bash

# This script assumes it is running from the llvm-project tree base.
# It also assumes that all build prerequisites are installed.

# Set here:
# * Targets to build. Defaults are X86 and AArch64.
# * Projects and runtimes. Add or remove as needed. This will build
#   clang and flang based toolchain by default.
# * Type of build. Default is "Release".
# * Installation prefix.
# * C++ standard. Default is 17.
TARGETS="X86;AArch64"
PROJECTS="clang;flang;lld;openmp;mlir"
RUNTIMES="compiler-rt"
BUILD_TYPE="Release"
INSTALL_PREFIX="<insert_installation_path>"
CXX_STD="17"

# Check if an old build exists and erase it.
if [ -d "build" ]; then
    echo "Old build found. Removing it.."
    rm -rf "build"
fi

mkdir -p build
cd build

# Execute the build. Using Ninja as default.
echo "Running cmake..."
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
    echo "Error running cmake. Check build/_cmake_log."
    exit 1
fi

echo "Building..."
ninja > _ninja_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja. Check build/_ninja_log."
    exit 1
fi

echo "Installing..."
ninja install > _ninja_install_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja install. Check build/_ninja_install_log."
    exit 1
fi

echo "Installation finished in ${INSTALL_PREFIX}."
exit 0
