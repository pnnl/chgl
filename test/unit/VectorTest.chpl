use Vectors;
use CyclicDist;

var v1, v2 : owned Vector(int);
v1 = new owned VectorImpl(int, {0..#10});
v2 = new owned VectorImpl(int, {0..#10} dmapped Cyclic(startIdx=1));
v1.append(1);
v2.append(2);
writeln(v1[0]);
writeln(v2[0]);
