.. CHGL documentation master file, created by
   sphinx-quickstart on Wed Jul 10 14:15:56 2019.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

CHGL Documentation
==================

**C**\ hapel **H**\ yper\ **g**\ raph **L**\ ibrary (CHGL), a library
for hypergraph computation in the emerging Chapel language. Hypergraphs
generalize graphs, where a hypergraph edge can connect any number of
vertices. Thus, hypergraphs capture high-order, high-dimensional
interactions between multiple entities that are not directly expressible
in graphs. CHGL is designed to provide HPC-class computation with
high-level abstractions and modern language support for parallel
computing on shared memory and distributed memory systems.

.. toctree::
   :caption: Compiling and Running Chapel
   :maxdepth: 1

   Quickstart Instructions <quickstart>
   CHGL Performance Results <https://pnnl.github.io/chgl-perf/>


.. toctree::
   :caption: Writing CHGL Programs
   :maxdepth: 1

   examples/index
   api/index

