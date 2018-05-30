use Sample;
use Time;

var testTimer : Timer;

testTimer.start();
var test : Sample = new Sample();
var sum : atomic int = test.doGoodStuff();
testTimer.stop();

writeln("Time: ", testTimer.elapsed());
