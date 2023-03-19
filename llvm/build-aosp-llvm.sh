#!/bin/bash

# Build LLVM for Android. The workspace directory has to have:
#       llvm-toolchain: the Android LLVM source.
#       llvm-install: the custom LLVM installation dir.
#       llvm: the vanilla LLVM source.
#
#  Based on the Linaro scripts (https://git.linaro.org/toolchain).

# Build LLVM
build_shadow_llvm ()
{
    (

    cd llvm-toolchain

    local cc cxx ninja
    cc=$(cat out/stage2/cmake_invocation.sh \
	     | grep -e " -DCMAKE_C_COMPILER=" \
	     | sed -e "s/.* -DCMAKE_C_COMPILER=\([^ ]*\).*/\1/")
    cxx=$(cat out/stage2/cmake_invocation.sh \
	      | grep -e " -DCMAKE_CXX_COMPILER=" \
	      | sed -e "s/.* -DCMAKE_CXX_COMPILER=\([^ ]*\).*/\1/")
    ninja=$(cat out/stage2/cmake_invocation.sh \
	      | grep -e " -DCMAKE_MAKE_PROGRAM=" \
	      | sed -e "s/.* -DCMAKE_MAKE_PROGRAM=\([^ ]*\).*/\1/")
    cd ..

    local workspace
    workspace=$(pwd)

    # ${workspace:?}/bin is to avoid shellcheck warning that below never
    # expands to "rm -rf /bin"
    rm -rf "${workspace:?}/bin"
    mkdir "$workspace/bin"

    cat > "$workspace/bin/cc" <<EOF
#!/bin/sh
CCACHE_BASEDIR=$workspace exec ccache $cc "\$@"
EOF
    chmod +x "$workspace/bin/cc"

    cat > "$workspace/bin/c++" <<EOF
#!/bin/sh
CCACHE_BASEDIR=$workspace exec ccache $cxx "\$@"
EOF
    chmod +x "$workspace/bin/c++"

    rm -rf llvm-install

    cd llvm-toolchain/out

    cp stage2/cmake_invocation.sh ./


    sed -i \
	-e "s#/llvm-toolchain/out/llvm-project/llvm #/llvm/llvm #" \
	-e "s#/llvm-toolchain/out/stage2-install #/llvm-install #" \
	-e "s# -DCMAKE_C_COMPILER=[^ ]* # -DCMAKE_C_COMPILER=$workspace/bin/cc #" \
	-e "s# -DCMAKE_CXX_COMPILER=[^ ]* # -DCMAKE_CXX_COMPILER=$workspace/bin/c++ #" \
	cmake_invocation.sh

    ccache -z

    rm -rf stage3
    mkdir stage3
    cd stage3

    set +e
    source ../cmake_invocation.sh
    local res=$?
    set -e
    if [ $res != 0 ] || ! $ninja; then
	# Attempt to workaround failures in past LLVM versions.
	cd ..

	# Workaround failures to find BOLT, which seems to be unused anyway.
	sed -i -e "s/bolt;//" cmake_invocation.sh

	# Workaround failure to link x86_64's libc++.so against non-PIC
	# libc++abi.a.  Add -fPIC to x86_64 runtime's CFLAGS.
	sed -i -e "s/ '-DRUNTIMES_x86_64-unknown-linux-gnu_CMAKE_C_FLAGS=/ '-DRUNTIMES_x86_64-unknown-linux-gnu_CMAKE_C_FLAGS=-fPIC /g" \
	    cmake_invocation.sh
	sed -i -e "s/ '-DRUNTIMES_x86_64-unknown-linux-gnu_CMAKE_CXX_FLAGS=/ '-DRUNTIMES_x86_64-unknown-linux-gnu_CMAKE_CXX_FLAGS=-fPIC /g" \
	    cmake_invocation.sh

	rm -rf stage3
	mkdir stage3
	cd stage3
	source ../cmake_invocation.sh
	$ninja
    fi
    $ninja install

    ccache -s
    )
}

build_shadow_llvm