#!/bin/bash

numVertices=100000
numEdges=100000
probability=0.01

while getopts ":v:e:c:" opt; do
  case ${opt} in
    v )
      numVertices=$OPTARG
      ;;
    e )
      numEdges=$OPTARG
      ;;
    p )
      probability=$OPTARG
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

BINARY=$@

set -x

for NODES in 1; do
for THREADS in 1 2 4 8 16 32; do
#for PROBABILITY in 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1; do
probability_adjusted=$probability; # $( echo "scale = 10; ${probability} * ${THREADS}" | bc )
qsub - <<EOF
#!/bin/bash -l
#PBS -l nodes=${NODES}:ppn=44
#PBS -l walltime=01:00:00
#PBS -N strong2-$( echo ${BINARY} | cut -d "/" -f 2 )-${NODES}-${THREADS}-smp
#PBS -V
#PBS -j oe
#PBS -m abe
#PBS -M zalewski@pnnl.gov
#PBS -S /bin/bash
#PBS -W umask=0000

set -x

ulimit -c unlimited

export CHPL_LAUNCHER_CORES_PER_LOCALE=${THREADS}
export CHPL_RT_NUM_THREADS_PER_LOCALE=${THREADS}

module load craype-hugepages16M

cd \$PBS_O_WORKDIR
echo 'Running script\n'
for nodes in ${NODES}; do
  for threads in ${THREADS}; do
    #for prob in ${PROBABILITY}; do
        aprun  -cc none -d 44 -n ${NODES} -N 1 -j 0 ${BINARY}_real -nl ${NODES} --verbose --numVertices ${numVertices} --numEdges ${numEdges} --probability ${probability}
    #done
  done
done
EOF

#done
done
done


#aprun -b -n $(( 2 * $NODES )) -N 2 $PT --threads $THREADS --warm-up-iterations 1 --iterations 8 --scale ${scalemap[$NODES]} --rmat1 --run_bucket_mis --coalescing-size 30000,50000,240000
#export LD_LIBRARY_PATH=/home/users/p02119/development/cds-2.1.0/bin/cc-amd64-linux-64/:$LD_LIBRARY_PATH
