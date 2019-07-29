.. _chgl-quickstart:

Quickstart Instructions
=======================

Follow the instructions below to get Chapel and CHGL compiled in your
environment.

Environment Requirements
------------------------

**Programming Language:** Chapel

**Operating System & Version:** Tested on Chapel Docker containers
(Debian) and internal RHEL 7 system

**Required Disk Space:** Approx. 40mb for code repository and binaries

Dependencies
------------

A compiled version of the Chapel programming language with is test
virtual environment is all that is required to compile and test CHGL.
Unit tests were run on the Travis CI continuous integration system using
Chapel's Docker container (see included ``.travis.yml`` file for
details).

====== ============== ======================================== =================
Name   Version        Download Location                        Country of Origin
====== ============== ======================================== =================
Chapel Release 1.19.0 https://github.com/chapel-lang/chapel    USA              
====== ============== ======================================== =================

Distribution Files
------------------

CHGL is released through a GitHub repository found at
https://github.com/pnnl/chgl. No additional files are required.

Installation Instructions
-------------------------

Chapel
~~~~~~

Chapel must be installed on the system before compiling and installing
CHGL. The version required is documented above in `Dependencies`_. Be
sure to checkout the required branch, tag, or commit CHGL has been
tested with as using a different version of Chapel may cause errors.

If a particular branch, tag, or commit is required, execute the
following git command after cloning the Chapel GitHub repository:

::

   git checkout <branch_name, tag_name, or commit_hash>

With the correct Chapel version checked out, continue by folloing the
Chapel installation documented at
https://chapel-lang.org/docs/usingchapel/QUICKSTART.html.

Alternatively if a release is used, a Chapel Docker image found at
https://hub.docker.com/r/chapel/chapel/.

CHGL
~~~~

In the future, CHGL will be compiled and packaged into a Mason library.
For the time being, CHGL is used directly (see unit tests for examples).
The code is compiled and tested simultaneously -- see the Test Cases
section below for running the unit tests.

Also see the ``.travis.yml`` file for an example of our continuous
integration build. Or view the current status at
https://travis-ci.com/pnnl/chgl.

**NOTE:** The COMPOPTS files in ``test`` and ``test_performance``
make use of ``--no-lifetime-checking --no-warnings`` for successful
compilation. If you are compiling independent code that uses CHGL, be
sure to use these options as well.

Test Cases
----------

CHGL includes both unit & performance tests utilizing the ``start_test``
Python script supplied by Chapel. Change directories into ``test``
or ``test_performance`` and execute ``start_test`` to run the tests.
View the `unit test README`_ or `perfomrance test README`_ for more
information.

The unit tests are best run to verify the CHGL build. Performance tests
were not routinely run by a continuous integration environment and were
written targeting particular hardware systems, leading them to be not as
useful for verifying a CHGL build.

.. _unit test README: test/README.md
.. _perfomrance test README: test_performance/README.md