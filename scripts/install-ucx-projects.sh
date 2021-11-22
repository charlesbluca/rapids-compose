#!/usr/bin/env bash

set -e

# ucx with IB and NVLINK
cd ~/ucx
git checkout v1.11.1
git clean -xdf
./autogen.sh
mkdir build
cd build
../contrib/configure-release \
--prefix=$CONDA_PREFIX \
--with-cuda=$CUDA_HOME \
--enable-mt \
CPPFLAGS="-I$CUDA_HOME/include"
make -j$PARALLEL_LEVEL install

# ucx-py
cd ~/ucx-py
git clean -xdf
UCXPY_DISABLE_HWLOC=1 pip install -v -e .
