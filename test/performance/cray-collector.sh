#! /bin/bash
echo > results.csv;
for i in 1 2 4 8 16 32; do
    for j in 1 2 4 8 16 32; do
        file=(strong2-ErdosRenyi-$i-$j*);
        result=$(cat $file | grep "Time:" -H);
        echo "$i,$j,${result:23}" >> results.csv;
    done;
done;
