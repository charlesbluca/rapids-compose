#!/usr/bin/env bash

set -e

# dask and distributed
cd ~/dask
pip install -e .
cd ~/distributed
pip install -e .

# dask-sql
cd ~/dask-sql
pip install -e ".[dev]"
python setup.py java

# dask-cuda
cd ~/dask-cuda
pip install -e .
