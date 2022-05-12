#!/bin/bash
#
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2021 Adithya R.

# Setup getopt.
long_opts="regen,clean"
getopt_cmd=$(getopt -o rcsh:t: --long "$long_opts" \
            -n $(basename $0) -- "$@") || \
            { echo -e "\nError: Getopt failed. Extra args\n"; exit 1;}

eval set -- "$getopt_cmd"

while true; do
    case "$1" in
        -r|--regen|r|regen) FLAG_REGEN_DEFCONFIG=y;;
        -c|--clean|c|clean) FLAG_CLEAN_BUILD=y;;
        -o|--outdir|o|outdir) OUT_DIR="$2"; shift;;
        --) shift; break;;
    esac
    shift
done

TC_DIR="$HOME/tc/proton-clang"

# Setup OUT dir
if [ $OUT_DIR ]; then
    OUT_DIR=$OUT_DIR
else
    OUT_DIR=out
fi
echo -e "Out directory is at $OUT_DIR\n"

export KBUILD_BUILD_USER=leddaz
export KBUILD_BUILD_HOST=godopoli
export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
	echo "Proton clang not found! Cloning to $TC_DIR..."
	if ! git clone -q --depth=1 --single-branch https://github.com/kdrag0n/proton-clang "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

SECONDS=0 # builtin bash timer
ZIPNAME="LagoDuria-miatoll-$(date '+%Y%m%d-%H%M').zip"
if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
        ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi
DEFCONFIG="vendor/miatoll-perf_defconfig"

export PATH="$TC_DIR/bin:$PATH"

# Prep for a clean build, if requested so
if [ "$FLAG_CLEAN_BUILD" = 'y' ]; then
	echo -e "\nCleaning output folder..."
	rm -rf $OUT_DIR
fi

# Regenerate defconfig, if requested so
if [ "$FLAG_REGEN_DEFCONFIG" = 'y' ]; then
	make O=$OUT_DIR ARCH=arm64 $DEFCONFIG savedefconfig
	cp $OUT_DIR/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit 1
fi

mkdir -p $OUT_DIR
make O=$OUT_DIR ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j"$(nproc --all)" O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image dtbo.img

if [ -f "$OUT_DIR/arch/arm64/boot/Image" ] && [ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if ! git clone -q https://github.com/LeddaZ/AnyKernel3 -b miatoll; then
		echo -e "\nCloning AnyKernel3 repo failed! Aborting..."
		exit 1
	fi
	cp $OUT_DIR/arch/arm64/boot/Image AnyKernel3
	cp $OUT_DIR/arch/arm64/boot/dtbo.img AnyKernel3
	cp $OUT_DIR/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb AnyKernel3/dtb
	rm -f ./*zip
	cd AnyKernel3 || exit
	rm -rf $OUT_DIR/arch/arm64/boot
	zip -r9 "../$ZIPNAME" ./* -x '*.git*' README.md ./*placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
	curl -F "file=@${ZIPNAME}" https://oshi.at
	echo
else
	echo -e "\nCompilation failed!"
fi
