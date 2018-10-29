use CyclicDist;
use BlockDist;

inline proc getLocale(dom, idx) {
  var loc = dom.dist.idxToLocale(idx);
  var locID = chpl_nodeFromLocaleID(__primitive("_wide_get_locale", loc));
  
  // Handles cases where we get a locale that is allocated on another locale...
  if locID == here.id then return loc;
  else return Locales[locID];
}

inline proc getLocale(arr : [], idx) {
  return getLocale(arr.domain, idx);
}

inline proc createCyclic(dom : domain) {
  return dom dmapped Cyclic(startIdx=dom.low);
}
inline proc createCyclic(rng : range) {
  return createCyclic({rng});
}
inline proc createCyclic(sz : integral, startIdx = 1) {
  return createCyclic(startIdx..#sz);
}
inline proc createBlock(dom : domain) {
  return dom dmapped Block(dom);
}
inline proc createBlock(rng : range) {
  return createBlock({rng});
}
inline proc createBlock(sz : integral, startIdx = 1) {
  return createBlock(startIdx..#sz);
}

iter getLines(file : string) : string {
  var f = open(file, iomode.r).reader();
  var tmp : string;
  while f.readline(tmp) do yield tmp;
}

iter getLines(file : string, chunkSize = 1024, param tag : iterKind) : string where tag == iterKind.standalone {
  var chunk : atomic int;
  coforall loc in Locales do on loc {
    coforall tid in 1..#here.maxTaskPar {
      proc p() { return open(file, iomode.r).reader(); }
      var f = p();
      var currentIdx = 0;
      var readChunks = true;
      while readChunks {
        // Claim a chunk...
        var ix = chunk.fetchAdd(chunkSize);
        // Skip ahead to chunk we claimed...
        var tmp : string;
        for 1..#(ix - currentIdx) do f.readline(tmp);
        // Begin processing our chunk...
        for 1..#chunkSize {
          if f.readline(tmp) {
            yield tmp;
          } else {
            readChunks = false;
            break;
          }
        }
      }
    }
  }
}