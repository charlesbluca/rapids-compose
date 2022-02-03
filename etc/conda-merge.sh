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
  - debugpy
  - yaml-axis-parser
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

# manually grab dask-sql requirements
wget https://raw.githubusercontent.com/dask-contrib/dask-sql/main/continuous_integration/environment-3.9-jdk11-dev.yaml -O dask-sql.yml

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

replace-env-versions() {
    VER=$(find-env-file-version $1)
    cat "$RAPIDS_HOME/$1/conda/environments/$1_dev_cuda$VER.yml" \
  | sed -r "s/cudatoolkit=$VER/cudatoolkit=$CUDA_TOOLKIT_VERSION/g" \
  | sed -r "s!rapidsai/label/cuda$VER!rapidsai/label/cuda$CUDA_TOOLKIT_VERSION!g" \
  | sed -r "s/- python[<>=,\.0-9]*$/- python=${PYTHON_VERSION}/g"
}

YMLS=()
if [ $(should-build-rmm)       == true ]; then echo -e "$(replace-env-versions rmm)"       > rmm.yml       && YMLS+=(rmm.yml);       fi;
if [ $(should-build-cudf)      == true ]; then echo -e "$(replace-env-versions cudf)"      > cudf.yml      && YMLS+=(cudf.yml);      fi;
if [ $(should-build-cuml)      == true ]; then echo -e "$(replace-env-versions cuml)"      > cuml.yml      && YMLS+=(cuml.yml);      fi;
if [ $(should-build-cugraph)   == true ]; then echo -e "$(replace-env-versions cugraph)"   > cugraph.yml   && YMLS+=(cugraph.yml);   fi;
if [ $(should-build-cuspatial) == true ]; then echo -e "$(replace-env-versions cuspatial)" > cuspatial.yml && YMLS+=(cuspatial.yml); fi;
YMLS+=(dask-sql.yml)
YMLS+=(ucx.yml)
YMLS+=(rapids.yml)
conda-merge ${YMLS[@]} > merged.yml

# Strip out cmake + the rapids packages, and save the combined environment
cat merged.yml \
  | grep -v -P '^(.*?)\-(.*?)(rapids-build-env|rapids-notebook-env|rapids-doc-env|rapids-pytest-benchmark)(.*?)$' \
  | grep -v -P '^(.*?)\-(.*?)(rmm|cudf|dask-cudf|cugraph|cuspatial|cuxfilter|dask-cuda|ucx|ucx-py)(.*?)$' \
  | grep -v -P '^(.*?)\-(.*?)(\.git\@[^(main|master)])(.*?)$' \
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
  - git+https://github.com/rapidsai/jupyterlab-nvdashboard.git
EOF

conda-merge rapids.yml notebooks.yml > merged.yml && mv merged.yml notebooks.yml
