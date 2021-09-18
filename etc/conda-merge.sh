#!/usr/bin/env bash

set -Eeo pipefail

cd "$RAPIDS_HOME"

####
# Merge the rapids projects' envs into one rapids.yml environment file
####
cat << EOF > rapids.yml
name: rapids
channels:
- rapidsai
- nvidia
- rapidsai-nightly
- conda-forge
dependencies:
- cmake>=3.20
- cmake_setuptools
- pynvml
- pytest-xdist
- python=${PYTHON_VERSION}
- pip:
  - ptvsd
EOF

# UCX source requirements
cat << EOF > ucx.yml
name: ucx
channels:
- conda-forge
dependencies:
- automake
- make
- libtool
- pkg-config
- psutil
- setuptools
- cython>=0.29.14,<3.0.0a0
EOF

# workaround until https://github.com/dask-contrib/dask-sql/pull/238 is merged
cat << EOF > dask-sql.yml
name: dask-sql
channels:
- conda-forge
dependencies:
- adagio>=0.2.3
- antlr4-python3-runtime>=4.9.2
- black=19.10b0
- ciso8601>=2.2.0
- dask-ml>=1.7.0
- dask>=2.19.0,!=2021.3.0  # dask 2021.3.0 makes dask-ml fail (see https://github.com/dask/dask-ml/issues/803)
- fastapi>=0.61.1
- fs>=2.4.11
- intake>=0.6.0
- isort=5.7.0
- jpype1>=1.0.2
- lightgbm>=3.2.1
- maven>=3.6.0
- mlflow>=1.19.0
- mock>=4.0.3
- nest-asyncio>=1.4.3
- openjdk>=8
- pandas>=1.0.0  # below 1.0, there were no nullable ext. types
- pip=20.2.4
- pre-commit>=2.11.1
- prompt_toolkit>=3.0.8
- psycopg2>=2.9.1
- pyarrow>=0.15.1
- pygments>=2.7.1
- pyhive>=0.6.4
- pytest-cov>=2.10.1
- pytest-xdist
- pytest>=6.0.1
- python=3.8
- scikit-learn>=0.24.2
- sphinx>=3.2.1
- tpot>=0.11.7
- triad>=0.5.4
- tzlocal>=2.1
- uvicorn>=0.11.3
- pip:
  - fugue[sql]>=0.5.3
EOF


CUDA_TOOLKIT_VERSION=${CONDA_CUDA_TOOLKIT_VERSION:-$CUDA_SHORT_VERSION};

find-env-file-version() {
    ENVS_DIR="$RAPIDS_HOME/$1/conda/environments"
    for YML in $ENVS_DIR/${1}_dev_cuda*.yml; do
        YML="${YML#$ENVS_DIR/$1}"
        YML="${YML#_dev_cuda}"
        echo "${YML%*.yml}"
        break;
    done
}

replace-env-cuda-toolkit-version() {
    VER=$(find-env-file-version $1)
    cat "$RAPIDS_HOME/$1/conda/environments/$1_dev_cuda$VER.yml" \
  | sed -r "s/cudatoolkit=$VER/cudatoolkit=$CUDA_TOOLKIT_VERSION/g" \
  | sed -r "s!rapidsai/label/cuda$VER!rapidsai/label/cuda$CUDA_TOOLKIT_VERSION!g"
}

YMLS=()
if [ $(should-build-rmm)       == true ]; then echo -e "$(replace-env-cuda-toolkit-version rmm)"       > rmm.yml       && YMLS+=(rmm.yml);       fi;
if [ $(should-build-cudf)      == true ]; then echo -e "$(replace-env-cuda-toolkit-version cudf)"      > cudf.yml      && YMLS+=(cudf.yml);      fi;
if [ $(should-build-cuml)      == true ]; then echo -e "$(replace-env-cuda-toolkit-version cuml)"      > cuml.yml      && YMLS+=(cuml.yml);      fi;
if [ $(should-build-cugraph)   == true ]; then echo -e "$(replace-env-cuda-toolkit-version cugraph)"   > cugraph.yml   && YMLS+=(cugraph.yml);   fi;
if [ $(should-build-cuspatial) == true ]; then echo -e "$(replace-env-cuda-toolkit-version cuspatial)" > cuspatial.yml && YMLS+=(cuspatial.yml); fi;
YMLS+=(dask-sql.yml)  # workaround until https://github.com/dask-contrib/dask-sql/pull/238 is merged
YMLS+=(ucx.yml)
YMLS+=(rapids.yml)
conda-merge ${YMLS[@]} > merged.yml

# Strip out cmake + the rapids packages, and save the combined environment
cat merged.yml \
  | grep -v -P '^(.*?)\-(.*?)(rapids-build-env|rapids-notebook-env|rapids-doc-env|rapids-pytest-benchmark)(.*?)$' \
  | grep -v -P '^(.*?)\-(.*?)(rmm|cudf|dask-cudf|cugraph|cuspatial|cuxfilter|dask-cuda|ucx|ucx-py)(.*?)$' \
  | grep -v -P '^(.*?)\-(.*?)(cmake=)(.*?)$' \
  | grep -v -P '^(.*?)\-(.*?)(defaults)(.*?)$' \
  | grep -v -P '^(.*?)\-(.*?)(isort=5.7.0)(.*?)$' \
  > rapids.yml

####
# Merge the rapids env with this hard-coded one here for notebooks
# env since the notebooks repos don't include theirs in the github repo
# Pulled from https://github.com/rapidsai/build/blob/d2acf98d0f069d3dad6f0e2e4b33d5e6dcda80df/generatedDockerfiles/Dockerfile.ubuntu-runtime#L45
####
cat << EOF > notebooks.yml
name: notebooks
channels:
- rapidsai
- nvidia
- rapidsai-nightly
# - numba
- conda-forge
dependencies:
- bokeh
- dask-labextension
- dask-ml
- ipython
# - ipython=${IPYTHON_VERSION:-"7.3.0"}
- ipywidgets
- jupyterlab
# - jupyterlab=1.0.9
- matplotlib
- networkx
- nodejs
- scikit-learn
- scipy
- seaborn
# - tensorflow
- umap-learn
- pip:
  - graphistry
  - git+https://github.com/jacobtomlinson/jupyterlab-nvdashboard.git
EOF

conda-merge rapids.yml notebooks.yml > merged.yml && mv merged.yml notebooks.yml
