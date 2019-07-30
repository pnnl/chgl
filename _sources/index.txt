.. CHGL documentation master file, created by
   sphinx-quickstart on Wed Jul 10 14:15:56 2019.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

CHGL Documentation
==================

The **C**\ hapel **H**\ yper\ **g**\ raph **L**\ ibrary (CHGL) is a library
for hypergraph computation in the emerging Chapel language. Hypergraphs
generalize graphs, where a hypergraph edge can connect any number of
vertices. Thus, hypergraphs capture high-order, high-dimensional
interactions between multiple entities that are not directly expressible
in graphs. CHGL is designed to provide HPC-class computation with
high-level abstractions and modern language support for parallel
computing on shared memory and distributed memory systems.

.. toctree::
   :caption: Compiling and Running CHGL
   :maxdepth: 1

   installation_guide
   Performance Results <https://pnnl.github.io/chgl-perf/>


.. toctree::
   :caption: Developer Documentation
   :maxdepth: 1

   api/index
   coding_standards
   contributors



.. toctree::
   :caption: Example CHGL Applications
   :maxdepth: 1

   example/index

CHGL is developed under the `MIT License <https://raw.githubusercontent.com/pnnl/chgl/master/LICENSE>`_ and PNNL `disclaimer <https://raw.githubusercontent.com/pnnl/chgl/master/DISCLAIMER>`_.