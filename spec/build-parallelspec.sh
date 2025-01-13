#!/bin/bash

# Build all the targets for SPEC CPU 2017 (intrate, intspeed, fprate, fpspeed) in parallel.
# Optionally, run the benchmarks

if [ "$#" = "--help" ]; then
    echo "Usage: $0 --OPTION"
    echo "Valid options are:"
    echo "--run : Run the benchmarks."
    echo "--help : This message."
    exit 1
fi

# The config file must be in SPEC_DIR/config.
SPEC_DIR="<insert spec installation dir>"
SPEC_CONFIG="<insert config file>"

if [ ! -d "$SPEC_DIR" ]; then
    echo "SPEC directory not found. Please check the path."
    exit 1
fi

if [ ! -f "$SPEC_DIR/config/$SPEC_CONFIG" ]; then
    echo "SPEC config file not found. Please check the path."
    exit 1
fi

# Create logs dir
if [ ! -d "${SPEC_DIR}/logs" ]; then
        mkdir -p "${SPEC_DIR}/logs"
fi

# Check if old build logs exist and erase them.
BUILD_LOGS="${SPEC_DIR}/logs/build"
if [ -d "${BUILD_LOGS}" ]; then
    echo "Old build logs found. Removing them..."
    rm -rf "${BUILD_LOGS}"
fi
mkdir -p "${BUILD_LOGS}"

# Create build logs dir


# Call SPEC build for each target in a parallel shell. Wait until all the builds to finish before continuing.
# 
# Targets: intrate, intspeed, fprate, fpspeed, or any of the benchmarks below.
# 
# SPECrate®2017         SPECspeed®2017          Language[1]     KLOC[2]         Application Area
# Integer               Integer
#         
# 500.perlbench_r       600.perlbench_s         C               362             Perl interpreter
# 502.gcc_r             602.gcc_s               C               1,304           GNU C compiler
# 505.mcf_r             605.mcf_s               C               3               Route planning
# 520.omnetpp_r         620.omnetpp_s           C++             134             Discrete Event simulation - computer network
# 523.xalancbmk_r       623.xalancbmk_s         C++             520             XML to HTML conversion via XSLT
# 525.x264_r            625.x264_s              C               96              Video compression
# 531.deepsjeng_r       631.deepsjeng_s         C++             10              Artificial Intelligence: alpha-beta tree search (Chess)
# 541.leela_r           641.leela_s             C++             21              Artificial Intelligence: Monte Carlo tree search (Go)
# 548.exchange2_r       648.exchange2_s         Fortran         1               Artificial Intelligence: recursive solution generator (Sudoku)
# 557.xz_r              657.xz_s                C               33              General data compression
#
# SPECrate®2017         SPECspeed®2017          Language[1]     KLOC[2]         Application Area
# Floating Point        Floating Point        
#         
# 503.bwaves_r          603.bwaves_s            Fortran         1               Explosion modeling
# 507.cactuBSSN_r       607.cactuBSSN_s         C++, C, Fortran 257             Physics: relativity
# 508.namd_r                                    C++             8               Molecular dynamics
# 510.parest_r                                  C++             427             Biomedical imaging: optical tomography with finite elements
# 511.povray_r                                  C++, C          170             Ray tracing
# 519.lbm_r             619.lbm_s               C               1               Fluid dynamics
# 521.wrf_r             621.wrf_s               Fortran, C      991             Weather forecasting
# 526.blender_r                                 C++, C          1,577           3D rendering and animation
# 527.cam4_r            627.cam4_s              Fortran, C      407             Atmosphere modeling
#                       628.pop2_s              Fortran, C      338             Wide-scale ocean modeling (climate level)
# 538.imagick_r         638.imagick_s           C               259             Image manipulation
# 544.nab_r             644.nab_s               C               24              Molecular dynamics
# 549.fotonik3d_r       649.fotonik3d_s         Fortran         14              Computational Electromagnetics
# 554.roms_r            654.roms_s              Fortran         210             Regional ocean modeling
# 
# [1] For multi-language benchmarks, the first one listed determines library and link options
# [2] KLOC = line count (including comments/whitespace) for source files used in a build / 1000

TARGET_LIST="648_exchange_s 603.bwaves_s 607.cactuBSSN_s 621.wrf_s 627.cam4_s 628.pop2_s 649.fotonik3d_s 654.roms_s"

for target in $TARGET_LIST; do
    echo "Building $target..."
    cd "$SPEC_DIR" || exit
    ./bin/runcpu -a build --config "$SPEC_CONFIG" "$target" > "${BUILD_LOGS}"/_build_"${target}" &
done

while [ $(jobs | grep -c "Running") -gt 0 ]; do
    sleep 1
done

echo "All builds finished."

# Consolidate the build logs.
cat "${BUILD_LOGS}"/_build_* > "${BUILD_LOGS}"/_consolidated_build
echo "Individual build logs are in ${BUILD_LOGS}/_build_<target>."
echo "Consolidated build log is in ${BUILD_LOGS}/_consolidated_build."

if [ "$#" -gt 0 ]; then
        if [ "$1" = "--run" ]; then
                # Check if old logs exist and erase them.
                RUN_LOGS="${SPEC_DIR}/logs/run"
                if [ -d "${RUN_LOGS}" ]; then
                    echo "Old run logs found. Removing them..."
                    rm -rf "${RUN_LOGS}"
                fi
                mkdir -p "${RUN_LOGS}"
                echo "Running benchmarks now."
                for target in $TARGET_LIST; do
                    echo "Running $target..."
                    cd "$SPEC_DIR"
                    ./bin/runcpu -a run --config "$SPEC_CONFIG" "$target" > "${RUN_LOGS}"/_run_"${target}"
                done
                # Consolidate the run logs.
                cat "${RUN_LOGS}"/_run_* > "${RUN_LOGS}"/_consolidated_run
                echo "Individual build logs are in ${RUN_LOGS}/_run_<target>."
                echo "Consolidated build log is in ${RUN_LOGS}/_consolidated_run."
        fi
fi

exit 0
