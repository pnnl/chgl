use Generation;
use Types;

var vd_file = open("../../../data/condMat/dSeq_v_list.csv", iomode.r).reader();
var ed_file = open("../../../data/condMat/dSeq_E_list.csv", iomode.r).reader();
var vm_file = open("../../../data/condMat/mpd_V.csv", iomode.r).reader();
var em_file = open("../../../data/condMat/mpd_E.csv", iomode.r).reader();

var matlabRhoFile = open("../../../data/output/BTER/CondMat-Sinan/rhoByAffBlkID.csv", iomode.r).reader();
var matlabVFile = open("../../../data/output/BTER/CondMat-Sinan/affBlkID_V.csv", iomode.r).reader();
var matlabEFile = open("../../../data/output/BTER/CondMat-Sinan/affBlkID_E.csv", iomode.r).reader();

var vertexDegrees: [0..16725] int;
var edgeDegrees: [0..22014] int;
var vertexMetamorphs: [0..115] real;
var edgeMetamorphs: [0..17] real;

var matlabRho: [0..5308] real;
var matlabV: [0..16725] real;
var matlabE: [0..22014] real;

for i in 0..16725 {
    vd_file.read(vertexDegrees[i]);
    matlabVFile.read(matlabV[i]);
}
for i in 0..22014 {
    ed_file.read(edgeDegrees[i]);
    matlabEFile.read(matlabE[i]);
}
for i in 0..5308 {
    matlabRhoFile.read(matlabRho[i]);
}
for i in 0..115 {
    vm_file.read(vertexMetamorphs[i]);
}
for i in 0..17 {
    em_file.read(edgeMetamorphs[i]);
}

vd_file.close();
ed_file.close();
vm_file.close();
em_file.close();

cobegin {
    sort(vertexDegrees);
    sort(edgeDegrees);
}

var (nV, nE, rho): 3 * real;

// hardcode the initial index with a degree greater than one
// for the vertices/edges
var idV = 7819;
var idE = 4178;

var numV = vertexDegrees.size;
var numE = edgeDegrees.size;


var probDiff : real;
var blockID = 1;
while (idV <= numV && idE <= numE) {
    var (dV, dE) = (vertexDegrees[idV], edgeDegrees[idE]);
    var (mV, mE) = (vertexMetamorphs[dV - 1], edgeMetamorphs[dE - 1]);
    (nV, nE, rho) = computeAffinityBlocks(dV, dE, mV, mE);

    // Using index [blockID-1] because array starts at 0
    // and var BlockID start at 1.
    probDiff = abs(rho - matlabRho[blockID-1]);
    assert(probDiff >= (5*(10**-6)));

    blockID += 1;
    var nV_int = nV:int;
    var nE_int = nE:int;

    idV += nV_int;
    idE += nE_int;
}
assert((blockID-1) == 3509);
writeln(true);
