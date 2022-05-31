#!/usr/bin/env bash

set -e

# dask and distributed
cd ~/dask
pip install --no-deps -e . -vv
cd ~/distributed
pip install --no-deps -e . -vv

# dask-sql
cd ~/dask-sql
pip install --no-deps -e . -vv

# dask-cuda
cd ~/dask-cuda
pip install --no-deps -e . -vv
