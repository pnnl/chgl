#!/bin/bash

while getopts ":g:t:c:" opt; do
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


echo "("
BINARY="${test}"
echo $BINARY

echo "${graphs}"
graphArr=(${graphs})

for FILE in ${graphArr}; do
    for NODES in 1 2 4 8 16; do
        for THREADS in 1 2 4 8 16 32 44; do # {1..44}; do
            echo "$( basename -- ${BINARY} )##*.-$( basename -- ${FILE})##*.-${NODES}-${THREADS}"
            qsub - << EOF
                #!/bin/bash -l
                #PBS -l place=scatter,select=${NODES},walltime=01:00:00
                #PBS -N $( basename -- ${BINARY} )-$( basename -- ${FILE})-${NODES}-${THREADS}
                #PBS -V
                #PBS -j oe
                #PBS -m abe
                #PBS -M zalewski@pnnl.gov
                #PBS -S /bin/bash
                #PBS -W umask=0000

                set -x

                ulimit -c unlimited

                #export CHPL_LAUNCHER_CORES_PER_LOCALE=${THREADS}
                #export CHPL_RT_NUM_THREADS_PER_LOCALE=${THREADS}
                #export CHPL_RT_COMM_UGNI_MAX_MEM_REGIONS=$((10 * 1024))
                #export CHPL_LAUNCHER=aprun

                cd \$PBS_O_WORKDIR
                echo 'Running script\n'
                for thread in ${THREADS}; do
                    ${BINARY} --dataset ${FILE} -nl ${NODES}
                done
EOF
        done
    done
done
