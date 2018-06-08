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

**Project Name:** _Current & past names (if any)_

**Principle Investigator:** _Name & contact info_

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

**Programming Language:** _List of the programming languages used_

**Operating System & Version:** _Most likely RedHat Enterprise Linux or CentOS_

**Required Disk Space:** _Installation size_

**Required Memory:** _Runtime memory required_

**Nodes / Cores Used:** _If applicable_

Dependencies
------------

_List all dependencies required to build & run the software. Consider separating build dependencies from runtime dependencies, if the lists are separate (e.g., compilers vs linked libraries). Start with a clean-state system and list all packages installed prior to and during the installation. For example, using Docker containers (like https://hub.docker.com/\_/centos/) for build environments will ensure the list of required dependencies is known and accurate. Include special installation instructions, if any (compiler flags, required configurations, etc.)._

_Attempt to keep this list short. Some sponsor environments are difficult to bring in new dependencies. Prefer the use of released software versions, not snapshot or the latest code. Packages that are included within the OS itself reduce sponsor installation complexity. USA country of origin also simplifies sponsor deployments._

| Name | Version | Download Location | Country of Origin | Special Instructions |
| ---- | ------- | ----------------- | ----------------- | -------------------- |
| Sample | 1.0 | https://github.com/pnnl/ | USA | None |  

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