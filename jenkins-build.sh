#!/bin/bash

# Build script for puma.pnl.gov

# TODO parameterize vs hard-coded path?
WORKSPACE=/lustre/jenkins/chgl-workspace

# Load required modules
export MODULEPATH=/home/zale916/software/modules:$MODULEPATH
module load gcc/8.2.0
module load openmpi/3.1.3
module load hdf5/1.10.5
module load zmq/4.3.1
module load chapel/1.19.0

# Execute peformance tests
export CHPL_TEST_LAUNCHCMD=$CHPL_HOME/util/test/chpl_launchcmd.py
export CHPL_LAUNCHER_WALLTIME=06:00:00
export CHPL_TEST_TIMEOUT=3600
export GASNET_BACKTRACE=1
export CHPL_TEST_PERF_DIR=$WORKSPACE/test_performance/dat
cd $WORKSPACE/test_performance
rm -rf Logs
start_test --performance -junit-xml -junit-xml-file $WORKSPACE/test_performance/Logs/chapel-perf-tests.xml --test-root=$WORKSPACE/test_performance/ -numlocales 4

# Replace Chapel references with CHGL
sed -i 's/Chapel Performance Graphs/CHGL Performance Graphs/g' $CHPL_TEST_PERF_DIR/html/index.html
sed -i 's/Chapel Performance Graphs/CHGL Performance Graphs/g' $CHPL_TEST_PERF_DIR/html/graphdata.js
sed -i 's|http://chapel-lang.org/perf/|https://pnnl.github.io/chgl/|g' $CHPL_TEST_PERF_DIR/html/index.html
