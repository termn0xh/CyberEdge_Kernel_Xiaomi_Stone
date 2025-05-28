#!/usr/bin/env bash

DEVICE_CODENAME="stone"
DEVICE_NAME="Redmi Note 12 5G/POCO X5 5G"
KERNEL_NAME="CyberEdge"
KERNEL_DEFCONFIG="nethunter_defconfig"
ANYKERNEL_DIR="$PWD/anykernel"
BUILD_TYPE="RELEASE"

NEUTRON_DIR="$PWD/clang-neutron"
function setup_neutron() {
    if [ ! -d "$NEUTRON_DIR" ]; then
        echo "[+] Cloning Neutron Clang..."
        mkdir -p "$NEUTRON_DIR"
        cd "$NEUTRON_DIR" || exit 1
        curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
        chmod +x antman
        ./antman -S >/dev/null 2>&1
        ./antman --patch=glibc >/dev/null 2>&1
        cd ..
    fi
    export PATH="$NEUTRON_DIR/bin:$PATH"
    COMPILER_STRING="$("$NEUTRON_DIR/bin/clang" --version | head -n 1)"
    echo "[+] Compiler: $COMPILER_STRING"
}

echo -n "Include KernelSU? (y/n): "
read -r KERNELSU
[ "$KERNELSU" = "y" ] && {
    KERNEL_VARIANT="-KSU"
    [ ! -d "KernelSU" ] && {
        echo "[+] Downloading KernelSU..."
        curl -LSs "https://raw.githubusercontent.com/SingkoLab/Kernel-Builder/batu/ksu_setup.sh" | bash -
        sed -i "s/CONFIG_KSU=n/CONFIG_KSU=y/g" "arch/arm64/configs/$KERNEL_DEFCONFIG"
    }
}

export ARCH=arm64
export LLVM=1
export LLVM_IAS=1
export KBUILD_BUILD_USER="CyberEdge"
export KBUILD_BUILD_HOST="Brick"

function compile() {
    echo "[+] Building kernel..."
    make O=out "$KERNEL_DEFCONFIG"
    make -j"$(nproc)" O=out \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        STRIP=llvm-strip \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-
}

function package() {
    [ ! -f "out/arch/arm64/boot/Image" ] && {
        echo "❌ Kernel Image missing!"
        exit 1
    }
    echo "[+] Packaging kernel..."
    rm -rf "$ANYKERNEL_DIR/Image" "$ANYKERNEL_DIR/dtbo.img"
    cp "out/arch/arm64/boot/Image" "$ANYKERNEL_DIR/"
    cp "out/arch/arm64/boot/dtbo.img" "$ANYKERNEL_DIR/"
    cd "$ANYKERNEL_DIR" || exit 1
    zip -r9 "../${KERNEL_NAME}-${DEVICE_CODENAME}-$(date '+%Y%m%d')${KERNEL_VARIANT}.zip" * -x .git README.md
}

### --- Main --- ###
setup_neutron
compile
package
echo "[+] Build completed!"
