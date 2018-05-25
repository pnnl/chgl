#!/bin/bash

numVertices=100000
numEdges=100000
probabilityMultiple=1

while getopts ":v:e:c:" opt; do
  case ${opt} in
    v )
      numVertices=$OPTARG
      ;;
    e )
      numEdges=$OPTARG
      ;;
    c )
      probabilityMultiple=$OPTARG
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
for THREADS in 1 2 4 16 32; do
qsub - <<EOF
#!/bin/bash -l
#PBS -l nodes=$NODES:ppn=44
#PBS -l walltime=01:00:00
#PBS -N ${BINARY}-${NODES}-${THREADS}
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
   aprun  -cc none -d 44 -n ${NODES} -N 1 -j 0 ${BINARY}_real -nl ${NODES} --verbose --numVertices ${numVertices} --numEdges ${numEdges} --probabilityMultiple ${probabilityMultiple}
  done
done
EOF

done
done


#aprun -b -n $(( 2 * $NODES )) -N 2 $PT --threads $THREADS --warm-up-iterations 1 --iterations 8 --scale ${scalemap[$NODES]} --rmat1 --run_bucket_mis --coalescing-size 30000,50000,240000 
#export LD_LIBRARY_PATH=/home/users/p02119/development/cds-2.1.0/bin/cc-amd64-linux-64/:$LD_LIBRARY_PATH
