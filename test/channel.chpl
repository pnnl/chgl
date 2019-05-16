use FIFOChannel;

proc main() {
  var outchan = new unmanaged Channel(int);
  var inchan : unmanaged Channel(int);
  if numLocales == 1 then inchan = new unmanaged Channel(int, len=1024);
  else on Locales[1] do inchan = new unmanaged Channel(int, len=1024);

  outchan.pair(inchan);
  begin on inchan {
    var total : int;
    while !inchan.isClosed() {
      total += (+ reduce inchan.recv());
    }
    total += (+ reduce inchan.recv());
    writeln("Received total: ", total);
  }
  forall ix in 1..1024 do outchan.send(ix);
  writeln("Sent full buffer...");
  forall ix in 1..512 do outchan.send(ix);
  writeln("Sent partial buffer...");
  outchan.close();
}
