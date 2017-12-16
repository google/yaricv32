#!/bin/bash
git clone --recurse-submodules -b v20171107 --single-branch https://github.com/riscv/riscv-gnu-toolchain riscv-toolchain-repo
mkdir riscv-toolchain-repo/build
cd riscv-toolchain-repo/build/
../configure  --with-arch=rv32i --prefix=$(pwd)/../../riscv-toolchain
make -j$(nproc)
cd ../..
rm -rf riscv-toolchain-repo/
