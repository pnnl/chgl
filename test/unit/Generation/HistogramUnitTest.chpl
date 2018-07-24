use Generation;

var probabilities: [0..9] real;
var numRandom = 1000000:int;
var numRandom_real = numRandom:real;
var generated: [0..9] int;


/* Uniform Probability Check */
for i in 0..9 {
    probabilities[i] = 0.1;
}

var scanProb = (+ scan probabilities);

// used arbitrary odd number seed for 3rd parameter.
var results = histogram(scanProb, numRandom);

for i in results {
    generated[i] += 1;
}

assert((+ reduce generated) == numRandom);

var percent: real;
for i in 0..9{
    percent = generated[i]/numRandom_real;
    assert(((percent) >= 0.09) && ((percent) <= 0.11));
}


/* Biased Probability Check */

// There's probably a better way to do this
probabilities[0] = 0.0;
probabilities[1] = 0.0;
probabilities[2] = 0.0;
probabilities[3] = 0.3;
probabilities[4] = 0.0;
probabilities[5] = 0.4;
probabilities[6] = 0.0;
probabilities[7] = 0.3;
probabilities[8] = 0.0;
probabilities[9] = 0.0;

scanProb = (+ scan probabilities);

// Using a different arbitrarily chosen seed
results = histogram(scanProb, numRandom);

var biasedGenerated: [0..9] int;

for i in results {
    biasedGenerated[i] += 1;
}

for i in 0..9{
    percent = biasedGenerated[i]/numRandom_real;

    if (i == 3) {
        assert((percent >= 0.2) && (percent <= 0.4));
    } else if (i == 5) {
        assert((percent >= 0.3) && (percent <= 0.5));
    } else if (i == 7) {
       assert((percent >= 0.2) && (percent <= 0.4));
    } else {
        assert(percent == 0);
    }
}
writeln(true);
