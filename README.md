Table of Contents
=================

*   [Project Overview](#project-overview)
    *   [Detailed Summary](#detailed-summary)
*   [Installation Guide](#installation-guide)
    *   [Environment Requirements](#environment-requirements)
    *   [Dependencies](#dependencies)
    *   [Distribution Files](#distrubution-files)
    *   [Installation Instructions](#installation-instructions)
    *   [Test Cases](#test-cases)
*   [User Guide](#user-guide)

Project Overview
================

**Project Name:** Chapel Hypergraph Library (CHGL)

**General Area or Topic of Investigation:** High performance, parallel hypergraph metrics and algorithms

**Travis CI Build Status:** [![Build Status](https://travis-ci.org/pnnl/chgl.svg?branch=master)](https://travis-ci.org/pnnl/chgl)

Detailed Summary
----------------

**C**hapel **H**per**g**raph **L**ibrary (CHGL), a library
for hypergraph computation in the emerging Chapel language.  Hypergraphs
generalize graphs, where a hypergraph edge can connect any number of vertices.
Thus, hypergraphs capture high-order, high-dimensional interactions between
multiple entities that are not directly expressible in graphs.  CHGL is designed
to provide HPC-class computation with high-level abstractions and modern
language support for parallel computing on shared memory and distributed memory
systems.

Environment Requirements
------------------------

**Programming Language:** Chapel 1.18 pre-release (master branch as of 7/25/2018)

**Operating System & Version:** Tested on Chapel Docker containers (Debian) and internal RHEL 7 system

**Required Disk Space:** Approx. 40mb for code repository and binaries

Dependencies
------------

A compiled version of the Chapel programming language with is test virtual environment is all that is required to compile and test CHGL. Unit tests were run on the GitLab-CI continuous integration system using Chapel's Docker container (see included ``.gitlab-ci.yml`` file for details).

| Name | Version | Download Location | Country of Origin | Special Instructions |
| ---- | ------- | ----------------- | ----------------- | -------------------- |
| Chapel | 1.18 pre-release | https://github.com/chapel-lang/chapel | USA | None |  

Distribution Files
------------------

CHGL is released through a GitHub repository found at https://github.com/pnnl/chgl. No additional files are required. 

Installation Instructions
-------------------------

CHGL can be compiled by first installing Chapel 
(see https://chapel-lang.org/docs/usingchapel/QUICKSTART.html) or using a Chapel 
Docker image (see https://hub.docker.com/r/chapel/chapel/). Note however that 
CHGL uses features found in the Chapel 1.18 pre-release and these features are 
currently unavailable in Docker images. Once a 1.18 release is made, Docker 
images can be used.

In the future, CHGL will be compiled and packaged into a Mason library. For the 
time being, CHGL is used directly (see unit tests for examples). The code is 
compiled and tested simultaneously -- see the Test Cases section below for 
running the unit tests.

Also see the ``.gitlab-ci.yml`` file for an example of our continuous 
integration build.

**NOTE:** The COMPOPTS files in ``test/unit`` and ``test/performance`` make use 
of ``--no-lifetime-checking --no-warnings`` for successful compilation. If you 
are compiling independent code that uses CHGL, be sure to use these options as 
well.

Test Cases
----------

CHGL includes both unit & performance tests utilizing the ``start_test`` Python 
script supplied by Chapel. Change directories into ``test/unit`` or 
``test/performance`` and execute ``start_test`` to run the tests. View the 
[unit test README](test/unit/README.md) or 
[perfomrance test README](test/performance/README.md) for more information.

User Guide
==========

TBD
