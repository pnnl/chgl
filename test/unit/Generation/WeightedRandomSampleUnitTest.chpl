use Generation;

var arr : [1..10] real;
arr[3..4] = 0.25;
arr[5..7] = 0.5;
arr[8] = 0.9;
arr[10] = 1;

writeln("arr = ", arr);
writeln("WRS(arr, 0.1) = ", weightedRandomSample(arr.domain, arr, 0.1));
writeln("WRS(arr, 0.3) = ", weightedRandomSample(arr.domain, arr, 0.3));
writeln("WRS(arr, 0.5) = ", weightedRandomSample(arr.domain, arr, 0.5));
writeln("WRS(arr, 0.7) = ", weightedRandomSample(arr.domain, arr, 0.7));
writeln("WRS(arr, 0.9) = ", weightedRandomSample(arr.domain, arr, 0.9));
writeln("WRS(arr, 0.99) = ", weightedRandomSample(arr.domain, arr, 0.99));
writeln("WRS(arr, 1.0) = ", weightedRandomSample(arr.domain, arr, 1.0));

// Re-enable once we support strided arrays again for `weightedRandomSample`
/*
var stridedArr : [1..10 by 2] real;
stridedArr[1] = 0.1;
stridedArr[3] = 0.3;
stridedArr[5] = 0.5;
stridedArr[7] = 0.7;
stridedArr[9] = 1;

writeln("stridedArr = ", stridedArr);
writeln("WRS(stridedArr, 0.1) = ", weightedRandomSample(stridedArr.domain, stridedArr, 0.1));
writeln("WRS(strdedArr, 0.3) = ", weightedRandomSample(stridedArr.domain, stridedArr, 0.3));
writeln("WRS(stridedArr, 0.5) = ", weightedRandomSample(stridedArr.domain, stridedArr, 0.5));
writeln("WRS(stridedArr, 0.7) = ", weightedRandomSample(stridedArr.domain, stridedArr, 0.7));
writeln("WRS(stridedArr, 0.9) = ", weightedRandomSample(stridedArr.domain, stridedArr, 0.9));
writeln("WRS(stridedArr, 0.99) = ", weightedRandomSample(stridedArr.domain, stridedArr, 0.99));
writeln("WRS(stridedArr, 1.0) = ", weightedRandomSample(stridedArr.domain, stridedArr, 1.0));
*/