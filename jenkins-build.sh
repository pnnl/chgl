#!/bin/bash

# Build script for puma.pnl.gov

# TODO parameterize vs hard-coded path?
CHAPEL_HOME=/home/zale916/software/chapel/master-source
WORKSPACE=/home/jenkins/chgl-workspace

# Load required modules
module load gcc/7.1.0
module load openmpi/2.1.1

# Initialize Chapel environment
cd $CHAPEL_HOME
source util/setchplenv.sh

# Execute unit tests
#cd $WORKSPACE/test/unit
#start_test -junit-xml -junit-xml-file $WORKSPACE/test/unit/Logs/chapel-unit-tests.xml -numlocales 4

# Execute peformance tests
export CHPL_TEST_PERF_DIR=$WORKSPACE/test/performance/dat
cd $WORKSPACE/test/performance
start_test --performance -junit-xml -junit-xml-file $WORKSPACE/test/performance/Logs/chapel-perf-tests.xml -numlocales 4

# Generated HTML does not work locally or in Jenkins due to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy. Copy files that use local resources instead.
cp -r $WORKSPACE/test/performance/html $WORKSPACE/test/performance/dat