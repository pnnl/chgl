use CHGL;

proc printMatrix(m) {
    for (i,j) in m.domain {
        writeln((i,j), ":",m[i,j]);
    }
}

var graph = new AdjListHyperGraph(20, 10);

for i in 0..9 {
    graph.addInclusion(2 * i, i);
    graph.addInclusion(2 * i + 1, i);
}
for i in 0..9 {
    graph.addDirection(graph.toEdge(i), graph.toEdge(i + 1));
}

var m1 = graph.getIncidenceMatrix();
printMatrix(m1);

var m2 = graph.getDirectedIncidenceMatrix();
printMatrix(m2);


