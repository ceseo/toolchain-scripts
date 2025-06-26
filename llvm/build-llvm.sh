#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [toolchain] [stage] [build type]"
    echo "Valid toolchain options are: gnu or llvm."
    echo "Valid stage options are: stage1 or stage2."
    echo "Valid (optional) build type options are: Release and Debug."
    echo "  Default build type is Release."
    exit 1
fi

CHECK_SRC=`grep "The LLVM Compiler Infrastructure" README.md 2>/dev/null`
if [ -z "${CHECK_SRC}" ]; then
    echo "Not in the llvm-project tree base."
    exit 1
fi

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

# Check toolchain
BUILDTC="$1"
GNUTC="${HOME}/.local/gnu-latest/bin"		# Change to desired gcc path.
LLVMTC="${HOME}/.local/llvm-latest/bin"		# Change to desired clang path.
if [ "${BUILDTC}" = "llvm" ]; then
    BUILDDIR="build"
    TCPATH="${LLVMTC}"
    CC="${TCPATH}/clang"
    CXX="${TCPATH}/clang++"
	# Xcode default toolchain doesn't include lld
	if [ "${OS}" = "Darwin" ]; then
		LD="${TCPATH}/ld"
		LLVM_ENABLE_LLD="OFF"
	else
		LD="${TCPATH}/ld.lld"
		LLVM_ENABLE_LLD="ON"
	fi
elif [ "${BUILDTC}" = "gnu" ]; then
	if [ "${OS}" = "Darwin" ]; then
		echo "gcc is not supported in macOS. Exiting."
		exit 1
	fi
    BUILDDIR="build-gnu"
    TCPATH="${GNUTC}"
    TRIPLE="aarch64-linux-gnu"
    CC="${TCPATH}/${TRIPLE}-gcc"
    CXX="${TCPATH}/${TRIPLE}-g++"
    LD="${TCPATH}/${TRIPLE}-ld"
    LLVM_ENABLE_LLD="OFF"
else
    echo "Invalid toolchain option."
    exit 1
fi

# Check if it's a stage2 build
STAGE="$2"
ENABLE_BOOTSTRAP="Off"
NINJA="ninja"
if [ "${STAGE}" = "stage2" ]; then
    ENABLE_BOOTSTRAP="On"
    NINJA="ninja stage2"
fi

# Check build type
if [ -z "$3" ]; then
	BUILD_TYPE="Release"
else
	BUILD_TYPE="$3"
fi

TARGETS="AArch64"
PROJECTS="lld;mlir;clang;flang;llvm;clang-tools-extra"
RUNTIMES="compiler-rt;flang-rt;openmp"
INSTALL_PREFIX="${HOME}/.local/llvm-head"	# Change to desired installation path.
CXX_STD="17"

# Set test targets here
TEST_TARGETS=""
declare -a TEST_TARGETS=("clang" "compiler-rt" "mlir" "lld")

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
CFLAGS="-g3 -I/usr/include"
CXXFLAGS="${CFLAGS}"

mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

# Execute the build. Using Ninja as default.
ENABLE_CCACHE="`which ccache`"
if [ ! -z "${ENABLE_CCACHE}" ]; then
	ENABLE_CCACHE="-DCMAKE_C_COMPILER_LAUNCHER=ccache"
	ENABLE_CCACHEXX="-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
fi
MAKEOPTS="-j12"	# Set desired parallelism.
echo "--------------------------------------------------"
echo "Starting llvm build..."
echo "--------------------------------------------------"
echo "Build type: ${BUILD_TYPE}"
echo "Build stages: ${STAGE}"
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
      -DLLVM_ENABLE_LLD="${LLVM_ENABLE_LLD}" \
      -DLLVM_LIT_ARGS="-v --xunit-xml-output test-results.xml" \
      -DLLVM_BUILD_EXAMPLES=ON \
      -DFLANG_ENABLE_WERROR=ON \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DBUILD_SHARED_LIBS=ON \
      -DBOLT_CLANG_EXE="${CC}" \
	  "${ENABLE_CCACHE}" \
	  "${ENABLE_CCACHEXX}" \
      "${ENABLE_BOOTSTRAP}" \
      ../llvm > _cmake_log 2>&1
if [ $? -ne 0 ]; then
    echo "Error running cmake. Check ${BUILDDIR}/_cmake_log."
    exit 1
fi

echo "Building..."
ninja "${MAKEOPTS}" > _ninja_log 2>&1
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

if [ ! -z "${TEST_TARGETS}" ]; then
	echo "Testing..."
	for i in "${TEST_TARGETS[@]}"; do
	    echo "Running check-${i}..."
	    ninja check-${i} > _check_${i}_log 2>&1
	    if [ $? -ne 0 ]; then
	        echo "Error running check-${i} tests. Check ${BUILDDIR}/_check_${i}_log for more information."
	        exit 1
	    fi
	done
fi

exit 0
