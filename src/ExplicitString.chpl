/*
    Due to behavior of `_string` (Chapel's native string type) that:

        1) Creates a full on copy of the string on assignment even if it is not needed.
            https://github.com/chapel-lang/chapel/blob/e6b8fd15b54e2c1f04d4dbf5bc8bff523551842a/modules/internal/String.chpl#L2018-L2029
        2) Leaks the implicit string copy if stored in a Chapel array that never shrinks
        3) Naively rehashes the string and does not cache the hash, hence resulting in excess implicit copies and remote transfers

    These issues have also been confirmed by Michael Ferguson (@mppf); hence to get around this, this module features
    a new 'String' type that does not create any implicit copies. This is necessary not only for performance but also
    space overhead.
*/

record String {
    // String
    var data : _ddata(uint(8));
    // Length of string
    var dataLen : int(64);
    // Precomputed Hash
    var hash : uint(64);

    proc init() {
        this.data = nil;
        this.hash = chpl__defaultHash("");
    }

    proc init=(other : String) {
        this.data = other.data;
        this.dataLen = other.dataLen;
        this.hash = other.hash;
    }

    proc init(str : string) {
        // TODO: Once on master, set `initElts=false`
        this.data = _ddata_allocate(uint(8), str.size);
        this.dataLen = str.size;
        c_memcpy((this.data:c_void_ptr):c_ptr(uint(8)), str.localize().buff, str.size);
        this.hash = chpl__defaultHash(str);
    }

    // Convert into a string; this string does not own nor does it copy the data, meaning modifications to it effects 'String'
    proc toString() {
        if this.dataLen == 0 then return "";
        if data.locale == here {
            return new string((this.data:c_void_ptr):c_string, dataLen, isowned=false, needToCopy=false);
        } else {
            var ret : string;
            on data do ret = new string((this.data:c_void_ptr):c_string, dataLen, isowned=false, needToCopy=false);
            return ret.localize(); 
        }
    }

    proc readWriteThis(f) { f <~> "(String) { data = " <~> this.toString() <~> ", dataLen = " <~> dataLen <~> ", hash = " <~> hash <~> " }"; }

    proc destroy() {
        _ddata_free(data, dataLen);
    }
}

proc +(str1 : string, str2 : String) : string {
    return str1 + str2.toString();
}

proc +(str1 : String, str2 : String) : string {
    return str1.toString() + str2.toString();
}

proc +(str1 : String, str2 : string) : string {
    return str1.toString() + str2;
}

proc ==(str1 : String, str2 : String) : bool {
    return str1.hash == str2.hash && str1.dataLen == str2.dataLen && (str1.data == str2.data || str1.toString() == str2.toString());
}

pragma "no doc"
inline proc chpl__defaultHash(str : String): uint {
    if str.hash == 0 then halt("Attempt to hash an empty 'String'");
    return str.hash;
}