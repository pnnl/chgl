#!/bin/bash

# Clean up from previous run
rm -rf api
rm -rf _build

# Activate the Chapel Python virtualenv for building docs.
# This gets us the sphinx-build, sphinx-rtd-theme, and sphinxcontrib-chapeldomain with the same versions used for the current CHPL_HOME.
pushd $CHPL_HOME/third-party/chpl-venv/install/linux64-x86_64/py2.7/chpl-virtualenv/bin
    . activate
popd

# Build the CHGL chpldoc & move Sphinx output to api/
pushd ..
    mkdir -p docs/_chgl
    chpldoc src/*.chpl --author=PNNL --save-sphinx=docs/_chgl --no-html
    mv docs/_chgl/source docs/api
    sed -i 's/chpldoc documentation/API Documentation/g' docs/api/index.rst
    sed -i '19 s/=/-/g' docs/api/index.rst
    rm -rf docs/_chgl

    mkdir -p docs/_example
    chpldoc example/*.chpl --author=PNNL --save-sphinx=docs/_example --no-html
    mv docs/_example/source docs/example
    sed -i 's/chpldoc documentation/Example Documentation/g' docs/example/index.rst
    sed -i '19 s/=/-/g' docs/example/index.rst
    rm -rf docs/_example
popd

# Build the manually written docs and api/ from CHGL chpldoc
sphinx-build . _build

# Be sure github-pages doesn't try to use Jekyll
touch _build/.nojekyll

# Deactivate the Chapel Python virtualenv
deactivate