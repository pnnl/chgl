#!/bin/bash

# Build script for puma.pnl.gov

# TODO parameterize vs hard-coded path?
CHAPEL_HOME=/home/zale916/software/chapel-1.19.0
WORKSPACE=/lustre/jenkins/chgl-workspace

# Load required modules
export MODULEPATH=/home/zale916/software/modules:$MODULEPATH
module load gcc/8.2.0
module load openmpi/3.1.3
module load hdf5/1.10.5
module load zmq/4.3.1
module load chapel/1.19.0

# Execute peformance tests
export CHPL_LAUNCHER_WALLTIME=06:00:00
export GASNET_BACKTRACE=1
export CHPL_TEST_PERF_DIR=$WORKSPACE/test_performance/dat
cd $WORKSPACE/test_performance
rm -rf Logs
bash -c "start_test --performance -junit-xml -junit-xml-file $WORKSPACE/test_performance/Logs/chapel-perf-tests.xml -numlocales 4"

# Generated HTML does not work locally or in Jenkins due to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy. Copy files that use local resources instead.
# disable as we're using GitHub pages
#cp -r $WORKSPACE/test_performance/html $WORKSPACE/test_performance/dat
