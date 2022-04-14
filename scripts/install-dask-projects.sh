#!/usr/bin/env bash

set -e

# dask and distributed
cd ~/dask
pip install --no-deps -e .
cd ~/distributed
pip install --no-deps -e .

# dask-sql
cd ~/dask-sql
pip install --no-deps -e .

# dask-cuda
cd ~/dask-cuda
pip install --no-deps -e .
