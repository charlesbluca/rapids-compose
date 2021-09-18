#!/usr/bin/env bash

set -e

# ucx with IB and NVLINK
cd ~/ucx
git checkout v1.11.1
./autogen.sh
rm -rf build/
mkdir build
cd build
../contrib/configure-release \
--prefix=$CONDA_PREFIX \
--with-cuda=$CUDA_HOME \
--enable-mt \
CPPFLAGS="-I$CUDA_HOME/include"
make -j install

# ucx-py
cd ~/ucx-py
python setup.py build_ext --inplace
pip install -v -e .
