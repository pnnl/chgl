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

Summary
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

**Programming Language:** Chapel 1.18 pre-release (master branch as of 9/17/2018)

**Operating System & Version:** Tested on Chapel Docker containers (Debian) and internal RHEL 7 system

**Required Disk Space:** Approx. 40mb for code repository and binaries

Dependencies
------------

A compiled version of the Chapel programming language with is test virtual environment is all that is required to compile and test CHGL. Unit tests were run on the Travis CI continuous integration system using Chapel's Docker container (see included ``.travis.yml`` file for details).

| Name | Version | Download Location | Country of Origin | Special Instructions |
| ---- | ------- | ----------------- | ----------------- | -------------------- |
| Chapel | 1.18 pre-release | https://github.com/chapel-lang/chapel | USA | Tested with commit [155a8837560da1645b31784a7df301fca400f048](https://github.com/chapel-lang/chapel/commit/155a8837560da1645b31784a7df301fca400f048) |  

Distribution Files
------------------

CHGL is released through a GitHub repository found at https://github.com/pnnl/chgl. No additional files are required. 

Installation Instructions
-------------------------

CHGL can be compiled by first installing Chapel 
(see https://chapel-lang.org/docs/usingchapel/QUICKSTART.html) or using a Chapel 
Docker image (see https://hub.docker.com/r/chapel/chapel/). Be sure to pull the required
commit CHGL has been tested with (see Dependencies above). Using a newer version
of Chapel may cause errors.

Note that CHGL uses features found in the Chapel 1.18 pre-release. These features are 
currently unavailable in Cray's published Docker images at https://hub.docker.com/r/chapel/chapel/. 
Once a 1.18 release is made, Cray Docker images can be used. PNNL used custom-built 
Docker imsages compiled from the master branch of the Chapel source (see https://hub.docker.com/r/pnnl/chapel/).

In the future, CHGL will be compiled and packaged into a Mason library. For the 
time being, CHGL is used directly (see unit tests for examples). The code is 
compiled and tested simultaneously -- see the Test Cases section below for 
running the unit tests.

Also see the ``.travis.yml`` file for an example of our continuous 
integration build. Or view the current status at https://travis-ci.org/pnnl/chgl.

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

The unit tests are best run to verify the CHGL build. Performance tests were not routinely
run by a continuous integration environment and were written targeting particular hardware
systems, leading them to be not as useful for verifying a CHGL build.

User Guide
==========

A full User Guide is still under development; however, the CHGL API documentation 
can be generated using Chapel's chpldoc application at the root of the source tree. 
E.g., ``chpldoc src/*/*.chpl``. 
