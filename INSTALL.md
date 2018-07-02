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

**Programming Language:** Chapel 1.17.1

**Operating System & Version:** Tested on Chapel Docker containers (Debian) and internal RHEL 7 system

**Required Disk Space:** Approx. 40mb for code repository and binaries

**Required Memory:** Not defined or tested (unit tests run on https://hub.docker.com/r/chapel/chapel/)

**Nodes / Cores Used:** Not defined -- depends on graph size loaded

Dependencies
------------

A compiled version of the Chapel programming language with is test virtual environment is all that is required to compile and test CHGL. Unit tests were run on the GitLab-CI continuous integration system using Chapel's Docker container (see included ``.gitlab-ci.yml`` file for details).

| Name | Version | Download Location | Country of Origin | Special Instructions |
| ---- | ------- | ----------------- | ----------------- | -------------------- |
| Chapel | 1.17.1 | https://github.com/chapel-lang/chapel | USA | None |  

Distribution Files
------------------

_List the files included within the distribution, including a brief overview of what is in each file / tarball. These files will include your source code, test data, configuration files, or other files associated with the installation of your software. Avoid including binaries if at all possible as this makes transferring the software to secure sponsor spaces difficult – instead include these in the dependencies list above with a documented way to retrieve them separately._  

Installation Instructions
-------------------------

_Include detailed step-by-step instructions to compile, package, and install the software. A good place to start is a clean-state machine similar to the deployment environment and document the installation as you get it working there. Where possible, use Docker containers (like https://hub.docker.com/\_/centos/) in build & test systems to ensure that your builds are reproducable at the sponsor independent of internal hardware. Provide detailed documentation on configuration settings or files required for compilation or runtime._

Test Cases
----------

_Include test data in the distribution that can be used to verify the installation was successful. Document detailed steps of how to execute these tests and the ways to identify success or failure. Example input & output data files is preferred over manual data entry. Do not include hard-coded paths within test scripts to allow flexibility in the installation. If possible, include test cases that can be performed on systems smaller than the target system, allowing the sponsor to demonstrate an installation on a different machine._

User Guide
==========

_This section is largely up to the project to determine its contents. Include information on how to run & configure the system, common usage, special configurations, etc. This section should demonstrate to the sponsor how to generally use the software to perform the desired analysis. Consider including troubleshooting guides for known, common problems._