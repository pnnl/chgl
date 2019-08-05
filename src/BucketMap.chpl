/*
    A map intended to be used for computing equivalence classes. We create a fixed number
    of buckets per locale and use modulus division to determine where the objects are sent to.
    The more buckets, the higher the potential for concurrency. Each bucket is a resizing vector
    with its own lock; this can be seen as a way to dynamically redistribute data based on the hash.
*/

use CyclicDist;
use Vectors;

config const BucketMapInitialBucketSize = 8;

pragma "always RVF"
record BucketMap {
    type keyType;
    type valueType;
    var pid : int;

    proc init(type keyType, type valueType, numBucketsPerLocale = 1024) {
        this.keyType = keyType;
        this.valueType = valueType;
        var instance = new unmanaged BucketMapImpl(keyType, valueType, numBucketsPerLocale);
        this.pid = instance.pid;
    }

    forwarding chpl_getPrivatizedCopy(BucketMapImpl(keyType, valueType), pid);
}

// Dynamic resizable container for key-value pairs.
class Bucket {
    type keyType;
    type valueType;
    var lock : Lock;
    // Kept separate for greater cache locality and potential packing
    // I.E if keys are integers and values are large records or an array,
    // this will allow for keys to be packed if they're less than 8 bytes,
    // and even if they are greater than 8 bytes, cache-line prefetching will
    // allow for 8 of the keys to be fetched at once; this is inspired by
    // Golang's sequential map implementation
    // https://github.com/golang/go/blob/master/src/runtime/map.go#L153-L157
    var keySlots : owned Vector(keyType);
    var valueSlots : owned Vector(valueType);
    
    proc init(type keyType, type valueType) {
        this.keyType = keyType;
        this.valueType = valueType;
        this.keySlots = new owned Vector(keyType, BucketMapInitialBucketSize);
        this.valueSlots = new owned Vector(valueType, BucketMapInitialBucketSize);
    }
}

// Distributed array of buckets.
class Buckets {
    type keyType;
    type valueType;
    const numBucketsPerLocale : int;
    var bucketsDom = {0..#(numLocales * numBucketsPerLocale)} dmapped Cyclic(startIdx=0);
    var buckets : [bucketsDom] unmanaged Bucket(keyType, valueType);

    proc init(type keyType, type valueType, numBucketsPerLocale) {
        this.keyType = keyType;
        this.valueType = valueType;
        this.numBucketsPerLocale = numBucketsPerLocale;
    }
}

class BucketMapImpl {
    type keyType;
    type valueType;
    var pid : int;
    var buckets : unmanaged Buckets(keyType, valueType);
    // Do not perform a shallow-copy
    var bucketsRef = _newArray(buckets.buckets._value);

    proc init(type keyType, type valueType, numBucketsPerLocale : int) {
        this.keyType = keyType;
        this.valueType = valueType;
        this.buckets = new unmanaged Buckets(keyType, valueType, numBucketsPerLocale);
        this.complete();
        // Ensures it does not try to cleanup when out of scope
        this.bucketsRef._unowned = true; 
        forall bucket in this.buckets.buckets do bucket = new unmanaged Bucket(keyType, valueType);

        this.pid = _newPrivatizedClass(this:unmanaged);
    }

    proc init(other : unmanaged Bucket(?keyType, ?valueType), privatizedData) {
        this.keyType = keyType;
        this.valueType = valueType;
        this.pid = privatizedData[1];
        this.buckets = privatizedData[2];
        this.complete();
        this.bucketsRef._unowned = true;
    }

    proc dsiPrivatize(privatizedData) { return new unmanaged BucketMapImpl(this:unmanaged, privatizedData); }
    proc dsiGetPrivatizeData() { return (pid, buckets); }
    inline proc getPrivatizedInstance() { return chpl_getPrivatizedCopy(this.type, pid); } // Bonus...
}