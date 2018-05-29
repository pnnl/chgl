#!/bin/bash

export CHPL_TEST_PERF_DIR=workspace/test/performance/dat
cd test/performance
start_test --performance -junit-xml -junit-xml-file workspace/test/performance/Logs/chapel-perf-tests.xml -numlocales 4

# Generated HTML does not work locally or in Jenkins due to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy. Copy files that use local resources instead.
# cp -r ${WORKSPACE}/test/performance/html ${WORKSPACE}/test/performance/dat