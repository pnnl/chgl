use Generation;

var probabilities: [0..9] real;
var numRandoms = 200000000;

var generated: [0..9] int;

probabilities[0] = 
probabilities[1] =
probabilities[2] =
probabilities[3] =
probabilities[4] =
probabilities[5] =
probabilities[6] =
probabilities[7] =
probabilities[8] =
probabilities[9] =

var derp = (+ scan probabilities);

var results = histogram(derp, numRandoms, 1235);

for i in results{
    generated[i] += 1;
}

writeln(generated);
