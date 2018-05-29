#!/bin/bash

# TODO parameterize vs hard-coded path?
CHAPEL_HOME=/home/zale916/software/chapel/master-source
WORKSPACE=/home/jenkins/chgl-workspace

# Initialize Chapel environment
cd $CHAPEL_HOME
source util/quickstart/setchplenv.bash

# Execute peformance tests
export CHPL_TEST_PERF_DIR=$WORKSPACE/test/performance/dat
cd $WORKSPACE/test/performance
start_test --performance -junit-xml -junit-xml-file $WORKSPACE/test/performance/Logs/chapel-perf-tests.xml -numlocales 4

# Generated HTML does not work locally or in Jenkins due to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy. Copy files that use local resources instead.
cp -r $WORKSPACE/test/performance/html $WORKSPACE/test/performance/dat