#!/bin/sh

EXT=0
LDR_MAKE="nx_release"
NO_EXO=0

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIST_DIR="$ROOT_DIR/dist"

while [ $# -gt 0 ]; do
    case "$1" in
        --ext)
            EXT=1
            ;;
        --ldr=*)
            LDR_MAKE="${1#*=}"
            ;;
        --no-exo)
            NO_EXO=1
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

LDR_BUILD_PATH="${LDR_MAKE#nx_}"

echo
if [ "$EXT" -eq 1 ]; then
    echo "EXT = 1"
fi

if [ "$NO_EXO" -eq 1 ]; then
    echo "No_EXO = 1"
fi

CORES="$(nproc --all)"
echo "CORES: $CORES"

SRC="Source/Atmosphere/stratosphere/loader/"
DEST="build/stratosphere/loader/"
mkdir -p "dist/atmosphere/kips/"
mkdir -p "$DEST"

echo
echo "*** Patching loader ***"
cp -vr "$SRC"/. "$DEST"/
echo

if [ "$NO_EXO" -eq 0 ]; then
    echo "*** Patching exosphere ***"
    EXO_SRC="Source/Atmosphere-Patches"
    EXO_DEST="build/exosphere/program/source/smc"
    LIBEXO_DEST="build/libraries/libexosphere/include/exosphere/secmon"

    cp -v "$EXO_SRC/secmon_emc_access_table_data.inc"       "$EXO_DEST/"
    cp -v "$EXO_SRC/secmon_define_emc_access_table.inc"     "$EXO_DEST/"
    cp -v "$EXO_SRC/secmon_rtc_pmc_access_table_data.inc"   "$EXO_DEST/"
    cp -v "$EXO_SRC/secmon_define_rtc_pmc_access_table.inc" "$EXO_DEST/"
    cp -v "$EXO_SRC/secmon_smc_register_access.cpp"         "$EXO_DEST/"
    cp -v "$EXO_SRC/secmon_smc_handler.cpp"                 "$EXO_DEST/"
    cp -v "$EXO_SRC/secmon_memory_layout.hpp"               "$LIBEXO_DEST/"
    echo
fi

echo
echo "*** Compiling loader ***"
cd build/stratosphere/loader || exit 1
make -j$CORES "$LDR_MAKE"
hactool -t kip1 "out/nintendo_nx_arm64_armv8a/$LDR_BUILD_PATH/loader.kip" --uncompress=hoc.kip
cd ../../../ # exit
cp -v build/stratosphere/loader/hoc.kip dist/atmosphere/kips/hoc.kip

if [ "$NO_EXO" -eq 0 ]; then
    echo
    echo "*** Compiling exosphere ***"
    cd build/exosphere
    make -j$CORES
    cd ../../
    cp -v build/exosphere/out/nintendo_nx_arm64_armv8a/release/exosphere.bin dist/atmosphere/exosphere.bin
fi

cd Source/hoc-clk/
./build.sh
cp -r dist/ ../../

cd ../../

echo "*** Compiling horizon-oc-monitor ***"
cd Source/Horizon-OC-Monitor/
make -j$CORES
cp -v Horizon-OC-Monitor.ovl ../../dist/switch/.overlays/Horizon-OC-Monitor.ovl

if [ "$EXT" -eq 1 ]; then
    cd ../
    echo
    echo "*** Extensions enabled ***"

    REPO_DIR="hekate"
    REPO_URL="https://github.com/Horizon-OC/hekate.git"

    if [ ! -d "$REPO_DIR" ]; then
        echo
        echo "*** Cloning custom Hekate ***"
        git clone "$REPO_URL" "$REPO_DIR"
    fi

    cd hekate/
    echo
    echo "*** Compiling custom Hekate ***"
    make -j$CORES
    echo

    mkdir -p "$DIST_DIR/bootloader/sys/"
    cp -v output/nyx.bin ../../dist/bootloader/sys/nyx.bin
fi

echo
echo "*** Packaging dist.zip ***"

cd "$DIST_DIR" || exit 1

rm -f dist.zip

zip -r dist.zip . >/dev/null

echo "*** dist.zip created ***"

cd "$ROOT_DIR" || exit 1
