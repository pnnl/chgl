# UPC++ Benchmarks

This directory provides implementations of two graph kernels in UPC++: triangle counting and breadth-first-search. In addition, an OpenMP version of the triangle counting algorithm is also provided to establish baseline. The program assumes graph input in a particular binary file format. Please refer to the [README](../converters/README.md) file in the converter directory for the graph converters that we use for converting graph inputs in the mmio format to the binary format. For the current UPC++ graph kernel execution, we primarily use vertex-count-converter in the converter folder as the conversion program.

We assume that a functional UPC++ installation is already existent (tested with the [59cd1b](https://bitbucket.org/berkeleylab/upcxx/commits/59cd1ba9a9fa86d897bbc62669d0eb732fd9d373?at=master) version). Assuming the UPC++ compiler wrapper (provided with the UPC++ installation) is in the `../build/bin/upcxx` directory, the following commands are used for compiling the kernels:

In addition, we use UPC++ STL allocator available in the original UPC++ repo:
[https://bitbucket.org/berkeleylab/upcxx-extras/src/master/extensions/allocator/](https://bitbucket.org/berkeleylab/upcxx-extras/src/master/extensions/allocator/)


To compile UPC++ triangle counting:

```bash
CXX=mpicxx UPCXX_CODEMODE=03 UPCXX_GASNET_CONDUIT=ibv UPCXX_THREADMODE=seq GASNET_PHYSMEM_NOPROBE=1 GASNET_CONFIGURE_ARGS=--enable-debug=no ../build/bin/upcxx -v -std=c++14 -Wall -Wextra -O3 -DNDEBUG -fopenmp -lboost_system -I../ -o triangle_counting triangle_counting.cpp
```

To compile UPC++ BFS:

```bash
CXX=mpicxx UPCXX_CODEMODE=03 UPCXX_GASNET_CONDUIT=ibv UPCXX_THREADMODE=seq GASNET_PHYSMEM_NOPROBE=1 GASNET_CONFIGURE_ARGS=--enable-debug=no ../build/bin/upcxx -v -std=c++14 -Wall -Wextra -O3 -DNDEBUG -lboost_system -I../ -o bfs_rget bfs_rget.cpp
```

To compile OpenMP version of triangle counting:

```bash
CXX=mpicxx UPCXX_CODEMODE=03 UPCXX_GASNET_CONDUIT=ibv UPCXX_THREADMODE=par GASNET_PHYSMEM_NOPROBE=1 GASNET_CONFIGURE_ARGS=--enable-debug=no ../build/bin/upcxx -v -std=c++14 -Wall -Wextra -O3 -DNDEBUG  -lboost_system -I../ -o triangle_counting_shared triangle_counting_shared.cpp -fopenmp
```

To run:

We have provided a slurm script `runner.sh` to run the programs on multiple nodes. The script needs to be modified for specifying the number of compute nodes and processes t o be used, as well as the no of OpenMP threads to use. To run the script:

```bash
runner.sh -g [binary_input_file] -t [executable_name] .
```

To run any of the programs manually type:

```bash
srun --cpu_bind=none -n [no_of_processes_per_node] -N [total_node] --label [executable_name] --edgelistfile [binary_ip_file]
```

For questions/comments, please contact: Jesun Sahariar Firoz (jesun.firoz@pnnl.gov)
