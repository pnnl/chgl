# Graph format converter 

converters/ - Contains MatrixMarket file (from [https://sparse.tamu.edu](https://sparse.tamu.edu) ) to Binary file converter
We used the vertex-count-converter for conversion. 

To compile:

```bash
g++ -std=c++14 -o vertex-count-converter vertex-count-converter.cpp
```

To run:
```bash
./vertex-count-converter --edgelistfile [mmio_filename]
```

In addition, another converter, the vertex-and-edge-count-converter is also included that has edge counts in the binary file header.

Binary File Format:

[vertex-and-edge-count]

|V| - 8 Bytes; Offset 0
|E| - 8 Bytes; Offset 8
Vertex Offsets - |V| * 8 bytes; Offset 16
Adjacency List - ...; Offset 16 bytes + |V| * 8 bytes

Example: Lets say we have 100 vertices in our graph...

The beginning offset of the adjacency list for vertex 8 is 
held at location 80 (16 + 64) and end offset can be calculated
from offset 88 (16 + 72). The adjacecy list can then be calculated
to be between offets (16 + 800 + startOffset) to (16 + 800 + endOffset - 1)

[vertex-count]

|V| - 8 Bytes; Offset 0
Vertex Offsets - |V| * 8 bytes; Offset 8
Adjacency List - ...; Offset 8 bytes + |V| * 8 bytes


