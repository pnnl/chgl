#!/bin/bash

threads=44
nodes=1
walltime=01:00:00

while getopts ":a:t:n:w:" opt; do
  case ${opt} in
    a )
      args=$OPTARG
      ;;
    t )
      threads=$OPTARG
      ;;
    n )
      nodes=$OPTARG
      ;;
    w )
      walltime=$OPTARG
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

for NODES in ${nodes}; do
for THREADS in ${threads}; do
echo "Nodes: ${NODES}, Threads: ${THREADS}, walltime=${walltime}, args=${args}"
echo "aprun  -cc none -d 44 -n ${NODES} -N 1 -j 0 ${BINARY}_real -nl ${NODES} ${args}"
echo "Filename: $(basename -- ${BINARY})-${NODES}-${THREADS}"
qsub - <<EOF
#!/bin/bash -l
#PBS -l place=scatter,select=${NODES},walltime=${walltime}
#PBS -l walltime=${walltime}
#PBS -N $(basename -- ${BINARY})-${NODES}-${THREADS}
#PBS -V
#PBS -j oe
#PBS -m abe
#PBS -S /bin/bash
#PBS -W umask=0000

set -x

ulimit -c unlimited

export CHPL_LAUNCHER_CORES_PER_LOCALE=${THREADS}
export CHPL_RT_NUM_THREADS_PER_LOCALE=${THREADS}

module load craype-hugepages16M

cd \$PBS_O_WORKDIR
echo 'Running script\n'
aprun  -cc none -d 44 -n ${NODES} -N 1 -j 0 ${BINARY}_real -nl ${NODES} ${args}
EOF

done
done
