#!/bin/bash

# Build all the targets for SPEC CPU 2017 (intrate, intspeed, fprate, fpspeed) in parallel.

# The config file must be in SPEC_DIR/config.
SPEC_DIR="<insert SPEC CPU 2017 installation dir here>"
SPEC_CONFIG="<insert SPEC CPU 2017 config file here>"

if [ ! -d "$SPEC_DIR" ]; then
    echo "SPEC directory not found. Please check the path."
    exit 1
fi

if [ ! -f "$SPEC_DIR/config/$SPEC_CONFIG" ]; then
    echo "SPEC config file not found. Please check the path."
    exit 1
fi

# Check if old logs exist and erase them.
if [ -f "$SPEC_DIR/_build" ]; then
    echo "Old build logs found. Removing them..."
    rm "$SPEC_DIR/_build" "$SPEC_DIR/_intrate_build" "$SPEC_DIR/_intspeed_build" "$SPEC_DIR/_fprate_build" "$SPEC_DIR/_fpspeed_build"
fi

# Call SPEC build for each target in a parallel shell. Wait until all the builds to finish before continuing.
for target in intrate intspeed fprate fpspeed; do
    echo "Building $target..."
    cd "$SPEC_DIR" || exit
    ./bin/runcpu -a build --config "$SPEC_CONFIG" "$target" > "$SPEC_DIR"/_${target}_build &
done

while [ $(jobs | grep -c "Running") -gt 0 ]; do
    sleep 1
done

echo "All builds finished."

# Consolidate the build logs.
cat "$SPEC_DIR/_intrate_build" "$SPEC_DIR/_intspeed_build" "$SPEC_DIR/_fprate_build" "$SPEC_DIR/_fpspeed_build" > "$SPEC_DIR/_build"
echo "Individual build logs are in $SPEC_DIR/_<target>_build."
echo "Consolidated build log is in $SPEC_DIR/_build."

exit 0
