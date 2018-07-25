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

**Principle Investigator:** Marcin Zalewski (marcin.zalewski@pnnl.gov) 

**General Area or Topic of Investigation:** _Short field of study_

**Release Number:** _Formal version number or Git branch & tag that must uniquely (and reproducibly) identify this delivery_

Detailed Summary
----------------

_Include the purpose of the research and an explanation of what it does from a high level._

Installation Guide
==================

The following sections detail the compilation, packaging, and installation of the software. Also included are test data and scripts to verify the installation was successful.

Environment Requirements
------------------------

**Programming Language:** Chapel 1.18 pre-release (master branch as of 7/25/2018)

**Operating System & Version:** Tested on Chapel Docker containers (Debian) and internal RHEL 7 system

**Required Disk Space:** Approx. 40mb for code repository and binaries

**Required Memory:** Not defined or tested (unit tests run on https://hub.docker.com/r/chapel/chapel/)

**Nodes / Cores Used:** Not defined -- depends on graph size loaded

Dependencies
------------

A compiled version of the Chapel programming language with is test virtual environment is all that is required to compile and test CHGL. Unit tests were run on the GitLab-CI continuous integration system using Chapel's Docker container (see included ``.gitlab-ci.yml`` file for details).

| Name | Version | Download Location | Country of Origin | Special Instructions |
| ---- | ------- | ----------------- | ----------------- | -------------------- |
| Chapel | 1.18 pre-release | https://github.com/chapel-lang/chapel | USA | None |  

Distribution Files
------------------

CHGL is released as a Git repository found at https://gitlab.com/marcinz/chgl. No additional files are required. 

Installation Instructions
-------------------------

CHGL can be compiled by first installing Chapel (see https://chapel-lang.org/docs/usingchapel/QUICKSTART.html) or using a Chapel Docker image (see https://hub.docker.com/r/chapel/chapel/). Note however that CHGL uses features found in the Chapel 1.18 pre-release and these features are currently unavailable in Docker images. Once a 1.18 release is made, Docker images can be used.

With Chapel installed, you can compile the CHGL module as follows:

**TODO**

See the ``.gitlab-ci.yml`` file for an example of our continuous integration build.

Test Cases
----------

CHGL includes both unit & performance tests utilizing the ``start_test`` Python script supplied by Chapel. Change directories into ``test/unit`` or ``test/performance`` and execute ``start_test`` to run the tests. View the [unit test README](test/unit/README.md) or [perfomrance test README](test/performance/README.md) for more information.

_Note that the build on GitlabCI currently fails as we wait on Chapel 1.18 to be released as it uses the Chapel Docker images to build._

User Guide
==========

**TODO** -- @Marcin, should we include a link to the paper (if one exists?). Otherwise we may be able to leave this section out.

_This section is largely up to the project to determine its contents. Include information on how to run & configure the system, common usage, special configurations, etc. This section should demonstrate to the sponsor how to generally use the software to perform the desired analysis. Consider including troubleshooting guides for known, common problems._