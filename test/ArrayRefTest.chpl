use CHGL;
use BlockDist;
use CyclicDist;
use BlockCycDist;

var D1 = {1..10};
var D2 = D1 dmapped Block(boundingBox=D1);
var D3 = D1 dmapped Cyclic(startIdx=1);
var D4 = D1 dmapped BlockCyclic(startIdx=1, blocksize=1);
var A1 : [D1] int;
var A2 : [D2] int;
var A3 : [D3] int;
var A4 : [D4] int;

var arrRef1 = new ArrayRef(A1);
var arrRef2 = new ArrayRef(A2);
var arrRef3 = new ArrayRef(A3);
var arrRef4 = new ArrayRef(A4);

[a in arrRef1] a = 1;
[a in arrRef2] a = 2;
[a in arrRef3] a = 3;
[a in arrRef4] a = 4;

writeln(A1);
writeln(A2);
writeln(A3);
writeln(A4);
