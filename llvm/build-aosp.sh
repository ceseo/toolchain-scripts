#!/bin/bash

# This assumes the script is running at the toplevel directory from the AOSP source.
# The workspace directory has to have:
#       AOSP: the AOSP source
#       scripts: the Linaro wrapper scripts (https://git.linaro.org/toolchain/jenkins-scripts.git/tree/)
#       llvm-install: the custom LLVM installation
#
# Based on the Linaro scripts (https://git.linaro.org/toolchain).

build_AOSP () {
		# Get current clang
	        clang_default=$(grep "ClangDefaultVersion.* = " AOSP/build/soong/cc/config/global.go | sed "s/^.* \"//" | sed "s/\"//")
                clang_path="AOSP/prebuilts/clang/host/linux-x86/${clang_default}"
		echo "Current clang version to be wrapped: ${clang_path}"

	        # Remove old shadow binaries
	        if [ -d "shadow" ]; then
			echo "Old wrapper detected. Removing old shadow binaries..."
			(set +f; rm -rf shadow*)
		fi
		if [ -d "AOSP/out" ]; then
			echo "Previous AOSP build found. Removing..."
			rm -rf AOSP/out
		fi

		# Uninstall old wrapper
		if [ -d "${clang_path}/bin.wrapper" ]; then
			echo "Old wrapper detected: ${clang_path}/bin.wrapper. Removing..."
	        	rm -rf "${clang_path}"/bin.wrapper
                        rm -rf "${clang_path:?}"/bin
		fi
		if [ -d "AOSP/build/soong/scripts.wrapper" ]; then
			echo "Removing old strip.sh..."
			rm -rf AOSP/build/soong/scripts.wrapper
		fi

		# Restore original clang and strip.sh
		if [ -d "${clang_path}/bin.orig" ]; then
			echo "Restoring original ${clang_path}/bin..."
			mv "${clang_path}"/bin.orig "${clang_path}"/bin
		fi
		if [ -d "AOSP/build/soong/scripts.orig" ]; then
			echo "Restoring original strip.sh..."
			mv AOSP/build/soong/scripts.orig/strip.sh AOSP/build/soong/scripts/
			rm -rf AOSP/build/soong/scripts.orig
		fi

		# Install new wrapper
		echo "Installing new wrapper from llvm-install.."
                set -ex
	        ./scripts/wrappers/install-wrappers.sh \
                        $clang_path/bin llvm-install/bin AOSP shadow
                set +ex
		echo "Installing new strip.sh..."
	        ./scripts/wrappers/install-wrappers.sh \
                        AOSP/build/soong/scripts llvm-install/bin AOSP shadow strip.sh
                (
        	    	cd AOSP
                        echo "Starting AOSP build..."
        	    	set -e +ufx +o pipefail
        	    	source build/envsetup.sh
        	    	lunch aosp_oriole-user
	    	        m
                )

}

build_AOSP

