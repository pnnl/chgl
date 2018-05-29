#!/bin/bash

# TODO parameterize Chapel install on puma.pnl.gov vs hard-coded path?
cd /home/zale916/software/chapel/master-source
source util/quickstart/setchplenv.bash

# Execute peformance tests
export CHPL_TEST_PERF_DIR=/home/jenkins/chgl-workspace/test/performance/dat
cd /home/jenkins/chgl-workspace/test/performance
start_test --performance -junit-xml -junit-xml-file /home/jenkins/chgl-workspace/test/performance/Logs/chapel-perf-tests.xml -numlocales 4

# Generated HTML does not work locally or in Jenkins due to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy. Copy files that use local resources instead.
# cp -r ${WORKSPACE}/test/performance/html ${WORKSPACE}/test/performance/dat