#!/bin/bash

# This script is useful for debugging Flang. It allows building only the compiler
# with debug information.

REBUILD_BASE="$1"
TARGETS="X86;AArch64"
PROJECTS="clang;flang;lld;openmp;mlir"
RUNTIMES="compiler-rt"
BUILD_TYPE="Debug"
INSTALL_BASE_PREFIX="/home/carlos.seo/.local/flang-base"
INSTALL_FLANG_PREFIX="/home/carlos.seo/.local/llvm-flang"
CXX_STD="17"
SRCDIR="${PWD}"
BUILD_BASE="${SRCDIR}/build"
BUILD_STANDALONE="${SRCDIR}/build-standalone"

# This script should be run from the root of the llvm-project directory.
if [ ! -f "llvm/CMakeLists.txt" ]; then
    echo "This script should be run from the root of the llvm-project directory."
    exit 1
fi

# Check if we need rebuild the base LLVM
if [ "${REBUILD_BASE}" == "rebuild" ]; then
    echo "Rebuilding base LLVM."

    # Check if an old base build exists and erase it.
    if [ -d "${BUILD_BASE}" ]; then
        echo "Old build found. Removing it.."
        rm -rf "${BUILD_BASE}"
    fi

    mkdir -p ${BUILD_BASE}
    cd ${BUILD_BASE}

    # Execute the base build. Using Ninja as default.
    echo "Running cmake..."
    CC="/usr/bin/clang" \
    CXX="/usr/bin/clang++" \
    CFLAGS="-O2" \
    CXXFLAGS="${CFLAGS}" \
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_BASE_PREFIX}" \
        -DCMAKE_CXX_STANDARD="${CXX_STD}" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_BUILD_PARALLEL_LEVEL=64 \
        -DFLANG_ENABLE_WERROR=ON \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DLLVM_TARGETS_TO_BUILD="${TARGETS}" \
        -DLLVM_LIT_ARGS=-v \
        -DLLVM_ENABLE_PROJECTS="${PROJECTS}" \
        -DLLVM_ENABLE_RUNTIMES="${RUNTIMES}" \
        -DLLVM_USE_SPLIT_DWARF=ON \
        -DLLVM_USE_LINKER=lld \
        -DLLVM_OPTIMIZED_TABLEGEN=ON \
        ../llvm > _cmake_log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error running cmake. Check ${BUILD_BASE}/_cmake_log."
        exit 1
    fi

    echo "Building base LLVM..."
    ninja > _ninja_log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error running ninja. Check ${BUILD_BASE}/_ninja_log."
        exit 1
    fi

    echo "Installing base LLVM..."
    ninja install > _ninja_install_log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error running ninja install. Check bui${BUILD_BASE}ld/_ninja_install_log."
        exit 1
    fi

    echo "Base LLVM installed in ${INSTALL_BASE_PREFIX}."
    cd ..
else
    echo "No rebuild. Using base LLVM in ${INSTALL_BASE_PREFIX}."
fi

# Build standalone flang.
echo "Building standalone flang..."
# Check if an old standalone build exists and erase it.
if [ -d "${BUILD_STANDALONE}" ]; then
    echo "Old standalne Flang build found. Removing it.."
    rm -rf "${BUILD_STANDALONE}"
fi

mkdir -p ${BUILD_STANDALONE}
cd ${BUILD_STANDALONE}

# Execute the standalone build. Using Ninja as default.
echo "Running cmake..."
CC="${INSTALL_BASE_PREFIX}/bin/clang" \
CXX="${INSTALL_BASE_PREFIX}/bin/clang++" \
CFLAGS="-g3" \
CXXFLAGS="${CFLAGS}" \
LD="${INSTALL_BASE_PREFIX}/bin/ld.lld" \
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_FLANG_PREFIX}" \
    -DCMAKE_CXX_STANDARD="${CXX_STD}" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DFLANG_ENABLE_WERROR=ON \
    -DLLVM_TARGETS_TO_BUILD="${TARGETS}" \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_BUILD_MAIN_SRC_DIR="${BUILD_BASE}/lib/cmake/llvm" \
    -DLLVM_EXTERNAL_LIT="${BUILD_BASE}/bin/llvm-lit" \
    -DLLVM_LIT_ARGS=-v \
    -DLLVM_DIR="${BUILD_BASE}/lib/cmake/llvm" \
    -DCLANG_DIR="${BUILD_BASE}/lib/cmake/clang" \
    -DMLIR_DIR="${BUILD_BASE}/lib/cmake/mlir" \
    ../flang > _cmake_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running cmake. Check ${BUILD_STANDALONE}/_cmake_log."
    exit 1
fi

echo "Building standalone Flang..."
ninja > _ninja_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja. Check ${BUILD_STANDALONE}/_ninja_log."
    exit 1
fi

echo "Installing standalone Flang..."
ninja install > _ninja_install_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running ninja install. Check ${BUILD_STANDALONE}/_ninja_install_log."
    exit 1
fi

echo "Flang installed in ${INSTALL_FLANG_PREFIX}."

exit 0
