#!/bin/bash

while getopts ":g:t:c:n" opt; do
  case ${opt} in
    g )
      graphs=$OPTARG
      ;;
    t )
      test=$OPTARG
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND - 1))

set -x


echo "$1"
BINARY="$_/${test}"

echo "${graphs}"
graphArr=(${graphs})

for FILE in ${graphArr}; do
for NODES in 1; do
for PROCESS in 1; do # {1..44}; do
echo "$( basename -- ${BINARY} )##*.-$( basename -- ${FILE})##*.-${NODES}-${PROCESS}"
sbatch  <<EOF
#!/bin/bash -l
#SBATCH -N ${NODES}
#SBATCH -t 24:00:00
#SBATCH --job-name upc_$( basename -- ${BINARY} )
#SBATCH --output=upc_$( basename -- ${BINARY})_${NODES}-${PROCESS}-$( basename -- ${FILE})-%j.out

set -x

ulimit -c unlimited

export GASNET_PHYSMEM_MAX=750G
export OMP_NUM_THREADS=20

echo 'Running script\n'
for nodes in ${NODES}; do
  for process in ${PROCESS}; do
   GASNET_PHYSMEM_NOPROBE=1 UPCXX_SHARED_HEAP_SIZE=5G srun --cpu_bind=none -n ${PROCESS} -N ${NODES} --label ${BINARY} --edgelistfile ${FILE}
  done
done
EOF

done
done
done
